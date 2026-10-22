"""Reconstruction gate for the Neon database.

Builds a fresh database from zero (local shim + every file in neon/migrations), then
checks the authorization behaviour the apps rely on, as the Neon Data API would run
it: `SET ROLE authenticated` with the user's id in the simulated JWT claims.

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests -q

Needs a local Postgres (MOVEMARK_TEST_ADMIN_DSN, default postgresql:///postgres).
"""
from __future__ import annotations

import json
import os
import pathlib
import uuid
from contextlib import contextmanager
from typing import Any, Iterator

import pytest

psycopg = pytest.importorskip("psycopg")
from psycopg import errors  # noqa: E402

NEON = pathlib.Path(__file__).resolve().parents[1]
ADMIN_DSN = os.getenv("MOVEMARK_TEST_ADMIN_DSN", "postgresql:///postgres")
DB = "movemark_neon_gate"

A = str(uuid.UUID("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"))
B = str(uuid.UUID("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"))


@pytest.fixture(scope="session")
def dsn() -> Iterator[str]:
    try:
        admin = psycopg.connect(ADMIN_DSN, autocommit=True, connect_timeout=3)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"no local Postgres: {e}")
    with admin, admin.cursor() as cur:
        cur.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')
        cur.execute(f'CREATE DATABASE "{DB}"')
    url = f"postgresql:///{DB}"
    with psycopg.connect(url, autocommit=True) as conn, conn.cursor() as cur:
        cur.execute((NEON / "tests" / "neon_platform_shim.sql").read_text())
        for f in sorted((NEON / "migrations").glob("*.sql")):
            cur.execute(f.read_text())
        cur.execute("INSERT INTO neon_auth.\"user\" (id, email) VALUES (%s, 'a@qa.test'), (%s, 'b@qa.test')", (A, B))
    yield url
    with psycopg.connect(ADMIN_DSN, autocommit=True) as admin2, admin2.cursor() as cur:
        cur.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')


@pytest.fixture
def owner(dsn: str) -> Iterator[Any]:
    """The trusted backend's connection (table owner; RLS does not apply)."""
    with psycopg.connect(dsn, autocommit=True) as conn:
        yield conn


@contextmanager
def as_user(dsn: str, user_id: str | None) -> Iterator[Any]:
    """A Data API request: role `authenticated` (or `anonymous`) with JWT claims."""
    conn = psycopg.connect(dsn)
    try:
        with conn.cursor() as cur:
            if user_id is None:
                cur.execute("SET ROLE anonymous")
            else:
                cur.execute("SET ROLE authenticated")
                cur.execute("SELECT set_config('request.jwt.claims', %s, false)", (json.dumps({"sub": user_id}),))
        yield conn
    finally:
        conn.rollback()
        conn.close()


def one(conn: Any, sql: str, params: tuple = ()) -> Any:
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchone()


def rows(conn: Any, sql: str, params: tuple = ()) -> list[Any]:
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall() if cur.description else []


def seed_rental(dsn: str, user: str) -> dict[str, str]:
    """Create a complete rental exactly as the apps do, through RLS, as `user`."""
    with as_user(dsn, user) as c:
        ids: dict[str, str] = {}
        ids["profile"] = one(c, "INSERT INTO profiles (id, email, full_name) VALUES (%s, %s, 'QA') RETURNING id", (user, f"{user[:4]}@qa.test"))[0]
        ids["property"] = str(one(c, """INSERT INTO properties (user_id, title, address_line_1, city, province_state, postal_code, country)
            VALUES (%s, 'QA ONLY', '88 Harbour St', 'Toronto', 'ON', 'M5J', 'CA') RETURNING id""", (user,))[0])
        ids["room"] = str(one(c, "INSERT INTO rooms (property_id, name, sort_order) VALUES (%s, 'Kitchen', 0) RETURNING id", (ids["property"],))[0])
        ids["inspection"] = str(one(c, "INSERT INTO inspections (property_id, user_id, inspection_type) VALUES (%s, %s, 'move_in') RETURNING id", (ids["property"], user))[0])
        ids["item"] = str(one(c, "INSERT INTO inspection_items (inspection_id, room_id, notes, condition_rating) VALUES (%s, %s, 'Wall\nscratch', 3) RETURNING id", (ids["inspection"], ids["room"]))[0])
        ids["evidence"] = str(one(c, """INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type, thumbnail_path)
            VALUES (%s, %s, %s, 'image', %s) RETURNING id""", (ids["property"], ids["item"],
            f"{user}/{ids['property']}/move-in/{ids['room']}/1.jpg", f"{user}/{ids['property']}/move-in/{ids['room']}/1_thumb.jpg"))[0])
        tag = one(c, "SELECT id FROM issue_tags WHERE name = 'Scratch'")[0]
        c.execute("INSERT INTO inspection_item_tags (inspection_item_id, issue_tag_id) VALUES (%s, %s)", (ids["item"], tag))
        ids["maintenance"] = str(one(c, "INSERT INTO maintenance_issues (property_id, user_id, title) VALUES (%s, %s, 'Leak') RETURNING id", (ids["property"], user))[0])
        ids["document"] = str(one(c, """INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name)
            VALUES (%s, %s, 'lease', %s, 'lease.pdf') RETURNING id""", (ids["property"], user, f"{user}/{ids['property']}/lease/l.pdf"))[0])
        ids["checklist"] = str(one(c, "INSERT INTO move_out_checklists (property_id, user_id) VALUES (%s, %s) RETURNING id", (ids["property"], user))[0])
        c.commit()
    return ids


# --- schema gate ---------------------------------------------------------------

def test_every_public_table_has_rls(owner: Any) -> None:
    missing = rows(owner, """SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity""")
    assert missing == []


def test_no_extension_functions_exposed_in_public(owner: Any) -> None:
    exposed = rows(owner, """SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        JOIN pg_depend d ON d.objid = p.oid AND d.deptype = 'e' WHERE n.nspname = 'public'""")
    assert exposed == []


def test_issue_tags_seeded(owner: Any) -> None:
    assert one(owner, "SELECT count(*) FROM issue_tags")[0] >= 6


# --- two-user isolation (Data API path) ------------------------------------------

USER_TABLES = {
    # table: (id column, a column the owner may update)
    "properties": ("id", "title"),
    "rooms": ("id", "name"),
    "inspections": ("id", "overall_notes"),
    "inspection_items": ("id", "notes"),
    "evidence_files": ("id", "captured_at"),
    "maintenance_issues": ("id", "title"),
    "property_documents": ("id", "file_name"),
    "move_out_checklists": ("id", "keys_returned"),
}
VALUE = {"title": "x", "name": "x", "overall_notes": "x", "notes": "x", "file_name": "x",
         "captured_at": "2026-10-20T00:00:00Z", "keys_returned": True}
ID_OF = {"properties": "property", "rooms": "room", "inspections": "inspection", "inspection_items": "item",
         "evidence_files": "evidence", "maintenance_issues": "maintenance", "property_documents": "document",
         "move_out_checklists": "checklist"}


@pytest.fixture(scope="module")
def two_rentals(dsn: str) -> tuple[dict[str, str], dict[str, str]]:
    return seed_rental(dsn, A), seed_rental(dsn, B)


@pytest.mark.parametrize("table", sorted(USER_TABLES))
def test_select_isolation(dsn: str, two_rentals: Any, table: str) -> None:
    a, b = two_rentals
    with as_user(dsn, A) as c:
        seen = {str(r[0]) for r in rows(c, f"SELECT id FROM {table}")}
    assert a[ID_OF[table]] in seen and b[ID_OF[table]] not in seen


def granted(c: Any, table: str, privilege: str) -> bool:
    """Whether the current (app) role holds `privilege` on `table`."""
    return c.execute("SELECT has_table_privilege(%s, %s)", (f"public.{table}", privilege)).fetchone()[0]


@pytest.mark.parametrize("table", sorted(USER_TABLES))
def test_update_isolation(dsn: str, two_rentals: Any, table: str) -> None:
    a, b = two_rentals
    col = USER_TABLES[table][1]
    with as_user(dsn, A) as c:
        if not granted(c, table, "UPDATE"):  # 0960: the apps never update this table, so nobody may
            with pytest.raises(errors.InsufficientPrivilege):
                rows(c, f"UPDATE {table} SET {col} = %s WHERE id = %s RETURNING id", (VALUE[col], b[ID_OF[table]]))
            return
        mine = rows(c, f"UPDATE {table} SET {col} = %s WHERE id = %s RETURNING id", (VALUE[col], a[ID_OF[table]]))
        theirs = rows(c, f"UPDATE {table} SET {col} = %s WHERE id = %s RETURNING id", (VALUE[col], b[ID_OF[table]]))
    assert len(mine) == 1 and theirs == []


@pytest.mark.parametrize("table", sorted(USER_TABLES))
def test_delete_isolation(dsn: str, two_rentals: Any, table: str) -> None:
    _, b = two_rentals
    with as_user(dsn, A) as c:
        if not granted(c, table, "DELETE"):
            with pytest.raises(errors.InsufficientPrivilege):
                rows(c, f"DELETE FROM {table} WHERE id = %s RETURNING id", (b[ID_OF[table]],))
            return
        gone = rows(c, f"DELETE FROM {table} WHERE id = %s RETURNING id", (b[ID_OF[table]],))
    assert gone == []


def test_profiles_isolation(dsn: str, two_rentals: Any) -> None:
    with as_user(dsn, A) as c:
        assert {str(r[0]) for r in rows(c, "SELECT id FROM profiles")} == {A}
        assert rows(c, "UPDATE profiles SET full_name = 'x' WHERE id = %s RETURNING id", (B,)) == []


INSERT_ATTACKS = {
    # A tries to write rows that hang off B's data, or claim to be B.
    "properties as B": "INSERT INTO properties (user_id, title, address_line_1, city, province_state, postal_code, country) VALUES ('{B}', 't','a','c','p','z','x')",
    "room in B's property": "INSERT INTO rooms (property_id, name) VALUES ('{bp}', 'x')",
    "inspection on B's property": "INSERT INTO inspections (property_id, user_id, inspection_type) VALUES ('{bp}', '{A}', 'move_out')",
    "item in B's inspection": "INSERT INTO inspection_items (inspection_id, room_id) VALUES ('{bi}', '{br}')",
    "key in B's folder recorded on own property": "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) VALUES ('{ap}', '{aitem}', '{B}/{bp}/move-in/r/x.jpg', 'image')",
    "evidence on B's property": "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) VALUES ('{bp}', '{bitem}', 'x', 'image')",
    "evidence in own property pointing at B's item": "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) VALUES ('{ap}', '{bitem}', 'x', 'image')",
    "tag on B's item": "INSERT INTO inspection_item_tags (inspection_item_id, issue_tag_id) SELECT '{bitem}', id FROM issue_tags WHERE name = 'Stain'",
    "maintenance on B's property": "INSERT INTO maintenance_issues (property_id, user_id, title) VALUES ('{bp}', '{A}', 'x')",
    "document on B's property": "INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name) VALUES ('{bp}', '{A}', 'other', 'x', 'x')",
    "export row directly": "INSERT INTO exports (user_id, property_id, export_type) VALUES ('{A}', '{bp}', 'move_in_report')",
    "profile for B": "INSERT INTO profiles (id) VALUES ('{newid}')",
}


@pytest.mark.parametrize("name", sorted(INSERT_ATTACKS))
def test_insert_attacks_rejected(dsn: str, two_rentals: Any, name: str) -> None:
    a, b = two_rentals
    sql = INSERT_ATTACKS[name].format(A=A, B=B, ap=a["property"], aitem=a["item"], bp=b["property"], bi=b["inspection"],
                                      br=b["room"], bitem=b["item"], newid=str(uuid.uuid4()))
    with as_user(dsn, A) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute(sql)


def test_anonymous_sees_nothing(dsn: str, two_rentals: Any) -> None:
    with as_user(dsn, None) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute("SELECT id FROM properties")


# --- RPCs ------------------------------------------------------------------------

def test_property_snapshot_is_owner_scoped(dsn: str, two_rentals: Any) -> None:
    a, b = two_rentals
    with as_user(dsn, A) as c:
        mine = one(c, "SELECT get_property_snapshot(%s)", (a["property"],))[0]
        theirs = one(c, "SELECT get_property_snapshot(%s)", (b["property"],))[0]
    assert mine["property"]["id"] == a["property"]
    assert {e["id"] for e in mine["evidence_files"]} == {a["evidence"]}
    assert mine["item_tags"] == [{"inspection_item_id": a["item"], "name": "Scratch"}]
    assert mine["evidence_files"][0]["thumbnail_path"].endswith("_thumb.jpg")
    assert theirs["property"] is None and theirs["rooms"] == [] and theirs["evidence_files"] == []


@pytest.mark.parametrize("fn", [
    "claim_next_export_job()", "reap_stuck_export_jobs()",
    "grant_report_credit('{A}', 'evt', NULL)", "consume_report_credit('{A}', 'evt')",
    "delete_user_owned_data('{B}')",
])
def test_privileged_functions_denied_to_users(dsn: str, fn: str) -> None:
    with as_user(dsn, A) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute(f"SELECT * FROM {fn.format(A=A, B=B)}")


def test_report_credits_idempotent_and_never_negative(owner: Any) -> None:
    u = A
    owner.execute("DELETE FROM report_credit_events WHERE user_id = %s", (u,))
    owner.execute("DELETE FROM user_report_credits WHERE user_id = %s", (u,))
    owner.execute("SELECT grant_report_credit(%s, 'rc:purchase-1', 'movemark_report_pack')", (u,))
    owner.execute("SELECT grant_report_credit(%s, 'rc:purchase-1', 'movemark_report_pack')", (u,))  # webhook retry
    assert one(owner, "SELECT balance FROM user_report_credits WHERE user_id = %s", (u,))[0] == 1
    assert one(owner, "SELECT consume_report_credit(%s, 'export:1')", (u,))[0] is True
    assert one(owner, "SELECT consume_report_credit(%s, 'export:1')", (u,))[0] in (True, False)  # idempotent key
    assert one(owner, "SELECT balance FROM user_report_credits WHERE user_id = %s", (u,))[0] == 0
    assert one(owner, "SELECT consume_report_credit(%s, 'export:2')", (u,))[0] is False


def test_apps_have_no_access_to_credits_or_entitlements(dsn: str, owner: Any) -> None:
    owner.execute("SELECT grant_report_credit(%s, 'rc:b-1', NULL)", (B,))
    # 0960: the apps read credits through the API only; the Data API role has no access at all.
    for sql in ("SELECT user_id FROM user_report_credits", "UPDATE user_report_credits SET balance = 99",
                "SELECT * FROM report_credit_events", "SELECT * FROM user_entitlements"):
        with as_user(dsn, A) as c, pytest.raises(errors.InsufficientPrivilege):
            c.execute(sql)


def test_export_queue_one_active_job_and_claim(owner: Any, two_rentals: Any) -> None:
    a, _ = two_rentals
    owner.execute("DELETE FROM exports")
    owner.execute("INSERT INTO exports (user_id, property_id, export_type, status) VALUES (%s, %s, 'move_in_report', 'queued')", (A, a["property"]))
    with pytest.raises(errors.UniqueViolation):  # API relies on this 23505
        owner.execute("INSERT INTO exports (user_id, property_id, export_type, status) VALUES (%s, %s, 'move_in_report', 'queued')", (A, a["property"]))
    claimed = rows(owner, "SELECT id, status FROM claim_next_export_job()")
    assert len(claimed) == 1 and claimed[0][1] == "processing"


def test_export_rows_are_owner_scoped(dsn: str, owner: Any, two_rentals: Any) -> None:
    a, b = two_rentals
    owner.execute("DELETE FROM exports")
    owner.execute("INSERT INTO exports (user_id, property_id, export_type, status, file_path) VALUES (%s, %s, 'move_in_report', 'completed', 'x.pdf')", (B, b["property"]))
    with as_user(dsn, A) as c:
        assert rows(c, "SELECT id FROM exports") == []


def test_inspections_unique_per_property_user_type(dsn: str, two_rentals: Any) -> None:
    a, _ = two_rentals
    with as_user(dsn, A) as c, pytest.raises(errors.UniqueViolation):
        c.execute("INSERT INTO inspections (property_id, user_id, inspection_type) VALUES (%s, %s, 'move_in')", (a["property"], A))


def test_delete_user_owned_data_removes_only_that_user(dsn: str, owner: Any) -> None:
    c_user = str(uuid.uuid4())
    owner.execute("INSERT INTO neon_auth.\"user\" (id, email) VALUES (%s, 'c@qa.test')", (c_user,))
    seed_rental(dsn, c_user)
    owner.execute("SELECT grant_report_credit(%s, 'rc:c-1', NULL)", (c_user,))
    before_others = one(owner, "SELECT count(*) FROM properties WHERE user_id <> %s", (c_user,))[0]
    owner.execute("SELECT delete_user_owned_data(%s)", (c_user,))
    for t, col in [("properties", "user_id"), ("inspections", "user_id"), ("maintenance_issues", "user_id"),
                   ("property_documents", "user_id"), ("move_out_checklists", "user_id"), ("exports", "user_id"),
                   ("user_report_credits", "user_id"), ("report_credit_events", "user_id"), ("profiles", "id")]:
        assert one(owner, f"SELECT count(*) FROM {t} WHERE {col} = %s", (c_user,))[0] == 0, t
    assert one(owner, "SELECT count(*) FROM properties WHERE user_id <> %s", (c_user,))[0] == before_others
    assert one(owner, "SELECT count(*) FROM issue_tags")[0] >= 6  # global tags kept
    # Deleting the auth user afterwards succeeds (no rows still reference it).
    owner.execute("DELETE FROM neon_auth.\"user\" WHERE id = %s", (c_user,))


# --- 0930: Data API write integrity ----------------------------------------------
# Every case runs as the attacker X against a fresh victim Y (and X's own second
# rental X2 for same-user, cross-property mismatches). The product outcome that
# matters is checked last: Y can always be deleted, and nothing of X points at Y.

def _fresh_user(owner: Any) -> str:
    uid = str(uuid.uuid4())
    owner.execute("INSERT INTO neon_auth.\"user\" (id, email) VALUES (%s, %s)", (uid, f"{uid[:8]}@qa.test"))
    return uid


def _second_rental(dsn: str, user: str) -> dict[str, str]:
    with as_user(dsn, user) as c:
        ids = {"property": str(one(c, """INSERT INTO properties (user_id, title, address_line_1, city, province_state, postal_code, country)
            VALUES (%s, 'QA ONLY 2', '1 Other St', 'Toronto', 'ON', 'M5J', 'CA') RETURNING id""", (user,))[0])}
        ids["room"] = str(one(c, "INSERT INTO rooms (property_id, name) VALUES (%s, 'Bath') RETURNING id", (ids["property"],))[0])
        ids["inspection"] = str(one(c, "INSERT INTO inspections (property_id, user_id, inspection_type) VALUES (%s, %s, 'move_in') RETURNING id", (ids["property"], user))[0])
        ids["item"] = str(one(c, "INSERT INTO inspection_items (inspection_id, room_id) VALUES (%s, %s) RETURNING id", (ids["inspection"], ids["room"]))[0])
        ids["evidence"] = str(one(c, "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) VALUES (%s, %s, %s, 'image') RETURNING id",
                                  (ids["property"], ids["item"], f"{user}/{ids['property']}/move-in/{ids['room']}/2.jpg"))[0])
        ids["maintenance"] = str(one(c, "INSERT INTO maintenance_issues (property_id, user_id, title) VALUES (%s, %s, 'Crack') RETURNING id", (ids["property"], user))[0])
        ids["document"] = str(one(c, "INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name) VALUES (%s, %s, 'other', %s, 'o.pdf') RETURNING id",
                                  (ids["property"], user, f"{user}/{ids['property']}/other/o.pdf"))[0])
        c.commit()
    return ids


def _with_dispute(owner: Any, user: str, rental: dict[str, str]) -> str:
    """Disputes are created by the backend (0960: the apps have no access to disputes or their links)."""
    return str(one(owner, "INSERT INTO disputes (property_id, user_id, dispute_type) VALUES (%s, %s, 'other') RETURNING id", (rental["property"], user))[0])


@pytest.fixture
def graph(dsn: str, owner: Any) -> dict[str, Any]:
    x, y = _fresh_user(owner), _fresh_user(owner)
    g = {"X": x, "Y": y, "x": seed_rental(dsn, x), "x2": _second_rental(dsn, x), "y": seed_rental(dsn, y)}
    g["x_dispute"] = _with_dispute(owner, x, g["x"])
    g["y_dispute"] = _with_dispute(owner, y, g["y"])
    # An existing link X may later try to repoint.
    g["x_link"] = str(one(owner, "INSERT INTO dispute_evidence_links (dispute_id, evidence_file_id) VALUES (%s, %s) RETURNING id",
                          (g["x_dispute"], g["x"]["evidence"]))[0])
    return g


# (name, SQL with {placeholders}) — each must be refused for X.
CROSS_REFERENCE_ATTACKS = {
    # exports are read-only for clients (the API queues; the worker mutates)
    "insert own queued export": "INSERT INTO exports (user_id, property_id, export_type, status) VALUES ('{X}', '{xp}', 'dispute_packet', 'queued')",
    # cross-tenant moves and attachments
    "move inspection to Y's property": "UPDATE inspections SET property_id = '{yp}' WHERE id = '{xi}'",
    "move maintenance to Y's property": "UPDATE maintenance_issues SET property_id = '{yp}' WHERE id = '{xm}'",
    "move document to Y's property": "UPDATE property_documents SET property_id = '{yp}' WHERE id = '{xd}'",
    "move checklist to Y's property": "UPDATE move_out_checklists SET property_id = '{yp}' WHERE id = '{xc}'",
    "move dispute to Y's property": "UPDATE disputes SET property_id = '{yp}' WHERE id = '{xdisp}'",
    "checklist_state on Y's property": "INSERT INTO move_out_checklist_state (property_id, user_id) VALUES ('{yp}', '{X}')",
    "move room to Y's property": "UPDATE rooms SET property_id = '{yp}' WHERE id = '{xr}'",
    "item in own inspection on Y's room": "INSERT INTO inspection_items (inspection_id, room_id) VALUES ('{xi}', '{yr}')",
    "repoint own item to Y's room": "UPDATE inspection_items SET room_id = '{yr}' WHERE id = '{xitem}'",
    "repoint own evidence to Y's item": "UPDATE evidence_files SET inspection_item_id = '{yitem}' WHERE id = '{xe}'",
    "repoint own evidence to Y's maintenance": "UPDATE evidence_files SET inspection_item_id = NULL, maintenance_issue_id = '{ym}' WHERE id = '{xe}'",
    "link own dispute to Y's evidence": "INSERT INTO dispute_evidence_links (dispute_id, evidence_file_id) VALUES ('{xdisp}', '{ye}')",
    "link own dispute to Y's maintenance": "INSERT INTO dispute_evidence_links (dispute_id, maintenance_issue_id) VALUES ('{xdisp}', '{ym}')",
    "link own dispute to Y's document": "INSERT INTO dispute_evidence_links (dispute_id, property_document_id) VALUES ('{xdisp}', '{yd}')",
    "repoint own link to Y's evidence": "UPDATE dispute_evidence_links SET evidence_file_id = '{ye}' WHERE id = '{xlink}'",
    # same user, different property: the graph must stay on one property
    "item: rental A1 inspection with A2 room": "INSERT INTO inspection_items (inspection_id, room_id) VALUES ('{xi}', '{x2r}')",
    "repoint own item to own other rental's room": "UPDATE inspection_items SET room_id = '{x2r}' WHERE id = '{xitem}'",
    "evidence: property disagrees with parent item": "UPDATE evidence_files SET property_id = '{x2p}' WHERE id = '{xe}'",
    "evidence: parent item on other own rental": "UPDATE evidence_files SET inspection_item_id = '{x2item}' WHERE id = '{xe}'",
    "evidence: maintenance on other own rental": "UPDATE evidence_files SET inspection_item_id = NULL, maintenance_issue_id = '{x2m}' WHERE id = '{xe}'",
    "link A1 dispute to own A2 evidence": "INSERT INTO dispute_evidence_links (dispute_id, evidence_file_id) VALUES ('{xdisp}', '{x2e}')",
    "link A1 dispute to own A2 maintenance": "INSERT INTO dispute_evidence_links (dispute_id, maintenance_issue_id) VALUES ('{xdisp}', '{x2m}')",
    "link A1 dispute to own A2 document": "INSERT INTO dispute_evidence_links (dispute_id, property_document_id) VALUES ('{xdisp}', '{x2d}')",
    "move own inspection away from its items": "UPDATE inspections SET property_id = '{x2p}' WHERE id = '{xi}'",
    "move own room away from its items": "UPDATE rooms SET property_id = '{x2p}' WHERE id = '{xr}'",
    "move own dispute away from its links": "UPDATE disputes SET property_id = '{x2p}' WHERE id = '{xdisp}'",
}


def _fill(sql: str, g: dict[str, Any]) -> str:
    x, x2, y = g["x"], g["x2"], g["y"]
    return sql.format(X=g["X"], xp=x["property"], xr=x["room"], xi=x["inspection"], xitem=x["item"], xe=x["evidence"],
                      xm=x["maintenance"], xd=x["document"], xc=x["checklist"], xdisp=g["x_dispute"], xlink=g["x_link"],
                      x2p=x2["property"], x2r=x2["room"], x2item=x2["item"], x2e=x2["evidence"], x2m=x2["maintenance"], x2d=x2["document"],
                      yp=y["property"], yr=y["room"], yitem=y["item"], ye=y["evidence"], ym=y["maintenance"], yd=y["document"])


def _refused(dsn: str, user: str, sql: str) -> bool:
    """True when the Data API role is refused (RLS error) or the statement changes nothing."""
    with as_user(dsn, user) as c:
        try:
            with c.cursor() as cur:
                cur.execute(sql)
                return cur.rowcount == 0
        except (errors.InsufficientPrivilege, errors.ForeignKeyViolation):
            return True


@pytest.mark.parametrize("name", sorted(CROSS_REFERENCE_ATTACKS))
def test_cross_reference_writes_refused(dsn: str, graph: dict[str, Any], name: str) -> None:
    assert _refused(dsn, graph["X"], _fill(CROSS_REFERENCE_ATTACKS[name], graph)), name


def test_poisoning_never_makes_another_account_undeletable(dsn: str, owner: Any, graph: dict[str, Any]) -> None:
    for name, sql in CROSS_REFERENCE_ATTACKS.items():  # every attack, each in its own committed attempt
        with as_user(dsn, graph["X"]) as c:
            try:
                c.execute(_fill(sql, graph)); c.commit()
            except Exception:  # noqa: BLE001
                c.rollback()
    x, y = graph["X"], graph["Y"]
    # Nothing of X's references anything of Y's.
    assert one(owner, """SELECT count(*) FROM inspection_items ii JOIN inspections i ON i.id = ii.inspection_id
                         JOIN rooms r ON r.id = ii.room_id JOIN properties p ON p.id = r.property_id
                         WHERE i.user_id = %s AND p.user_id = %s""", (x, y))[0] == 0
    for table in ("inspections", "maintenance_issues", "property_documents", "move_out_checklists", "move_out_checklist_state", "disputes", "exports"):
        assert one(owner, f"SELECT count(*) FROM {table} t JOIN properties p ON p.id = t.property_id WHERE t.user_id = %s AND p.user_id = %s", (x, y))[0] == 0, table
    assert one(owner, """SELECT count(*) FROM dispute_evidence_links l JOIN disputes d ON d.id = l.dispute_id
                         LEFT JOIN evidence_files ef ON ef.id = l.evidence_file_id
                         LEFT JOIN maintenance_issues mi ON mi.id = l.maintenance_issue_id
                         LEFT JOIN property_documents pd ON pd.id = l.property_document_id
                         WHERE d.user_id = %s AND coalesce(ef.property_id, mi.property_id, pd.property_id) <> d.property_id""", (x,))[0] == 0
    # The outcome that matters: Y's account deletes cleanly, X keeps everything X owns.
    owner.execute("SELECT delete_user_owned_data(%s)", (y,))
    owner.execute("DELETE FROM neon_auth.\"user\" WHERE id = %s", (y,))
    assert one(owner, "SELECT count(*) FROM properties WHERE user_id = %s", (x,))[0] == 2
    owner.execute("SELECT delete_user_owned_data(%s)", (x,))  # and X's own graph is still consistent enough to delete


def test_legitimate_writes_still_work(dsn: str, graph: dict[str, Any]) -> None:
    """Every write the apps actually perform (0960 grants exactly these) still passes RLS."""
    x = graph["x"]
    with as_user(dsn, graph["X"]) as c:
        assert rows(c, "UPDATE inspection_items SET notes = 'ok' WHERE id = %s RETURNING id", (x["item"],))
        assert rows(c, "UPDATE maintenance_issues SET status = 'resolved' WHERE id = %s RETURNING id", (x["maintenance"],))
        assert rows(c, "UPDATE move_out_checklists SET keys_returned = true WHERE id = %s RETURNING id", (x["checklist"],))
        assert rows(c, "UPDATE properties SET title = 'Renamed' WHERE id = %s RETURNING id", (x["property"],))
        assert rows(c, "INSERT INTO rooms (property_id, name) VALUES (%s, 'Spare') RETURNING id", (x["property"],))
        # Upsert shape the apps use (insert … on conflict do update) still passes.
        assert rows(c, """INSERT INTO move_out_checklists (property_id, user_id, keys_returned) VALUES (%s, %s, true)
                          ON CONFLICT (property_id, user_id) DO UPDATE SET keys_returned = EXCLUDED.keys_returned RETURNING id""",
                    (x["property"], graph["X"]))


# Writes no app performs (0960 revoked them): refused outright for the Data API role, whatever the row.
APP_WRITES_NOT_GRANTED = {
    "update inspection": "UPDATE inspections SET overall_notes = 'ok' WHERE id = '{xi}'",
    "update evidence": "UPDATE evidence_files SET captured_at = now() WHERE id = '{xe}'",
    "update document": "UPDATE property_documents SET file_name = 'x.pdf' WHERE id = '{xd}'",
    "update room": "UPDATE rooms SET name = 'Kitchen 2' WHERE id = '{xr}'",
    "update dispute": "UPDATE disputes SET title = 'Deposit' WHERE id = '{xdisp}'",
    "insert dispute": "INSERT INTO disputes (property_id, user_id, dispute_type) VALUES ('{xp}', '{X}', 'other')",
    "insert dispute link": "INSERT INTO dispute_evidence_links (dispute_id, maintenance_issue_id) VALUES ('{xdisp}', '{xm}')",
    "insert checklist state": "INSERT INTO move_out_checklist_state (property_id, user_id) VALUES ('{xp}', '{X}')",
    "insert own credits": "INSERT INTO user_report_credits (user_id, balance) VALUES ('{X}', 99)",
    "insert own entitlement": "INSERT INTO user_entitlements (user_id, status) VALUES ('{X}', 'active')",
    "insert issue tag": "INSERT INTO issue_tags (name) VALUES ('Free Pro')",
}


@pytest.mark.parametrize("name", sorted(APP_WRITES_NOT_GRANTED))
def test_writes_no_app_performs_are_not_granted(dsn: str, graph: dict[str, Any], name: str) -> None:
    with as_user(dsn, graph["X"]) as c:
        with pytest.raises(errors.InsufficientPrivilege):
            c.execute(_fill(APP_WRITES_NOT_GRANTED[name], graph))
        c.commit()


def test_exports_are_read_only_for_clients_and_scoped(dsn: str, owner: Any, graph: dict[str, Any]) -> None:
    x, y = graph["x"], graph["y"]
    owner.execute("INSERT INTO exports (user_id, property_id, export_type, status, file_path) VALUES (%s, %s, 'move_in_report', 'completed', 'x.pdf')", (graph["X"], x["property"]))
    owner.execute("INSERT INTO exports (user_id, property_id, export_type, status, file_path) VALUES (%s, %s, 'move_in_report', 'completed', 'y.pdf')", (graph["Y"], y["property"]))
    with as_user(dsn, graph["X"]) as c:
        assert {str(r[0]) for r in rows(c, "SELECT property_id FROM exports")} == {x["property"]}
    for sql in ("INSERT INTO exports (user_id, property_id, export_type) VALUES ('{X}', '{xp}', 'move_in_report')",
                "UPDATE exports SET status = 'queued', attempts = 0 WHERE user_id = '{X}'",
                "DELETE FROM exports WHERE user_id = '{X}'"):
        with as_user(dsn, graph["X"]) as c, pytest.raises(errors.InsufficientPrivilege):
            c.execute(_fill(sql, graph))


def test_backend_still_runs_the_export_lifecycle(owner: Any, graph: dict[str, Any]) -> None:
    x = graph["x"]
    # The worker claims the oldest queued job globally; start from an empty queue.
    owner.execute("DELETE FROM exports WHERE status IN ('queued', 'processing') OR user_id = %s", (graph["X"],))
    job = one(owner, "INSERT INTO exports (user_id, property_id, export_type, status) VALUES (%s, %s, 'move_out_report', 'queued') RETURNING id", (graph["X"], x["property"]))[0]
    claimed = [r for r in rows(owner, "SELECT id, status, attempts FROM claim_next_export_job()") if r[0] == job]
    assert claimed and claimed[0][1] == "processing" and claimed[0][2] == 1
    owner.execute("UPDATE exports SET status = 'failed', error_message = 'boom', locked_at = NULL WHERE id = %s", (job,))
    owner.execute("UPDATE exports SET status = 'queued', error_message = NULL WHERE id = %s", (job,))  # retry
    rows(owner, "SELECT id FROM claim_next_export_job()")
    owner.execute("UPDATE exports SET status = 'completed', file_path = %s, completed_at = now(), locked_at = NULL WHERE id = %s",
                  (f"{graph['X']}/{job}.pdf", job))
    assert one(owner, "SELECT status, attempts FROM exports WHERE id = %s", (job,)) == ("completed", 2)
    owner.execute("UPDATE exports SET status = 'processing', locked_at = now() - interval '10 minutes' WHERE id = %s", (job,))
    assert one(owner, "SELECT reap_stuck_export_jobs()")[0] >= 1


# --- 0960 role hardening ------------------------------------------------------------

RUNTIME_TABLES = {  # 0970: exactly these, per process
    "movemark_api": {
        "SELECT": {"properties", "rooms", "inspections", "inspection_items", "inspection_item_tags", "issue_tags",
                   "maintenance_issues", "disputes", "user_report_credits", "evidence_files", "property_documents",
                   "dispute_evidence_links", "exports", "user_entitlements", "storage_upload_tickets"},
        "INSERT": {"exports", "user_entitlements", "storage_upload_tickets"},
        "UPDATE": {"user_entitlements", "storage_upload_tickets"},
        "DELETE": {"evidence_files", "property_documents", "dispute_evidence_links", "storage_upload_tickets"},
    },
    "movemark_worker": {
        "SELECT": {"properties", "rooms", "inspections", "inspection_items", "inspection_item_tags", "issue_tags",
                   "evidence_files", "property_documents", "maintenance_issues", "exports", "storage_upload_tickets"},
        "INSERT": set(),
        "UPDATE": {"exports", "storage_upload_tickets"},
        "DELETE": set(),
    },
}


@pytest.mark.parametrize("role", sorted(RUNTIME_TABLES))
def test_runtime_roles_hold_exactly_their_process_grants(owner: Any, role: str) -> None:
    attrs = one(owner, "SELECT rolcanlogin, rolbypassrls, rolsuper, rolcreaterole, rolcreatedb, rolreplication FROM pg_roles WHERE rolname = %s", (role,))
    assert attrs == (True, False, False, False, False, False)
    tables = [r[0] for r in rows(owner, "SELECT relname FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'")]
    for privilege, allowed in RUNTIME_TABLES[role].items():
        held = {t for t in tables if one(owner, "SELECT has_table_privilege(%s, %s, %s)", (role, f"public.{t}", privilege))[0]}
        assert held == allowed, (role, privilege, held ^ allowed)
    for privilege in ("TRUNCATE", "REFERENCES", "TRIGGER"):
        assert not any(one(owner, "SELECT has_table_privilege(%s, %s, %s)", (role, f"public.{t}", privilege))[0] for t in tables)
    # Row access on its tables comes from explicit, named policies (no BYPASSRLS).
    policy_tables = {r[0] for r in rows(owner, "SELECT polrelid::regclass::text FROM pg_policy WHERE %s::regrole = ANY(polroles)", (role,))}
    assert policy_tables == {f"public.{t}" if "." not in t else t for t in RUNTIME_TABLES[role]["SELECT"]} or \
        policy_tables == RUNTIME_TABLES[role]["SELECT"]
    assert one(owner, "SELECT count(*) FROM pg_class WHERE relowner = %s::regrole", (role,))[0] == 0
    assert one(owner, "SELECT count(*) FROM pg_proc WHERE proowner = %s::regrole", (role,))[0] == 0


def _login_as(dsn: str, role: str) -> str:
    return f"{dsn}{'&' if '?' in dsn else '?'}user={role}"


COMPROMISED_RUNTIME_ATTEMPTS = {
    "create table": "CREATE TABLE public.pwn (id int)",
    "create function": "CREATE FUNCTION public.pwn() RETURNS int LANGUAGE sql AS 'select 1'",
    "create schema": "CREATE SCHEMA pwn",
    "alter table": "ALTER TABLE public.properties ADD COLUMN pwn int",
    "drop table": "DROP TABLE public.issue_tags",
    "disable rls": "ALTER TABLE public.properties DISABLE ROW LEVEL SECURITY",
    "create policy": "CREATE POLICY pwn ON public.properties FOR ALL TO anonymous USING (true)",
    "become owner": "SET ROLE {owner}",
    "truncate": "TRUNCATE public.exports",
    "replace privileged function": "CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id uuid) RETURNS void LANGUAGE sql AS 'select'",
    "read auth identities": 'SELECT * FROM neon_auth."user"',
    "write billing": "UPDATE public.user_report_credits SET balance = 99",
    "insert credit event": "INSERT INTO public.report_credit_events (event_key, user_id, delta) VALUES ('x', gen_random_uuid(), 1)",
    "edit evidence": "UPDATE public.evidence_files SET file_path = 'x'",
}


@pytest.mark.parametrize("role", sorted(RUNTIME_TABLES))
@pytest.mark.parametrize("name", sorted(COMPROMISED_RUNTIME_ATTEMPTS))
def test_compromised_runtime_credentials_cannot_change_schema_grants_or_billing(dsn: str, owner: Any, role: str, name: str) -> None:
    table_owner = one(owner, "SELECT tableowner FROM pg_tables WHERE schemaname = 'public' AND tablename = 'properties'")[0]
    with psycopg.connect(_login_as(dsn, role)) as conn:  # what a stolen password gives: a session *as* the role
        with pytest.raises((errors.InsufficientPrivilege, errors.UndefinedObject)):
            conn.execute(COMPROMISED_RUNTIME_ATTEMPTS[name].format(owner=table_owner))
        conn.rollback()


@pytest.mark.parametrize("role", sorted(RUNTIME_TABLES))
def test_compromised_runtime_credentials_cannot_grant_anything(dsn: str, owner: Any, role: str) -> None:
    # A GRANT the role has no right to make only warns and changes nothing; prove that nothing changed.
    with psycopg.connect(_login_as(dsn, role), autocommit=True) as conn:
        for sql in ("GRANT SELECT ON public.properties TO anonymous", "GRANT SELECT ON public.exports TO PUBLIC",
                    "GRANT EXECUTE ON FUNCTION public.delete_auth_user(uuid) TO authenticated"):
            try:
                conn.execute(sql)
            except errors.InsufficientPrivilege:
                pass
        with pytest.raises(errors.InsufficientPrivilege):
            conn.execute("GRANT movemark_backend TO anonymous")
    assert not one(owner, "SELECT has_table_privilege('anonymous', 'public.properties', 'SELECT')")[0]
    assert not one(owner, "SELECT has_table_privilege('anonymous', 'public.exports', 'SELECT')")[0]
    assert not one(owner, "SELECT has_function_privilege('authenticated', 'public.delete_auth_user(uuid)', 'EXECUTE')")[0]
    assert not one(owner, "SELECT pg_has_role('anonymous', 'movemark_backend', 'MEMBER')")[0]


def test_runtime_role_timeouts(owner: Any) -> None:
    settings = dict(rows(owner, """SELECT r.rolname, array_to_string(s.setconfig, ' ') FROM pg_db_role_setting s
                                   JOIN pg_roles r ON r.oid = s.setrole WHERE r.rolname IN ('movemark_api', 'movemark_worker')"""))
    for role in ("movemark_api", "movemark_worker"):
        for key in ("statement_timeout=", "lock_timeout=", "idle_in_transaction_session_timeout="):
            assert key in settings[role], (role, key)


def test_new_tables_and_functions_are_private_by_default(owner: Any) -> None:
    # Created by the migration (owner) role, as a future migration would — nobody gets anything implicitly.
    owner.execute("CREATE TABLE public.default_acl_probe (id int)")
    owner.execute("CREATE FUNCTION public.default_acl_probe_fn() RETURNS int LANGUAGE sql AS 'select 1'")
    try:
        for role in ("authenticated", "anonymous", "movemark_backend", "movemark_api", "movemark_worker"):
            for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE"):
                assert not one(owner, "SELECT has_table_privilege(%s, 'public.default_acl_probe', %s)", (role, privilege))[0], (role, privilege)
            assert not one(owner, "SELECT has_function_privilege(%s, 'public.default_acl_probe_fn()', 'EXECUTE')", (role,))[0], role
    finally:
        owner.execute("DROP FUNCTION public.default_acl_probe_fn()")
        owner.execute("DROP TABLE public.default_acl_probe")


def test_query_statistics_are_not_reachable_by_app_roles(owner: Any) -> None:
    for role in ("authenticated", "anonymous"):
        assert not one(owner, "SELECT has_schema_privilege(%s, 'monitoring', 'USAGE')", (role,))[0]
    assert one(owner, "SELECT extnamespace::regnamespace::text FROM pg_extension WHERE extname = 'pg_stat_statements'")[0] == "monitoring"


def test_auth_user_deletion_is_a_backend_only_function(owner: Any) -> None:
    assert one(owner, "SELECT has_function_privilege('movemark_api', 'public.delete_auth_user(uuid)', 'EXECUTE')")[0]
    for role in ("authenticated", "anonymous", "public", "movemark_worker", "movemark_backend"):
        assert not one(owner, "SELECT has_function_privilege(%s, 'public.delete_auth_user(uuid)', 'EXECUTE')", (role,))[0]
    victim = str(uuid.uuid4())
    owner.execute("INSERT INTO neon_auth.\"user\" (id, email, name) VALUES (%s, %s, 'QA')", (victim, f"{victim[:6]}@qa.test"))
    owner.execute("SET ROLE movemark_api")
    try:
        owner.execute("SELECT public.delete_auth_user(%s)", (victim,))
    finally:
        owner.execute("RESET ROLE")
    assert one(owner, "SELECT count(*) FROM neon_auth.\"user\" WHERE id = %s", (victim,))[0] == 0


def test_privileged_functions_pin_search_path(owner: Any) -> None:
    loose = rows(owner, """SELECT p.proname FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prosecdef
                           AND NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%%pg_temp')""")
    assert loose == []


PRIVILEGED_FUNCTIONS = {  # 0980: each SECURITY DEFINER function, executable by exactly these roles
    "public.claim_next_export_job()": {"movemark_worker"},
    "public.reap_stuck_export_jobs(interval, integer)": {"movemark_worker"},
    "public.consume_report_credit(uuid, text)": {"movemark_api"},
    "public.grant_report_credit(uuid, text, text)": {"movemark_api"},
    "public.delete_user_owned_data(uuid)": {"movemark_api"},
    "public.delete_auth_user(uuid)": {"movemark_api"},
}


@pytest.mark.parametrize("fn", sorted(PRIVILEGED_FUNCTIONS))
def test_privileged_functions_are_executable_only_by_their_process(owner: Any, fn: str) -> None:
    roles = ("anonymous", "authenticated", "movemark_backend", "movemark_api", "movemark_worker", "public")
    allowed = {r for r in roles if one(owner, "SELECT has_function_privilege(%s, %s, 'EXECUTE')", (r, fn))[0]}
    assert allowed == PRIVILEGED_FUNCTIONS[fn]
    defined = {r[0] for r in rows(owner, "SELECT p.oid FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace "
                                         "AND p.prosecdef AND p.prorettype <> 'trigger'::regtype")}
    listed = {one(owner, "SELECT %s::regprocedure::oid", (f,))[0] for f in PRIVILEGED_FUNCTIONS}
    assert defined == listed  # a new privileged function must be added here deliberately


@pytest.mark.parametrize("args", ["interval '0'", "interval '30 seconds'", "interval '2 days'", "interval '5 minutes', 0",
                                  "interval '5 minutes', 99", "NULL"])
def test_reaper_refuses_windows_that_would_requeue_live_jobs(owner: Any, args: str) -> None:
    with pytest.raises(errors.InvalidParameterValue):
        owner.execute(f"SELECT public.reap_stuck_export_jobs({args})")


# --- 0990 bounded snapshot v2 ---------------------------------------------------------

V2_FUNCTIONS = ["public.get_property_snapshot_v2(uuid, integer, integer)",
                "public.get_room_entries_page(uuid, text, timestamp with time zone, uuid, integer, integer)",
                "public.get_entry_photos_page(uuid, timestamp with time zone, uuid, integer)",
                "public.get_vault_summaries()", "public._entry_payload(uuid[], integer)"]


@pytest.mark.parametrize("fn", V2_FUNCTIONS)
def test_v2_functions_are_invoker_app_only_with_pinned_search_path(owner: Any, fn: str) -> None:
    secdef, config = one(owner, "SELECT prosecdef, array_to_string(proconfig, ' ') FROM pg_proc WHERE oid = %s::regprocedure", (fn,))
    assert secdef is False and "search_path=pg_catalog, public, pg_temp" in config  # RLS applies to the caller
    for role, allowed in (("authenticated", True), ("anonymous", False), ("public", False), ("movemark_api", False), ("movemark_worker", False)):
        assert one(owner, "SELECT has_function_privilege(%s, %s, 'EXECUTE')", (role, fn))[0] is allowed, (role, fn)


@pytest.fixture
def busy_room(dsn: str, owner: Any) -> dict[str, Any]:
    """One rental of a fresh user with 23 move-in entries in one room, 7 photos on the newest entry."""
    user = _fresh_user(owner)
    r = seed_rental(dsn, user)
    with as_user(dsn, user) as c:
        items = [str(one(c, "INSERT INTO inspection_items (inspection_id, room_id, notes, created_at) VALUES (%s, %s, %s, now() - %s * interval '1 minute') RETURNING id",
                         (r["inspection"], r["room"], f"Entry {k}\nnote {k}" if k % 2 else f"Entry {k}", k))[0]) for k in range(1, 23)]
        newest = items[0]
        for k in range(7):
            c.execute("INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) VALUES (%s, %s, %s, 'image')",
                      (r["property"], newest, f"{user}/{r['property']}/move-in/{r['room']}/p{k}.jpg"))
        c.commit()
    return {"user": user, "rental": r, "newest": newest, "items": set(items) | {r["item"]}}


def test_snapshot_v2_bounds_the_load_but_keeps_true_totals(dsn: str, busy_room: Any) -> None:
    r = busy_room["rental"]
    with as_user(dsn, busy_room["user"]) as c:
        snap = one(c, "SELECT get_property_snapshot_v2(%s, 5, 3)", (r["property"],))[0]
        room = next(x for x in snap["rooms"] if x["id"] == r["room"])
        assert room["stats"]["move_in"]["entries"] == 23 and room["stats"]["move_in"]["photos"] == 8  # 7 + the seeded one
        assert room["stats"]["move_in"]["entries_with_notes"] >= 11
        assert len(snap["inspection_items"]) == 5  # newest five, not all 23
        assert snap["entries"]["photo_counts"][busy_room["newest"]] == 7  # true count …
        assert len([e for e in snap["entries"]["evidence_files"] if e["inspection_item_id"] == busy_room["newest"]]) == 3  # … bounded rows
        assert one(c, "SELECT get_property_snapshot_v2(%s, 100000, 100000)", (r["property"],))[0]["limits"] == {"entries_per_room": 100, "photos_per_entry": 50}


def test_entry_and_photo_pages_walk_the_whole_history_exactly_once(dsn: str, busy_room: Any) -> None:
    r = busy_room["rental"]
    with as_user(dsn, busy_room["user"]) as c:
        seen, cursor = [], (None, None)
        while True:
            page = one(c, "SELECT get_room_entries_page(%s, 'move_in', %s, %s, 4, 1)", (r["room"], *cursor))[0]
            items = page["inspection_items"]
            seen += [i["id"] for i in items]
            assert items == sorted(items, key=lambda i: (i["created_at"], i["id"]), reverse=True)  # newest first
            if not page["has_more"]:
                break
            cursor = (items[-1]["created_at"], items[-1]["id"])
        assert len(seen) == len(set(seen)) and set(seen) == busy_room["items"]
        photos, cursor = [], (None, None)
        while True:
            page = one(c, "SELECT get_entry_photos_page(%s, %s, %s, 2)", (busy_room["newest"], *cursor))[0]
            photos += [p["id"] for p in page["evidence_files"]]
            if not page["has_more"]:
                break
            cursor = (page["evidence_files"][-1]["created_at"], page["evidence_files"][-1]["id"])
        assert len(photos) == 7 == len(set(photos))
        with pytest.raises(errors.InvalidParameterValue):  # half a cursor is refused, not guessed
            c.execute("SELECT get_room_entries_page(%s, 'move_in', now(), NULL)", (r["room"],))


def test_v2_and_vault_summary_show_nothing_of_another_account(dsn: str, busy_room: Any, owner: Any) -> None:
    r = busy_room["rental"]
    stranger = _fresh_user(owner)
    seed_rental(dsn, stranger)
    with as_user(dsn, stranger) as c:
        snap = one(c, "SELECT get_property_snapshot_v2(%s)", (r["property"],))[0]
        assert snap["property"] is None and snap["rooms"] == [] and snap["inspection_items"] == []
        assert one(c, "SELECT get_room_entries_page(%s, 'move_in')", (r["room"],))[0]["inspection_items"] == []
        assert one(c, "SELECT get_entry_photos_page(%s)", (busy_room["newest"],))[0]["evidence_files"] == []
        assert r["property"] not in {s["property_id"] for s in one(c, "SELECT get_vault_summaries()")[0]}
    with as_user(dsn, busy_room["user"]) as c:
        mine = {s["property_id"]: s for s in one(c, "SELECT get_vault_summaries()")[0]}
        assert mine[r["property"]]["rooms_documented"] == 1 and mine[r["property"]]["latest_evidence"] is not None
