"""MoveMark — concurrency/load gate on a synthetic benchmark branch (never dev or production).

    ../movemark-api-py/.venv/bin/python scripts/db/load_gate.py ~/.movemark-qa/bench-hardening/movemark_api.dsn \\
        --owner-dsn-file <bench owner dsn> [--levels 10,25,50,100] [--seconds 45]

Each concurrent session is its own pooled connection as movemark_api (as the API would hold them) running a
weighted mix of the real operations: property snapshot, list reads, evidence writes (item + 2 photos in one
transaction), credit-funded export enqueue (insert + consume_report_credit, one transaction), worker claim +
lease-fenced completion, and account deletion of reserved users while everyone else keeps writing. The
harness itself (picking ids, checking invariants) uses the owner connection; every workload session is
movemark_api, which cannot read Neon's auth schema. Ramps the
concurrency levels and reports per-operation throughput and p50/p95/p99, every database error by SQLSTATE,
and finally checks the invariants: credits never overspent, no export claimed twice, deleted accounts fully
gone, no deadlocks/serialization failures/timeouts.
"""
from __future__ import annotations

import argparse
import asyncio
import collections
import json
import pathlib
import random
import statistics
import sys
import time

import psycopg

# The property snapshot is an app call (Data API, `authenticated` under RLS — not callable by movemark_api);
# its cost is in bench_plans.py. "ping" (SELECT 1) is the round-trip baseline: this harness runs far from the
# database, so every latency below includes ping × the statements the operation sends.
MIX = [("ping", 10), ("lists", 35), ("write_evidence", 30), ("enqueue_credit", 10), ("claim_complete", 14), ("delete_account", 1)]


class Gate:
    def __init__(self, dsn: str, owner_dsn: str) -> None:
        self.dsn = dsn
        self.owner_dsn = owner_dsn
        self.lat: dict[str, list[float]] = collections.defaultdict(list)
        self.errors: collections.Counter = collections.Counter()
        self.claimed: list[str] = []
        self.spent = 0
        self.deleted: list[str] = []

    async def setup(self) -> None:
        async with await psycopg.AsyncConnection.connect(self.owner_dsn) as c:
            host = c.info.host or ""
            if "ep-steep-wind" in host or "ep-quiet-salad" in host:
                sys.exit("refusing: dev/production endpoint")
            big = (await (await c.execute("SELECT property_id FROM evidence_files GROUP BY property_id ORDER BY count(*) DESC LIMIT 1")).fetchone())[0]
            rows = await (await c.execute(
                "SELECT p.id, p.user_id, i.id, (SELECT array_agg(r.id) FROM rooms r WHERE r.property_id = p.id) "
                "FROM properties p JOIN inspections i ON i.property_id = p.id AND i.inspection_type = 'move_in' "
                "WHERE p.id <> %s ORDER BY random() LIMIT 5000", (big,))).fetchall()
            self.props = [(str(p), str(u), str(i), [str(r) for r in rooms]) for p, u, i, rooms in rows]
            items = await (await c.execute("SELECT id FROM inspection_items ORDER BY random() LIMIT 5000")).fetchall()
            self.items = [str(r[0]) for r in items]
            paths = await (await c.execute("SELECT thumbnail_path FROM evidence_files WHERE thumbnail_path IS NOT NULL ORDER BY random() LIMIT 5000")).fetchall()
            self.paths = [r[0] for r in paths]
            # Account deletion targets: users nobody else's workload touches (not in self.props).
            busy = {u for _, u, _, _ in self.props}
            victims = await (await c.execute("SELECT id FROM neon_auth.\"user\" WHERE email LIKE 'synth%%' ORDER BY random() LIMIT 400")).fetchall()
            self.victims = [str(v[0]) for v in victims if str(v[0]) not in busy]
            # Credit spenders: users with a balance, and their properties.
            spenders = await (await c.execute(
                "SELECT c.user_id, c.balance, array_agg(p.id) FROM user_report_credits c JOIN properties p ON p.user_id = c.user_id "
                "WHERE c.balance > 0 GROUP BY c.user_id, c.balance ORDER BY random() LIMIT 300")).fetchall()
            self.spenders = [(str(u), b, [str(p) for p in ps]) for u, b, ps in spenders if str(u) not in self.victims]
            self.initial_balance = sum(b for _, b, _ in self.spenders)
            await c.execute("UPDATE exports SET status = 'completed' WHERE status = 'queued'")  # start with an empty queue
            await c.commit()

    async def op(self, conn: psycopg.AsyncConnection, name: str) -> None:
        if name == "ping":
            await conn.execute("SELECT 1")
        elif name == "lists":
            p, _, _, rooms = random.choice(self.props)
            await conn.execute("SELECT * FROM rooms WHERE property_id = %s ORDER BY sort_order", (p,))
            await conn.execute("SELECT * FROM evidence_files WHERE inspection_item_id = %s", (random.choice(self.items),))
            path = random.choice(self.paths)
            await conn.execute("SELECT id FROM evidence_files WHERE file_path = %s OR thumbnail_path = %s", (path, path))
        elif name == "write_evidence":
            p, u, insp, rooms = random.choice(self.props)
            async with conn.transaction():
                item = (await (await conn.execute(
                    "INSERT INTO inspection_items (inspection_id, room_id, notes, condition_rating) VALUES (%s, %s, 'load', 4) RETURNING id",
                    (insp, random.choice(rooms)))).fetchone())[0]
                for k in range(2):
                    await conn.execute(
                        "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, thumbnail_path, file_type) "
                        "VALUES (%s, %s, %s, %s, 'image')",
                        (p, item, f"{u}/{p}/move-in/load/{item}-{k}.jpg", f"{u}/{p}/move-in/load/{item}-{k}_thumb.jpg"))
        elif name == "enqueue_credit":
            if not self.spenders:
                return
            u, _, props = random.choice(self.spenders)
            try:
                async with conn.transaction():
                    export = (await (await conn.execute(
                        "INSERT INTO exports (user_id, property_id, export_type, status) VALUES (%s, %s, 'move_in_report', 'queued') RETURNING id",
                        (u, random.choice(props)))).fetchone())[0]
                    ok = (await (await conn.execute("SELECT consume_report_credit(%s, %s)", (u, f"load:{export}"))).fetchone())[0]
                    if not ok:
                        raise LookupError("no credit")  # roll the export back, as the API does
                self.spent += 1
            except LookupError:
                self.errors["expected:no_credit"] += 1
            except psycopg.errors.UniqueViolation:
                self.errors["expected:one_active_job_per_property"] += 1
        elif name == "claim_complete":
            row = await (await conn.execute("SELECT id, attempts FROM claim_next_export_job()")).fetchone()
            await conn.commit()
            if row:
                self.claimed.append(str(row[0]))
                await conn.execute(
                    "UPDATE exports SET status = 'completed', completed_at = now(), locked_at = NULL "
                    "WHERE id = %s AND status = 'processing' AND attempts = %s", (row[0], row[1]))
        elif name == "delete_account":
            if not self.victims:
                return
            victim = self.victims.pop()
            async with conn.transaction():
                await conn.execute("SELECT delete_user_owned_data(%s)", (victim,))
                await conn.execute("SELECT delete_auth_user(%s)", (victim,))
            self.deleted.append(victim)
        await conn.commit()

    async def session(self, deadline: float) -> None:
        names, weights = zip(*MIX)
        async with await psycopg.AsyncConnection.connect(self.dsn, prepare_threshold=None, application_name="movemark-load-gate") as conn:
            while time.monotonic() < deadline:
                name = random.choices(names, weights)[0]
                t0 = time.monotonic()
                try:
                    await self.op(conn, name)
                    self.lat[name].append((time.monotonic() - t0) * 1000)
                except psycopg.Error as error:
                    self.errors[f"{name}:{error.sqlstate or type(error).__name__}"] += 1
                    await conn.rollback()

    async def level(self, sessions: int, seconds: float) -> dict:
        self.lat.clear()
        deadline = time.monotonic() + seconds
        await asyncio.gather(*[self.session(deadline) for _ in range(sessions)])
        out = {"sessions": sessions}
        for name, values in sorted(self.lat.items()):
            v = sorted(values)
            q = lambda f: round(v[min(len(v) - 1, int(f * len(v)))], 1)  # noqa: E731
            out[name] = {"ops_s": round(len(v) / seconds, 1), "p50": q(0.5), "p95": q(0.95), "p99": q(0.99)}
        out["total_ops_s"] = round(sum(len(v) for v in self.lat.values()) / seconds, 1)
        return out

    async def invariants(self) -> list[str]:
        problems = []
        async with await psycopg.AsyncConnection.connect(self.owner_dsn) as c:
            final = (await (await c.execute(
                "SELECT coalesce(sum(balance), 0) FROM user_report_credits WHERE user_id = ANY(%s::uuid[])",
                ([u for u, _, _ in self.spenders],))).fetchone())[0]
            if self.initial_balance - final != self.spent:
                problems.append(f"credits: {self.initial_balance - final} spent in the DB vs {self.spent} enqueues that succeeded")
            if (await (await c.execute("SELECT count(*) FROM user_report_credits WHERE balance < 0")).fetchone())[0]:
                problems.append("negative credit balance")
            if len(self.claimed) != len(set(self.claimed)):
                problems.append(f"{len(self.claimed) - len(set(self.claimed))} exports claimed twice")
            left = (await (await c.execute(
                "SELECT (SELECT count(*) FROM properties WHERE user_id = ANY(%s::uuid[])) + "
                "(SELECT count(*) FROM neon_auth.\"user\" WHERE id = ANY(%s::uuid[]))", (self.deleted, self.deleted))).fetchone())[0]
            if left:
                problems.append(f"{left} rows left behind by deleted accounts")
        bad = {k: v for k, v in self.errors.items() if not k.startswith("expected:")}
        if bad:
            problems.append(f"database errors: {bad}")
        return problems


async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dsn_file", type=pathlib.Path)
    ap.add_argument("--owner-dsn-file", type=pathlib.Path, required=True)
    ap.add_argument("--levels", default="10,25,50,100")
    ap.add_argument("--seconds", type=float, default=45)
    args = ap.parse_args()
    gate = Gate(args.dsn_file.expanduser().read_text().strip(), args.owner_dsn_file.expanduser().read_text().strip())
    await gate.setup()
    for n in (int(x) for x in args.levels.split(",")):
        print(json.dumps(await gate.level(n, args.seconds)), flush=True)
    problems = await gate.invariants()
    print(json.dumps({"claimed": len(gate.claimed), "credit_enqueues": gate.spent, "accounts_deleted": len(gate.deleted),
                      "errors": dict(gate.errors)}))
    for p in problems:
        print("PROBLEM:", p)
    print("LOAD_GATE", "PASS" if not problems else "FAIL")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
