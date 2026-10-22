"""MoveMark — query-plan benchmark for the hot queries of the apps, API and worker.

    ../movemark-api-py/.venv/bin/python scripts/db/bench_plans.py postgresql:///mm_bench_local [label]

Runs against a synthetic dataset (scripts/db/synth_scale.sql) — never dev or production. Each query runs
EXPLAIN (ANALYZE, BUFFERS) `RUNS` times; the report gives the median execution time, the buffers touched
and every sequential scan of a large table. Native-app queries run as `authenticated` with simulated JWT
claims, so RLS policies are part of the measured plan (local shim only: Neon's auth.user_id() reads a
verified session JWT instead). Writes run inside a transaction that is rolled back.
"""
from __future__ import annotations

import json
import statistics
import sys

import psycopg

RUNS = 5
LARGE = 50_000  # a Seq Scan over a table this size is reported


def pick(conn: psycopg.Connection) -> dict[str, str]:
    """Representative ids: a typical user/property/item, and the 'years of use' property."""
    q = lambda sql: conn.execute(sql).fetchone()[0]  # noqa: E731
    big = q("SELECT property_id FROM evidence_files GROUP BY property_id ORDER BY count(*) DESC LIMIT 1")
    typical = q(f"SELECT id FROM properties WHERE id <> '{big}' ORDER BY id OFFSET 12345 LIMIT 1")
    ids = {
        "P": typical, "U": q(f"SELECT user_id FROM properties WHERE id = '{typical}'"),
        "B": big, "UB": q(f"SELECT user_id FROM properties WHERE id = '{big}'"),
        "R": q(f"SELECT id FROM rooms WHERE property_id = '{typical}' ORDER BY sort_order LIMIT 1"),
        "INSP": q(f"SELECT id FROM inspections WHERE property_id = '{typical}' AND inspection_type = 'move_in'"),
        "D": q("SELECT id FROM disputes ORDER BY id OFFSET 500 LIMIT 1"),
    }
    ids["I"] = q(f"SELECT id FROM inspection_items WHERE inspection_id = '{ids['INSP']}' ORDER BY id LIMIT 1")
    ids["PATH"] = q(f"SELECT thumbnail_path FROM evidence_files WHERE inspection_item_id = '{ids['I']}' LIMIT 1")
    ids["NOPE"] = f"{ids['U']}/{typical}/move-in/{ids['R']}/never-referenced.jpg"
    ids["EIDS"] = "{" + ",".join(r[0].__str__() for r in conn.execute(
        f"SELECT id FROM evidence_files WHERE property_id = '{typical}' LIMIT 20").fetchall()) + "}"
    return {k: str(v) for k, v in ids.items()}


# (name, who, sql) — who: "app" = authenticated under RLS as U (or UB for *_big), "api" = backend.
QUERIES: list[tuple[str, str, str]] = [
    ("app.properties_by_user", "app", "SELECT * FROM properties WHERE user_id = '{U}' ORDER BY created_at"),
    ("app.rooms_by_property", "app", "SELECT * FROM rooms WHERE property_id = '{P}' ORDER BY sort_order"),
    ("app.snapshot", "app", "SELECT get_property_snapshot('{P}')"),
    ("app.snapshot_big", "app_big", "SELECT get_property_snapshot('{B}')"),
    ("app.evidence_by_property", "app", "SELECT * FROM evidence_files WHERE property_id = '{P}'"),
    ("app.evidence_by_property_big", "app_big", "SELECT * FROM evidence_files WHERE property_id = '{B}'"),
    ("app.evidence_by_item", "app", "SELECT * FROM evidence_files WHERE inspection_item_id = '{I}'"),
    ("app.signed_url_lookup", "app", "SELECT id, file_path, thumbnail_path FROM evidence_files "
                                     "WHERE file_path = '{PATH}' OR thumbnail_path = '{PATH}'"),
    ("app.items_by_room", "app", "SELECT * FROM inspection_items WHERE room_id = '{R}'"),
    ("app.maintenance_list", "app", "SELECT * FROM maintenance_issues WHERE property_id = '{P}' "
                                    "ORDER BY date_reported DESC LIMIT 200"),
    ("app.documents_list", "app", "SELECT * FROM property_documents WHERE property_id = '{P}' LIMIT 300"),
    ("app.exports_list", "app", "SELECT * FROM exports WHERE property_id = '{P}' ORDER BY created_at DESC"),
    ("app.insert_item", "app_write", "INSERT INTO inspection_items (inspection_id, room_id, notes) "
                                     "VALUES ('{INSP}', '{R}', 'bench')"),
    ("app.insert_evidence", "app_write", "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) "
                                         "VALUES ('{P}', '{I}', '{U}/{P}/move-in/{R}/bench.jpg', 'image')"),
    ("api.claim_export_job", "api_write", "SELECT id FROM claim_next_export_job()"),
    ("api.reap_stuck_jobs", "api_write", "SELECT reap_stuck_export_jobs(interval '5 minutes', 3)"),
    # Abandon's "is this upload referenced?" check, for an upload no row references (the normal abandon).
    ("api.abandon_check_lower", "api",
     "SELECT EXISTS (SELECT 1 FROM evidence_files WHERE lower(file_path) = ANY('{{{NOPE}}}') "
     "OR lower(thumbnail_path) = ANY('{{{NOPE}}}') OR lower(source_path) = ANY('{{{NOPE}}}')) "
     "OR EXISTS (SELECT 1 FROM property_documents WHERE lower(file_path) = ANY('{{{NOPE}}}') "
     "OR lower(thumbnail_path) = ANY('{{{NOPE}}}'))"),
    ("api.abandon_check_exact", "api",
     "SELECT EXISTS (SELECT 1 FROM evidence_files WHERE file_path = ANY('{{{NOPE}}}') "
     "OR thumbnail_path = ANY('{{{NOPE}}}') OR source_path = ANY('{{{NOPE}}}')) "
     "OR EXISTS (SELECT 1 FROM property_documents WHERE file_path = ANY('{{{NOPE}}}') "
     "OR thumbnail_path = ANY('{{{NOPE}}}'))"),
    ("api.vault_exports", "api", "SELECT id, export_type, status, created_at FROM exports "
                                 "WHERE property_id = '{P}' AND user_id = '{U}' ORDER BY created_at DESC"),
    ("api.dispute_catalog_photos", "api", "SELECT id, file_path, thumbnail_path, captured_at FROM evidence_files "
                                          "WHERE property_id = '{B}' ORDER BY created_at DESC"),
    ("api.dispute_links", "api", "SELECT * FROM dispute_evidence_links WHERE dispute_id = '{D}'"),
    ("api.owned_evidence", "api", "SELECT ef.id FROM evidence_files ef JOIN properties p ON p.id = ef.property_id "
                                  "WHERE ef.id = ANY('{EIDS}'::uuid[]) AND p.user_id = '{U}'"),
    ("api.delete_user_owned_data", "api_write", "SELECT delete_user_owned_data('{U}')"),
    ("api.expired_ticket_sweep", "api", "SELECT id FROM storage_upload_tickets WHERE state IN ('issued','finalized') "
                                        "AND expires_at < now() ORDER BY expires_at LIMIT 100"),
]


def seq_scans(plan: dict, sizes: dict[str, int]) -> list[str]:
    found = []
    if plan.get("Node Type") == "Seq Scan" and sizes.get(plan.get("Relation Name", ""), 0) >= LARGE:
        found.append(plan["Relation Name"])
    for child in plan.get("Plans", []):
        found += seq_scans(child, sizes)
    return found


def run(dsn: str, label: str) -> None:
    with psycopg.connect(dsn) as conn:
        host = conn.info.host or ""
        if "ep-steep-wind" in host or "ep-quiet-salad" in host:
            sys.exit("refusing: dev/production endpoint")
        ids = pick(conn)
        sizes = dict(conn.execute("SELECT relname, n_live_tup FROM pg_stat_user_tables").fetchall())
        conn.rollback()
        print(f"## {label}\n\n| query | median ms | buffers | large seq scans |\n|---|---:|---:|---|")
        for name, who, template in QUERIES:
            sql = template.format(**ids)
            times, buffers, scans = [], 0, set()
            for _ in range(RUNS):
                with conn.transaction(force_rollback=True):
                    if who.startswith("app"):
                        user = ids["UB"] if who == "app_big" else ids["U"]
                        conn.execute("SELECT set_config('request.jwt.claims', %s, true)", (json.dumps({"sub": user, "role": "authenticated"}),))
                        conn.execute("SET LOCAL ROLE authenticated")
                    out = conn.execute(f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {sql}").fetchone()[0][0]
                times.append(out["Execution Time"])
                plan = out["Plan"]
                buffers = plan.get("Shared Hit Blocks", 0) + plan.get("Shared Read Blocks", 0)
                scans |= set(seq_scans(plan, sizes))
            print(f"| {name} | {statistics.median(times):.2f} | {buffers} | {', '.join(sorted(scans)) or '—'} |")


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "baseline")
