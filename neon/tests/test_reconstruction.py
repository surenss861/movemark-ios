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
            VALUES (%s, %s, %s, 'image', %s) RETURNING id""", (ids["property"], ids["item"], f"{user}/p/move-in/r/1.jpg", f"{user}/p/move-in/r/1_thumb.jpg"))[0])
        tag = one(c, "SELECT id FROM issue_tags WHERE name = 'Scratch'")[0]
        c.execute("INSERT INTO inspection_item_tags (inspection_item_id, issue_tag_id) VALUES (%s, %s)", (ids["item"], tag))
        ids["maintenance"] = str(one(c, "INSERT INTO maintenance_issues (property_id, user_id, title) VALUES (%s, %s, 'Leak') RETURNING id", (ids["property"], user))[0])
        ids["document"] = str(one(c, """INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name)
            VALUES (%s, %s, 'lease', %s, 'lease.pdf') RETURNING id""", (ids["property"], user, f"{user}/p/lease/l.pdf"))[0])
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


@pytest.mark.parametrize("table", sorted(USER_TABLES))
def test_update_isolation(dsn: str, two_rentals: Any, table: str) -> None:
    a, b = two_rentals
    col = USER_TABLES[table][1]
    with as_user(dsn, A) as c:
        mine = rows(c, f"UPDATE {table} SET {col} = %s WHERE id = %s RETURNING id", (VALUE[col], a[ID_OF[table]]))
        theirs = rows(c, f"UPDATE {table} SET {col} = %s WHERE id = %s RETURNING id", (VALUE[col], b[ID_OF[table]]))
    assert len(mine) == 1 and theirs == []


@pytest.mark.parametrize("table", sorted(USER_TABLES))
def test_delete_isolation(dsn: str, two_rentals: Any, table: str) -> None:
    _, b = two_rentals
    with as_user(dsn, A) as c:
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
    sql = INSERT_ATTACKS[name].format(A=A, B=B, ap=a["property"], bp=b["property"], bi=b["inspection"],
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


def test_users_can_read_only_their_own_credits(dsn: str, owner: Any) -> None:
    owner.execute("SELECT grant_report_credit(%s, 'rc:b-1', NULL)", (B,))
    with as_user(dsn, A) as c:
        assert all(str(r[0]) == A for r in rows(c, "SELECT user_id FROM user_report_credits"))
        with pytest.raises(errors.InsufficientPrivilege):
            c.execute("UPDATE user_report_credits SET balance = 99")
            c.execute("INSERT INTO user_report_credits (user_id, balance) VALUES (%s, 99)", (A,))


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
