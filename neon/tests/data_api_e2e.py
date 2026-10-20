"""Two-user security test through the REAL Neon Data API on a non-production branch.

Signs up two disposable QA users on the branch's Neon Auth, obtains real JWTs, and
exercises RLS and function privileges over HTTP exactly as the apps will. Prints the
HTTP status and response body for every case. Cleans up its rows and both QA users
(via the owner DSN) at the end.

    MM_NEON_AUTH_URL=...  MM_NEON_DATA_API_URL=...  MM_NEON_OWNER_DSN_FILE=...  \\
      python neon/tests/data_api_e2e.py

Refuses to run against the production endpoints.
"""
from __future__ import annotations

import json
import os
import secrets
import sys
import uuid

import httpx
import psycopg

AUTH = os.environ["MM_NEON_AUTH_URL"].rstrip("/")
API = os.environ["MM_NEON_DATA_API_URL"].rstrip("/")
OWNER_DSN = open(os.environ["MM_NEON_OWNER_DSN_FILE"]).read().strip()
PRODUCTION_ENDPOINT = "ep-steep-wind-b56266ss"
if PRODUCTION_ENDPOINT in AUTH or PRODUCTION_ENDPOINT in API:
    sys.exit("refusing to run against production")

EMAILS = {"A": "qa-neon-a@movemark.test", "B": "qa-neon-b@movemark.test"}
ORIGIN = AUTH.split("/neondb")[0]
results: list[tuple[str, bool, int, str]] = []


def record(case: str, ok: bool, resp: httpx.Response) -> None:
    body = resp.text if len(resp.text) < 220 else resp.text[:220] + "…"
    results.append((case, ok, resp.status_code, body))


def sign_up(label: str) -> tuple[str, str]:
    password = secrets.token_urlsafe(24)  # never printed or stored
    with httpx.Client(timeout=30, headers={"Origin": ORIGIN}) as c:
        r = c.post(f"{AUTH}/sign-up/email", json={"email": EMAILS[label], "password": password, "name": f"QA {label}"})
        if r.status_code >= 400:
            sys.exit(f"sign-up {label} failed: {r.status_code} {r.text[:300]}")
        user_id = r.json()["user"]["id"]
        t = c.get(f"{AUTH}/token")
        if t.status_code >= 400 or "token" not in t.json():
            sys.exit(f"token {label} failed: {t.status_code} {t.text[:300]}")
        return user_id, t.json()["token"]


def rejected_without_token(r: httpx.Response) -> bool:
    """Neon's Data API refuses token-less requests before any SQL runs (HTTP 400)."""
    return r.status_code == 400 and "missing authentication credentials" in r.text


def api(token: str | None) -> httpx.Client:
    headers = {"Content-Type": "application/json", "Prefer": "return=representation"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return httpx.Client(base_url=API, timeout=30, headers=headers)


def cleanup(ids: list[str]) -> None:
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        for uid in ids:
            conn.execute("SELECT public.delete_user_owned_data(%s)", (uid,))
            conn.execute('DELETE FROM neon_auth.session WHERE "userId" = %s', (uid,))
            conn.execute('DELETE FROM neon_auth.account WHERE "userId" = %s', (uid,))
            conn.execute('DELETE FROM neon_auth."user" WHERE id = %s', (uid,))
        conn.execute("DELETE FROM neon_auth.\"user\" WHERE email IN (%s, %s)", tuple(EMAILS.values()))


def seed(c: httpx.Client, uid: str, label: str) -> dict[str, str]:
    ids: dict[str, str] = {}
    r = c.post("/profiles", json={"id": uid, "email": EMAILS[label], "full_name": f"QA {label}"})
    record(f"{label} creates own profile", r.status_code == 201, r)
    r = c.post("/properties", json={"user_id": uid, "title": f"QA ONLY {label}", "address_line_1": "88 Harbour St",
                                    "city": "Toronto", "province_state": "ON", "postal_code": "M5J", "country": "CA"})
    record(f"{label} creates own property", r.status_code == 201, r)
    ids["property"] = r.json()[0]["id"]
    r = c.post("/rooms", json={"property_id": ids["property"], "name": "Kitchen", "sort_order": 0})
    record(f"{label} creates room in own property", r.status_code == 201, r)
    ids["room"] = r.json()[0]["id"]
    r = c.post("/inspections", json={"property_id": ids["property"], "user_id": uid, "inspection_type": "move_in"})
    record(f"{label} creates own inspection", r.status_code == 201, r)
    ids["inspection"] = r.json()[0]["id"]
    r = c.post("/inspection_items", json={"inspection_id": ids["inspection"], "room_id": ids["room"], "notes": "Wall\nscratch", "condition_rating": 3})
    record(f"{label} creates inspection item", r.status_code == 201, r)
    ids["item"] = r.json()[0]["id"]
    r = c.post("/evidence_files", json={"property_id": ids["property"], "inspection_item_id": ids["item"],
                                        "file_path": f"{uid}/{ids['property']}/move-in/{ids['room']}/1.jpg", "file_type": "image"})
    record(f"{label} creates evidence row", r.status_code == 201, r)
    ids["evidence"] = r.json()[0]["id"]
    return ids


def main() -> None:
    cleanup([])  # leftovers from an interrupted run
    a_id, a_tok = sign_up("A")
    b_id, b_tok = sign_up("B")
    try:
        with api(a_tok) as a, api(b_tok) as b, api(None) as anon:
            ra, rb = seed(a, a_id, "A"), seed(b, b_id, "B")

            # Own-row update/delete work (proves auth.user_id() == JWT sub through the Data API).
            r = a.patch(f"/properties?id=eq.{ra['property']}", json={"title": "QA ONLY A (edited)"})
            record("A updates own property", r.status_code == 200 and len(r.json()) == 1, r)
            r = a.get("/profiles?select=id")
            record("A sees exactly own profile", r.status_code == 200 and [x["id"] for x in r.json()] == [a_id], r)

            # Cross-user isolation.
            for table, key in [("properties", "property"), ("rooms", "room"), ("inspections", "inspection"),
                               ("inspection_items", "item"), ("evidence_files", "evidence")]:
                r = a.get(f"/{table}?id=eq.{rb[key]}&select=id")
                record(f"A cannot SELECT B's {table}", r.status_code == 200 and r.json() == [], r)
                col = {"properties": "title", "rooms": "name", "inspections": "overall_notes",
                       "inspection_items": "notes", "evidence_files": "file_path"}[table]
                r = a.patch(f"/{table}?id=eq.{rb[key]}", json={col: "hijacked"})
                record(f"A cannot UPDATE B's {table}", r.status_code == 200 and r.json() == [], r)
            r2 = b.get(f"/properties?id=eq.{rb['property']}&select=title")
            record("B's property title unchanged after A's attempts", r2.json()[0]["title"] == "QA ONLY B", r2)
            r = a.delete(f"/evidence_files?id=eq.{rb['evidence']}")
            record("A cannot DELETE B's evidence row", r.status_code == 200 and r.json() == [], r)
            r = a.delete(f"/properties?id=eq.{rb['property']}")
            record("A cannot DELETE B's property", r.status_code == 200 and r.json() == [], r)
            r2 = b.get(f"/evidence_files?id=eq.{rb['evidence']}&select=id")
            record("B's evidence still exists", r2.status_code == 200 and len(r2.json()) == 1, r2)

            # Child rows hanging off B's data.
            for case, path, body in [
                ("A cannot INSERT room into B's property", "/rooms", {"property_id": rb["property"], "name": "x"}),
                ("A cannot INSERT item into B's inspection", "/inspection_items", {"inspection_id": rb["inspection"], "room_id": rb["room"]}),
                ("A cannot INSERT evidence on B's property", "/evidence_files", {"property_id": rb["property"], "inspection_item_id": rb["item"], "file_path": "x", "file_type": "image"}),
                ("A cannot INSERT evidence in own property pointing at B's item", "/evidence_files", {"property_id": ra["property"], "inspection_item_id": rb["item"], "file_path": "x", "file_type": "image"}),
                ("A cannot record a storage key in B's folder (0910)", "/evidence_files", {"property_id": ra["property"], "inspection_item_id": ra["item"], "file_path": f"{b_id}/{rb['property']}/move-in/{rb['room']}/1.jpg", "file_type": "image"}),
                ("A cannot INSERT property owned by B", "/properties", {"user_id": b_id, "title": "x", "address_line_1": "x", "city": "x", "province_state": "x", "postal_code": "x", "country": "x"}),
            ]:
                r = a.post(path, json=body)
                record(case, r.status_code in (401, 403), r)

            # Forged token: A's token with the payload's `sub` swapped to B (signature now invalid).
            import base64
            head, payload, sig = a_tok.split(".")
            claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
            claims["sub"] = b_id
            forged_payload = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
            with api(f"{head}.{forged_payload}.{sig}") as forged:
                r = forged.get(f"/properties?id=eq.{rb['property']}&select=id")
                record("forged token claiming B is rejected", r.status_code in (400, 401, 403) and "QA ONLY B" not in r.text and rb["property"] not in r.text, r)

            # Anonymous.
            for table in ["properties", "evidence_files", "profiles"]:
                r = anon.get(f"/{table}?select=id")
                record(f"anonymous cannot read {table}", rejected_without_token(r), r)

            # Snapshot RPC.
            r = a.post("/rpc/get_property_snapshot", json={"p_property_id": ra["property"]})
            ok = r.status_code == 200 and r.json()["property"]["id"] == ra["property"] and len(r.json()["evidence_files"]) == 1
            record("A's snapshot returns A's property", ok, r)
            r = a.post("/rpc/get_property_snapshot", json={"p_property_id": rb["property"]})
            ok = r.status_code == 200 and r.json()["property"] is None and r.json()["evidence_files"] == []
            record("A's snapshot of B's property is empty", ok, r)
            r = anon.post("/rpc/get_property_snapshot", json={"p_property_id": rb["property"]})
            record("anonymous cannot call snapshot", rejected_without_token(r), r)

            # Privileged functions.
            for fn, body in [("delete_user_owned_data", {"target_user_id": b_id}),
                             ("grant_report_credit", {"target_user_id": a_id, "event_key": "qa-free-credit", "product_id": None}),
                             ("consume_report_credit", {"target_user_id": a_id, "event_key": "qa"}),
                             ("claim_next_export_job", {}),
                             ("reap_stuck_export_jobs", {})]:
                r = a.post(f"/rpc/{fn}", json=body)
                record(f"A cannot call {fn}", r.status_code in (401, 403, 404), r)
            r2 = b.get(f"/properties?id=eq.{rb['property']}&select=id")
            record("B's data intact after A's delete_user_owned_data attempt", len(r2.json()) == 1, r2)

            # Owners delete their own rows.
            r = a.delete(f"/evidence_files?id=eq.{ra['evidence']}")
            record("A deletes own evidence row", r.status_code == 200 and len(r.json()) == 1, r)
    finally:
        cleanup([a_id, b_id])

    width = max(len(c) for c, *_ in results)
    for case, ok, status, body in results:
        print(f"{'PASS' if ok else 'FAIL'}  {case:<{width}}  HTTP {status}  {body}")
    failed = [c for c, ok, *_ in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
