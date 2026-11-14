"""The legal gate through the REAL Neon Data API on a non-production branch, with real JWTs.

Same harness and rules as data_api_e2e.py: disposable QA users, every case printed with its HTTP status and
body, rows and users removed at the end. The gate is turned on for the run and put back as it was found.
Needs active documents on the branch (neon/legal_gate_dev.py seed).

    MM_NEON_AUTH_URL=... MM_NEON_DATA_API_URL=... MM_NEON_OWNER_DSN_FILE=... \\
      [MM_NEON_API_DSN_FILE=...]  # movemark_api on this branch: also checks the runtime grants
      [MM_LEGAL_E2E_PUBLISH=1]    # disposable branches only: publishes a new version (documents are append-only)
      python neon/tests/legal_gate_data_api_e2e.py
"""
from __future__ import annotations

import os
import sys
import uuid

import psycopg

import data_api_e2e as h
from data_api_e2e import api, cleanup, record, results, seed, sign_up

if h.PRODUCTION_ENDPOINT in h.OWNER_DSN:
    sys.exit("refusing to run against production")
h.EMAILS.update({"A": "qa-legal-a@movemark.test", "B": "qa-legal-b@movemark.test"})

TABLES = [("properties", "property"), ("rooms", "room"), ("inspections", "inspection"), ("inspection_items", "item"),
          ("evidence_files", "evidence")]


def owner(sql: str, *params: object) -> list[tuple]:
    with psycopg.connect(h.OWNER_DSN, autocommit=True) as conn:
        cur = conn.execute(sql, params)
        return cur.fetchall() if cur.description else []


def enforce(on: bool) -> None:
    owner("UPDATE public.legal_gate_settings SET enforced = %s, updated_at = now()", on)


def status(c: h.httpx.Client) -> dict:
    return c.post("/rpc/get_legal_status", json={}).json()


def accept(c: h.httpx.Client, method: str, terms: str | None, notice: str | None) -> h.httpx.Response:
    return c.post("/rpc/accept_legal_documents", json={"p_method": method, "p_terms_version": terms, "p_privacy_notice_version": notice})


def main() -> None:
    was_enforced = owner("SELECT enforced FROM public.legal_gate_settings")[0][0]
    active = dict(owner("SELECT kind, version FROM public.legal_documents WHERE active"))
    if len(active) != 2:
        sys.exit("no active documents on this branch: run neon/legal_gate_dev.py seed first")
    terms, notice = active["terms"], active["privacy_notice"]
    cleanup([])
    enforce(False)
    a_id, a_tok = sign_up("A")
    b_id, b_tok = sign_up("B")
    try:
        with api(a_tok) as a, api(b_tok) as b, api(None) as anon:
            ra, rb = seed(a, a_id, "A"), seed(b, b_id, "B")
            r = a.post("/maintenance_issues", json={"property_id": ra["property"], "user_id": a_id, "title": "Leak"})
            record("A creates maintenance issue (gate off)", r.status_code == 201, r)

            s = status(a)
            record("gate off: acceptance reported as required, nothing blocked",
                   (s["enforced"], s["acceptance_required"], s["blocked"]) == (False, True, False), r)
            r = a.get("/properties?select=id")
            record("gate off: unaccepted user reads own rental", len(r.json()) == 1, r)

            enforce(True)
            r = a.post("/rpc/get_legal_status", json={})
            record("blocked: status RPC answers", r.status_code == 200 and r.json()["blocked"] is True, r)
            for table, key in TABLES + [("maintenance_issues", None)]:
                r = a.get(f"/{table}?select=id")
                record(f"blocked: {table} reads empty", r.status_code == 200 and r.json() == [], r)
            r = a.get("/profiles?select=id")
            record("blocked: own profile readable", [x["id"] for x in r.json()] == [a_id], r)
            r = a.get("/legal_documents?select=kind,version&active=is.true")
            record("blocked: legal documents readable", r.status_code == 200 and len(r.json()) == 2, r)
            r = a.post("/rooms", json={"property_id": ra["property"], "name": "Hall"})
            record("blocked: INSERT refused 403/42501", r.status_code == 403 and r.json().get("code") == "42501", r)
            r = a.patch(f"/properties?id=eq.{ra['property']}", json={"title": "x"})
            record("blocked: UPDATE matches nothing", r.status_code == 200 and r.json() == [], r)
            r = a.delete(f"/evidence_files?id=eq.{ra['evidence']}")
            record("blocked: DELETE matches nothing", r.status_code == 200 and r.json() == [], r)
            r = a.post("/rpc/get_property_snapshot_v2", json={"p_property_id": ra["property"]})
            j = r.json()
            record("blocked: snapshot v2 empty", r.status_code == 200 and j["property"] is None and j["maintenance_issues"] == [], r)
            r = a.post("/rpc/get_property_snapshot", json={"p_property_id": ra["property"]})
            record("blocked: snapshot v1 empty", r.status_code == 200 and r.json()["maintenance_issues"] == [], r)
            r = a.post("/rpc/get_vault_summaries", json={})
            record("blocked: vault summaries empty", r.status_code == 200 and r.json() == [], r)

            # Refused acceptances and direct writes.
            r = accept(a, "facebook", terms, notice)
            record("accept: unknown method refused", r.status_code >= 400 and r.json().get("message") == "LEGAL_INVALID_METHOD", r)
            r = accept(a, "email", "old", notice)
            record("accept: inactive version refused", r.status_code >= 400 and r.json().get("message") == "LEGAL_VERSION_NOT_ACTIVE", r)
            r = a.post("/rpc/accept_legal_documents", json={"p_method": "email", "p_terms_version": terms, "p_privacy_notice_version": notice,
                                                            "p_accepted_at": "2020-01-01T00:00:00Z"})
            record("accept: client-supplied time has no such parameter", r.status_code >= 400, r)
            r = a.post("/legal_acceptances", json={"user_id": a_id, "terms_version": terms, "privacy_notice_version": notice,
                                                   "accepted_at": "2020-01-01T00:00:00Z", "acceptance_method": "email", "document_hashes": {}})
            record("direct INSERT into legal_acceptances refused", r.status_code in (401, 403), r)
            r = a.get("/legal_gate_settings?select=enforced")
            record("legal_gate_settings not reachable", r.status_code in (401, 403, 404), r)
            r = a.patch("/legal_gate_settings", json={"enforced": False})
            record("legal_gate_settings not writable", r.status_code in (401, 403, 404), r)
            for fn in ("legal_status_for_user", "legal_gate_open_for_user", "legal_user_has_current_acceptance"):
                r = a.post(f"/rpc/{fn}", json={"target_user_id": b_id})
                record(f"client cannot call {fn}", r.status_code in (401, 403, 404), r)
            r = anon.post("/rpc/get_legal_status", json={})
            record("anonymous refused", h.rejected_without_token(r), r)

            # Accepting.
            r = accept(a, "email", terms, notice)
            first = r.json() if r.status_code == 200 else {}
            record("A accepts", r.status_code == 200 and first.get("blocked") is False and first.get("accepted", {}).get("acceptance_method") == "email", r)
            r = accept(a, "apple", terms, notice)
            record("replay: same row, same time and method", r.status_code == 200 and r.json()["accepted"] == first["accepted"], r)
            n = owner("SELECT count(*) FROM public.legal_acceptances WHERE user_id = %s", a_id)[0][0]
            results.append(("one acceptance row after replay", n == 1, 0, f"rows={n}"))
            for table, key in TABLES:
                r = a.get(f"/{table}?select=id")
                record(f"accepted: A reads own {table}", [x["id"] for x in r.json()] == [ra[key]], r)
                r = b.get(f"/{table}?select=id")
                record(f"unaccepted: B still reads no {table}", r.json() == [], r)
                r = a.get(f"/{table}?id=eq.{rb[key]}&select=id")
                record(f"accepted: A cannot read B's {table}", r.json() == [], r)
            r = accept(b, "google", terms, notice)
            record("B accepts", r.status_code == 200, r)
            r = a.get(f"/properties?id=eq.{rb['property']}&select=id")
            record("both accepted: isolation holds", r.json() == [], r)
            r = a.get("/legal_acceptances?select=user_id")
            record("own acceptances only", [x["user_id"] for x in r.json()] == [a_id], r)

            if os.getenv("MM_LEGAL_E2E_PUBLISH") == "1":
                tag = uuid.uuid4().hex[:8]
                owner("SELECT public.publish_legal_document('terms', %s, %s, NULL, false)", f"draft-e2e-{tag}", "0" * 64)
                r = a.get("/properties?select=id")
                record("new version: rental hidden again", r.json() == [], r)
                s = status(a)
                record("new version: blocked again", s["blocked"] is True and s["accepted"] is None, r)
                r = accept(a, "email", terms, notice)
                record("new version: stale screen refused", r.status_code >= 400 and r.json().get("message") == "LEGAL_VERSION_NOT_ACTIVE", r)
                r = accept(a, "email", f"draft-e2e-{tag}", notice)
                record("new version: accepting it works", r.status_code == 200, r)
                r = a.get("/properties?select=id")
                record("new version: data intact after accepting", [x["id"] for x in r.json()] == [ra["property"]], r)

            if os.getenv("MM_NEON_API_DSN_FILE"):
                with psycopg.connect(open(os.environ["MM_NEON_API_DSN_FILE"]).read().strip(), autocommit=True) as rt:
                    ok = rt.execute("SELECT public.legal_gate_open_for_user(%s), (public.legal_status_for_user(%s))->>'blocked'", (a_id, a_id)).fetchone()
                    results.append(("movemark_api reads the gate", ok[0] is True, 0, str(ok)))
                    blocked = str(uuid.uuid4())
                    ok = rt.execute("SELECT public.legal_gate_open_for_user(%s)", (blocked,)).fetchone()
                    results.append(("movemark_api: unknown user is closed", ok[0] is False, 0, str(ok)))
                    try:
                        rt.execute("SELECT count(*) FROM public.legal_acceptances")
                        results.append(("movemark_api cannot read the table", False, 0, "read"))
                    except psycopg.errors.InsufficientPrivilege as e:
                        results.append(("movemark_api cannot read the table", True, 0, str(e)[:80]))
                    # Account deletion of a user who is blocked at this moment, by the API's own role.
                    rt.execute("SELECT public.delete_user_owned_data(%s)", (b_id,))
                    rt.execute("DELETE FROM public.storage_upload_tickets WHERE user_id = %s", (b_id,))
                    rt.execute("SELECT public.delete_auth_user(%s)", (b_id,))
                left = owner("SELECT (SELECT count(*) FROM public.properties WHERE user_id = %s), (SELECT count(*) FROM public.legal_acceptances WHERE user_id = %s), "
                             "(SELECT count(*) FROM neon_auth.\"user\" WHERE id = %s)", b_id, b_id, b_id)[0]
                results.append(("account deletion as movemark_api leaves nothing", left == (0, 0, 0), 0, str(left)))
    finally:
        enforce(was_enforced)
        cleanup([a_id, b_id])

    width = max(len(c) for c, *_ in results)
    for case, ok, code, body in results:
        print(f"{'PASS' if ok else 'FAIL'}  {case:<{width}}  HTTP {code}  {body}")
    failed = [c for c, ok, *_ in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} passed; enforced restored to {was_enforced}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
