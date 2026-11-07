"""Legal acceptance gate (1030, 1040), as the Data API runs it: role `authenticated` with JWT claims.

Local Postgres only, like test_reconstruction.py, whose helpers it shares.

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_legal_gate.py -q
"""
from __future__ import annotations

import concurrent.futures
import hashlib
import importlib.util
import json
import os
import pathlib
import uuid
from typing import Any, Iterator

import pytest

psycopg = pytest.importorskip("psycopg")
from psycopg import errors  # noqa: E402

from test_reconstruction import as_user, one, rows, seed_rental  # noqa: E402

NEON = pathlib.Path(__file__).resolve().parents[1]
ADMIN_DSN = os.getenv("MOVEMARK_TEST_ADMIN_DSN", "postgresql:///postgres")
DB = "movemark_neon_legal_gate"

spec = importlib.util.spec_from_file_location("migrate_for_legal_gate", NEON / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)

GATED = {  # table: id key in seed_rental's result
    "properties": "property", "rooms": "room", "inspections": "inspection", "inspection_items": "item",
    "evidence_files": "evidence", "property_documents": "document",
}
METHODS = ("email", "apple", "google")


def sha(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def migrations_through(version: str) -> list[pathlib.Path]:
    return [p for p in sorted((NEON / "migrations").glob("*.sql")) if p.name[:4] <= version]


@pytest.fixture(scope="module")
def dsn() -> Iterator[str]:
    try:
        admin = psycopg.connect(ADMIN_DSN, autocommit=True, connect_timeout=3)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"no local Postgres: {e}")
    with admin, admin.cursor() as cur:
        cur.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')
        cur.execute(f'CREATE DATABASE "{DB}"')
    url = f"postgresql:///{DB}"
    with psycopg.connect(url, autocommit=True) as conn:
        conn.execute((NEON / "tests" / "neon_platform_shim.sql").read_text())
        for f in sorted((NEON / "migrations").glob("*.sql")):
            conn.execute(f.read_text())
    yield url
    with psycopg.connect(ADMIN_DSN, autocommit=True) as admin2:
        admin2.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')


@pytest.fixture
def owner(dsn: str) -> Iterator[Any]:
    with psycopg.connect(dsn, autocommit=True) as conn:
        yield conn


def set_enforced(owner: Any, on: bool) -> None:
    owner.execute("UPDATE legal_gate_settings SET enforced = %s, updated_at = now()", (on,))


def publish(owner: Any, *, terms: str | None = None, notice: str | None = None, final: bool = False) -> dict[str, str]:
    """Publishes new versions; returns what is active."""
    if terms:
        owner.execute("SELECT publish_legal_document('terms', %s, %s, 'https://movemark.ca/terms', %s)", (terms, sha(terms), final))
    if notice:
        owner.execute("SELECT publish_legal_document('privacy_notice', %s, %s, 'https://movemark.ca/privacy', %s)", (notice, sha(notice), final))
    return dict(rows(owner, "SELECT kind, version FROM legal_documents WHERE active"))


def fresh_user(owner: Any) -> str:
    uid = str(uuid.uuid4())
    owner.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    return uid


def accept(dsn: str, user: str, active: dict[str, str], method: str = "email") -> dict[str, Any]:
    with as_user(dsn, user) as c:
        status = one(c, "SELECT accept_legal_documents(%s, %s, %s)", (method, active["terms"], active["privacy_notice"]))[0]
        c.commit()
    return status


def status_of(dsn: str, user: str) -> dict[str, Any]:
    with as_user(dsn, user) as c:
        return one(c, "SELECT get_legal_status()")[0]


@pytest.fixture
def active(owner: Any) -> Iterator[dict[str, str]]:
    """Enforcement on, with a brand-new pair of documents, so no earlier test's acceptance counts."""
    tag = uuid.uuid4().hex[:8]
    current = publish(owner, terms=f"t-{tag}", notice=f"p-{tag}")
    set_enforced(owner, True)
    yield current
    set_enforced(owner, False)


@pytest.fixture
def legacy(dsn: str, owner: Any) -> dict[str, Any]:
    """A customer from before the gate: a full rental created with the gate off, no acceptance."""
    set_enforced(owner, False)
    user = fresh_user(owner)
    return {"user": user, **seed_rental(dsn, user)}


def owner_count(owner: Any, table: str, row_id: str) -> int:
    return one(owner, f"SELECT count(*) FROM {table} WHERE id = %s", (row_id,))[0]


# --- 1030 alone changes nothing --------------------------------------------------------

def test_a_fresh_build_enforces_nothing_and_accepts_nobody() -> None:
    with migrate.scratch_db(migrations_through("1050")) as conn:
        assert conn.execute("SELECT enforced FROM legal_gate_settings").fetchall() == [(False,)]
        assert conn.execute("SELECT count(*) FROM legal_documents").fetchone()[0] == 0
        assert conn.execute("SELECT count(*) FROM legal_acceptances").fetchone()[0] == 0


def test_migrating_a_database_with_users_marks_none_of_them_accepted() -> None:
    with migrate.scratch_db(migrations_through("1020")) as conn:
        conn.execute("""INSERT INTO neon_auth."user" (id, email) VALUES (gen_random_uuid(), 'old@qa.test')""")
        for path in sorted((NEON / "migrations").glob("10[3-9]*.sql")):
            conn.execute(path.read_text())
        assert conn.execute("SELECT count(*) FROM legal_acceptances").fetchone()[0] == 0


def test_gate_off_leaves_a_legacy_user_working_but_reports_acceptance_outstanding(dsn: str, owner: Any, legacy: dict[str, Any]) -> None:
    current = publish(owner, terms=f"t-{uuid.uuid4().hex[:8]}", notice=f"p-{uuid.uuid4().hex[:8]}")
    set_enforced(owner, False)
    with as_user(dsn, legacy["user"]) as c:
        for table, key in GATED.items():
            assert [str(r[0]) for r in rows(c, f"SELECT id FROM {table}")] == [legacy[key]]
        s = one(c, "SELECT get_legal_status()")[0]
    # The soft phase of the rollout: new apps prompt on acceptance_required even while nothing blocks.
    assert (s["enforced"], s["acceptance_required"], s["blocked"]) == (False, True, False)
    assert s["documents"]["terms"]["version"] == current["terms"]


def test_enforced_with_nothing_published_blocks_nobody(owner: Any) -> None:
    with migrate.scratch_db(migrations_through("1050")) as conn:
        conn.execute("UPDATE legal_gate_settings SET enforced = true")
        uid = str(uuid.uuid4())
        assert conn.execute("SELECT legal_gate_open_for_user(%s)", (uid,)).fetchone()[0] is True
        s = conn.execute("SELECT legal_status_for_user(%s)", (uid,)).fetchone()[0]
        assert (s["acceptance_required"], s["blocked"], s["documents"]) == (False, False, None)
        conn.execute("SELECT publish_legal_document('terms', 'only-terms', %s)", (sha("x"),))  # half a pair
        assert conn.execute("SELECT legal_gate_open_for_user(%s)", (uid,)).fetchone()[0] is True


# --- denied ---------------------------------------------------------------------------

@pytest.mark.parametrize("table", sorted(GATED))
def test_legacy_user_without_acceptance_reads_nothing(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str], table: str) -> None:
    with as_user(dsn, legacy["user"]) as c:
        assert rows(c, f"SELECT id FROM {table}") == []
    assert owner_count(owner, table, legacy[GATED[table]]) == 1


def test_legacy_user_exports_are_hidden(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str]) -> None:
    owner.execute("INSERT INTO exports (user_id, property_id, export_type, status) VALUES (%s, %s, 'move_in_report', 'completed')",
                  (legacy["user"], legacy["property"]))
    with as_user(dsn, legacy["user"]) as c:
        assert rows(c, "SELECT id FROM exports") == []
    accept(dsn, legacy["user"], active)
    with as_user(dsn, legacy["user"]) as c:
        assert len(rows(c, "SELECT id FROM exports")) == 1


@pytest.mark.parametrize("sql", [
    "UPDATE properties SET title = 'x' RETURNING id",
    "UPDATE inspection_items SET notes = 'x' RETURNING id",
    "DELETE FROM inspection_items RETURNING id",
    "DELETE FROM evidence_files RETURNING id",
    "DELETE FROM property_documents RETURNING id",
])
def test_legacy_user_updates_and_deletes_match_nothing(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str], sql: str) -> None:
    with as_user(dsn, legacy["user"]) as c:
        assert rows(c, sql) == []
        c.commit()
    for table, key in GATED.items():
        assert owner_count(owner, table, legacy[key]) == 1


@pytest.mark.parametrize("sql", [
    "INSERT INTO rooms (property_id, name) VALUES (%(property)s, 'Hall')",
    "INSERT INTO inspection_items (inspection_id, room_id) VALUES (%(inspection)s, %(room)s)",
    "INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type) VALUES (%(property)s, %(item)s, %(evidence_key)s, 'image')",
    "INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name) VALUES (%(property)s, %(user)s, 'lease', %(document_key)s, 'l.pdf')",
])
def test_legacy_user_inserts_are_refused(dsn: str, legacy: dict[str, Any], active: dict[str, str], sql: str) -> None:
    with as_user(dsn, legacy["user"]) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute(sql, {**legacy, "evidence_key": f"{legacy['user']}/{legacy['property']}/a.jpg",
                        "document_key": f"{legacy['user']}/{legacy['property']}/l.pdf"})


def test_new_user_who_has_not_accepted_cannot_create_a_rental(dsn: str, owner: Any, active: dict[str, str]) -> None:
    user = fresh_user(owner)
    with as_user(dsn, user) as c:
        assert one(c, "SELECT get_legal_status()")[0]["blocked"] is True
        assert rows(c, "SELECT id FROM properties") == []
        with pytest.raises(errors.InsufficientPrivilege):
            c.execute("""INSERT INTO properties (user_id, title, address_line_1, city, province_state, postal_code, country)
                         VALUES (%s, 'x', 'x', 'x', 'x', 'x', 'x')""", (user,))
    accept(dsn, user, active, "apple")
    seed_rental(dsn, user)  # the whole first-run path works once accepted


def test_snapshot_rpcs_return_nothing_protected(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str]) -> None:
    """The client-callable functions run as the caller, so the gate reaches them through RLS."""
    with as_user(dsn, legacy["user"]) as c:
        v1 = one(c, "SELECT get_property_snapshot(%s)", (legacy["property"],))[0]
        v2 = one(c, "SELECT get_property_snapshot_v2(%s)", (legacy["property"],))[0]
        assert one(c, "SELECT get_vault_summaries()")[0] == []
        page = one(c, "SELECT get_room_entries_page(%s, 'move_in')", (legacy["room"],))[0]
        photos = one(c, "SELECT get_entry_photos_page(%s)", (legacy["item"],))[0]
    for snapshot in (v1, v2):
        assert snapshot["property"] is None and not snapshot["rooms"]
        assert not snapshot.get("evidence_files") and not snapshot.get("documents")
    assert page["inspection_items"] == [] and page["entries"]["evidence_files"] == []
    assert not photos.get("evidence_files")
    assert legacy["property"] not in json.dumps(v2["property"]) and "Wall" not in json.dumps([v1, v2, page, photos])


def test_second_wave_tables_are_closed_too(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str]) -> None:
    dispute = one(owner, "INSERT INTO disputes (property_id, user_id, dispute_type) VALUES (%s, %s, 'deposit_withheld') RETURNING id",
                  (legacy["property"], legacy["user"]))[0]
    owner.execute("INSERT INTO dispute_evidence_links (dispute_id, maintenance_issue_id) VALUES (%s, %s)", (dispute, legacy["maintenance"]))
    second_wave = ("maintenance_issues", "move_out_checklists", "disputes", "dispute_evidence_links", "inspection_item_tags")
    with as_user(dsn, legacy["user"]) as c:
        for table in second_wave:
            assert one(c, f"SELECT count(*) FROM {table}")[0] == 0, table
        assert one(c, "SELECT get_property_snapshot(%s)", (legacy["property"],))[0]["maintenance_issues"] == []
        v2 = one(c, "SELECT get_property_snapshot_v2(%s)", (legacy["property"],))[0]
        assert (v2["maintenance_issues"], v2["maintenance_count"]) == ([], 0)
        assert rows(c, "DELETE FROM maintenance_issues RETURNING id") == []
        assert rows(c, "UPDATE move_out_checklists SET keys_returned = true RETURNING id") == []
        c.commit()
        with pytest.raises(errors.InsufficientPrivilege):
            c.execute("INSERT INTO maintenance_issues (property_id, user_id, title) VALUES (%s, %s, 'x')", (legacy["property"], legacy["user"]))
    assert owner_count(owner, "maintenance_issues", legacy["maintenance"]) == 1
    accept(dsn, legacy["user"], active)
    with as_user(dsn, legacy["user"]) as c:
        for table in second_wave:
            assert one(c, f"SELECT count(*) FROM {table}")[0] >= 1, table


def test_every_client_data_table_carries_the_gate_and_the_open_ones_are_named(owner: Any) -> None:
    """A table added later must take a side deliberately."""
    tables = {r[0] for r in rows(owner, """SELECT c.relname FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace
        AND c.relkind = 'r' AND has_table_privilege('authenticated', c.oid, 'SELECT')""")}
    gated = {r[0] for r in rows(owner, "SELECT tablename FROM pg_policies WHERE schemaname = 'public' AND policyname LIKE '%%_legal_gate'")}
    assert tables - gated == {"profiles", "issue_tags", "legal_documents", "legal_acceptances"}


# --- what must keep working -------------------------------------------------------------

def test_blocked_user_can_still_read_legal_and_own_profile_and_accept(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str]) -> None:
    with as_user(dsn, legacy["user"]) as c:
        assert {r[0] for r in rows(c, "SELECT version FROM legal_documents WHERE active")} == set(active.values())
        assert [str(r[0]) for r in rows(c, "SELECT id FROM profiles")] == [legacy["user"]]
        assert len(rows(c, "UPDATE profiles SET full_name = 'New' WHERE id = %s RETURNING id", (legacy["user"],))) == 1
        assert one(c, "SELECT has_current_legal_acceptance()")[0] is False
        assert one(c, "SELECT legal_gate_passes()")[0] is False
        assert rows(c, "SELECT id FROM legal_acceptances") == []
        assert len(rows(c, "SELECT id FROM issue_tags")) >= 6
    assert accept(dsn, legacy["user"], active)["blocked"] is False


@pytest.mark.parametrize("role", ["movemark_api", "movemark_worker"])
def test_runtime_roles_are_not_subject_to_the_data_api_gate(dsn: str, legacy: dict[str, Any], active: dict[str, str], role: str) -> None:
    with psycopg.connect(f"{dsn}?user={role}") as c:
        assert len(rows(c, "SELECT id FROM properties WHERE user_id = %s", (legacy["user"],))) == 1


def test_account_deletion_works_for_a_blocked_user_and_only_that_user(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str]) -> None:
    other = fresh_user(owner)
    accept(dsn, other, active)
    other_rental = seed_rental(dsn, other)
    with psycopg.connect(f"{dsn}?user=movemark_api") as api:  # exactly the API's three steps
        api.execute("SELECT public.delete_user_owned_data(%s)", (legacy["user"],))
        api.execute("DELETE FROM public.storage_upload_tickets WHERE user_id = %s", (legacy["user"],))
        api.execute("SELECT public.delete_auth_user(%s)", (legacy["user"],))
    assert one(owner, "SELECT count(*) FROM properties WHERE user_id = %s", (legacy["user"],))[0] == 0
    assert one(owner, 'SELECT count(*) FROM neon_auth."user" WHERE id = %s', (legacy["user"],))[0] == 0
    assert owner_count(owner, "properties", other_rental["property"]) == 1


def test_account_deletion_removes_the_users_acceptances(dsn: str, owner: Any, active: dict[str, str]) -> None:
    user, other = fresh_user(owner), fresh_user(owner)
    accept(dsn, user, active)
    accept(dsn, other, active)
    seed_rental(dsn, user)
    with psycopg.connect(f"{dsn}?user=movemark_api") as api:
        api.execute("SELECT public.delete_user_owned_data(%s)", (user,))
        api.execute("SELECT public.delete_auth_user(%s)", (user,))
    assert one(owner, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (user,))[0] == 0
    assert one(owner, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (other,))[0] == 1


def test_a_token_for_a_deleted_account_cannot_accept(dsn: str, active: dict[str, str]) -> None:
    with as_user(dsn, str(uuid.uuid4())) as c, pytest.raises(errors.ForeignKeyViolation):
        c.execute("SELECT accept_legal_documents('email', %s, %s)", (active["terms"], active["privacy_notice"]))


# --- accepting ---------------------------------------------------------------------------

def test_accepting_unlocks_only_that_user(dsn: str, owner: Any, active: dict[str, str]) -> None:
    set_enforced(owner, False)
    a, b = fresh_user(owner), fresh_user(owner)
    rental_a, rental_b = seed_rental(dsn, a), seed_rental(dsn, b)
    set_enforced(owner, True)

    status = accept(dsn, a, active)
    assert (status["acceptance_required"], status["blocked"]) == (False, False)
    assert status["accepted"]["terms_version"] == active["terms"]

    with as_user(dsn, a) as c:
        for table, key in GATED.items():
            assert [str(r[0]) for r in rows(c, f"SELECT id FROM {table}")] == [rental_a[key]], table
    with as_user(dsn, b) as c:
        for table in GATED:
            assert rows(c, f"SELECT id FROM {table}") == [], table

    accept(dsn, b, active)
    with as_user(dsn, a) as c:  # both accepted: ownership still separates them
        for table, key in GATED.items():
            assert rows(c, f"SELECT id FROM {table} WHERE id = %s", (rental_b[key],)) == [], table
        assert rows(c, "UPDATE properties SET title = 'x' WHERE id = %s RETURNING id", (rental_b["property"],)) == []
    with as_user(dsn, b) as c:
        assert [str(r[0]) for r in rows(c, "SELECT id FROM properties")] == [rental_b["property"]]
        assert [str(r[0]) for r in rows(c, "SELECT user_id FROM legal_acceptances")] == [b]  # own records only


def test_the_server_records_time_versions_and_hashes(dsn: str, owner: Any, active: dict[str, str]) -> None:
    user = fresh_user(owner)
    before = one(owner, "SELECT now()")[0]
    accept(dsn, user, active, "google")
    terms, notice, at, method, hashes = one(owner, """SELECT terms_version, privacy_notice_version, accepted_at, acceptance_method,
        document_hashes FROM legal_acceptances WHERE user_id = %s""", (user,))
    assert (terms, notice, method) == (active["terms"], active["privacy_notice"], "google")
    assert at >= before
    assert hashes == {"terms": sha(active["terms"]), "privacy_notice": sha(active["privacy_notice"])}


def test_replaying_an_acceptance_changes_nothing(dsn: str, owner: Any, active: dict[str, str]) -> None:
    user = fresh_user(owner)
    first = accept(dsn, user, active, "apple")
    for method in ("apple", "email"):
        again = accept(dsn, user, active, method)
        assert again["accepted"] == first["accepted"]  # first row stands: same time, same method
    assert one(owner, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (user,))[0] == 1


def test_concurrent_acceptances_leave_one_row(dsn: str, owner: Any, active: dict[str, str]) -> None:
    user = fresh_user(owner)
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        results = list(pool.map(lambda _: accept(dsn, user, active), range(16)))
    assert all(r["blocked"] is False for r in results)
    assert one(owner, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (user,))[0] == 1


@pytest.mark.parametrize("method", ["facebook", "", "EMAIL", None])
def test_unknown_method_is_refused(dsn: str, owner: Any, active: dict[str, str], method: str | None) -> None:
    with as_user(dsn, fresh_user(owner)) as c, pytest.raises(errors.InvalidParameterValue, match="LEGAL_INVALID_METHOD"):
        c.execute("SELECT accept_legal_documents(%s, %s, %s)", (method, active["terms"], active["privacy_notice"]))


@pytest.mark.parametrize("which", ["terms", "privacy_notice", "both", "null"])
def test_versions_other_than_the_active_ones_are_refused(dsn: str, owner: Any, active: dict[str, str], which: str) -> None:
    terms = None if which == "null" else ("old" if which in ("terms", "both") else active["terms"])
    notice = "old" if which in ("privacy_notice", "both") else active["privacy_notice"]
    user = fresh_user(owner)
    with as_user(dsn, user) as c, pytest.raises(errors.InvalidParameterValue, match="LEGAL_VERSION_NOT_ACTIVE"):
        c.execute("SELECT accept_legal_documents('email', %s, %s)", (terms, notice))
    assert one(owner, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (user,))[0] == 0


def test_accepting_with_nothing_published_is_refused(owner: Any) -> None:
    with migrate.scratch_db(migrations_through("1050")) as conn:
        conn.execute("SET ROLE authenticated")
        conn.execute("SELECT set_config('request.jwt.claims', %s, false)", (json.dumps({"sub": str(uuid.uuid4())}),))
        with pytest.raises(errors.InvalidParameterValue, match="LEGAL_DOCUMENTS_UNAVAILABLE"):
            conn.execute("SELECT accept_legal_documents('email', 'a', 'b')")
        conn.execute("RESET ROLE")


def test_a_caller_without_identity_cannot_accept_and_is_blocked(dsn: str, active: dict[str, str]) -> None:
    conn = psycopg.connect(dsn)
    try:
        conn.execute("SET ROLE authenticated")
        assert one(conn, "SELECT legal_gate_passes()")[0] is False
        with pytest.raises(errors.InsufficientPrivilege, match="LEGAL_NOT_AUTHENTICATED"):
            conn.execute("SELECT accept_legal_documents('email', %s, %s)", (active["terms"], active["privacy_notice"]))
    finally:
        conn.rollback()
        conn.close()


# --- what a client cannot do -------------------------------------------------------------

def _forged_insert(user: str) -> tuple[str, tuple]:
    return ("""INSERT INTO legal_acceptances (user_id, terms_version, privacy_notice_version, accepted_at, acceptance_method, document_hashes)
               VALUES (%s, 'x', 'y', '2020-01-01', 'email', '{}')""", (user,))


@pytest.mark.parametrize("attempt", [
    "insert",
    "UPDATE legal_acceptances SET accepted_at = '2020-01-01'",
    "UPDATE legal_acceptances SET terms_version = 'x'",
    "DELETE FROM legal_acceptances",
    "INSERT INTO legal_documents (kind, version, content_hash, active) VALUES ('terms', 'x', repeat('0', 64), true)",
    "UPDATE legal_documents SET active = false",
    "DELETE FROM legal_documents",
    "SELECT * FROM legal_gate_settings",
    "UPDATE legal_gate_settings SET enforced = false",
    "SELECT publish_legal_document('terms', 'x', repeat('0', 64))",
    "SELECT legal_status_for_user(gen_random_uuid())",
    "SELECT legal_gate_open_for_user(gen_random_uuid())",
    "SELECT legal_user_has_current_acceptance(gen_random_uuid())",
])
def test_client_cannot_write_or_ask_about_others(dsn: str, owner: Any, active: dict[str, str], attempt: str) -> None:
    user = fresh_user(owner)
    accept(dsn, user, active)
    sql, params = _forged_insert(user) if attempt == "insert" else (attempt, ())
    with as_user(dsn, user) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute(sql, params)


def test_client_cannot_pass_a_time_or_a_user_to_the_accept_function(dsn: str, owner: Any, active: dict[str, str]) -> None:
    other = fresh_user(owner)
    with as_user(dsn, fresh_user(owner)) as c, pytest.raises(errors.UndefinedFunction):
        c.execute("SELECT accept_legal_documents('email', %s, %s, %s::timestamptz)", (active["terms"], active["privacy_notice"], "2020-01-01"))
    with as_user(dsn, fresh_user(owner)) as c, pytest.raises(errors.UndefinedFunction):
        c.execute("SELECT accept_legal_documents(%s::uuid, 'email', %s, %s)", (other, active["terms"], active["privacy_notice"]))


@pytest.mark.parametrize("fn", ["get_legal_status()", "has_current_legal_acceptance()", "legal_gate_passes()",
                                "accept_legal_documents('email', 'a', 'b')"])
def test_anonymous_calls_nothing(dsn: str, fn: str) -> None:
    with as_user(dsn, None) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute(f"SELECT {fn}")


FUNCTIONS = {
    "public.legal_user_has_current_acceptance(uuid)": set(),
    "public.legal_gate_open_for_user(uuid)": {"movemark_api"},
    "public.legal_status_for_user(uuid)": {"movemark_api"},
    "public.has_current_legal_acceptance()": {"authenticated"},
    "public.legal_gate_passes()": {"authenticated"},
    "public.get_legal_status()": {"authenticated"},
    "public.accept_legal_documents(text, text, text)": {"authenticated"},
    "public.publish_legal_document(text, text, text, text, boolean)": set(),
}


@pytest.mark.parametrize("fn", sorted(FUNCTIONS))
def test_function_grants_and_pinned_search_path(owner: Any, fn: str) -> None:
    roles = ("anonymous", "authenticated", "movemark_backend", "movemark_api", "movemark_worker", "public")
    assert {r for r in roles if one(owner, "SELECT has_function_privilege(%s, %s, 'EXECUTE')", (r, fn))[0]} == FUNCTIONS[fn]
    assert "search_path=pg_catalog, public, pg_temp" in one(owner, "SELECT array_to_string(proconfig, ' ') FROM pg_proc WHERE oid = %s::regprocedure", (fn,))[0]


def test_published_documents_are_append_only(owner: Any, active: dict[str, str]) -> None:
    with pytest.raises(errors.InsufficientPrivilege, match="append-only"):
        owner.execute("UPDATE legal_documents SET content_hash = repeat('0', 64) WHERE active AND kind = 'terms'")
    with pytest.raises(errors.InsufficientPrivilege, match="append-only"):
        owner.execute("DELETE FROM legal_documents WHERE active AND kind = 'terms'")
    with pytest.raises(errors.UniqueViolation):  # one active per kind, whatever writes
        owner.execute("INSERT INTO legal_documents (kind, version, content_hash, active) VALUES ('terms', 'second-active', repeat('0', 64), true)")


# --- a new version -----------------------------------------------------------------------

@pytest.mark.parametrize("changed", ["terms", "notice", "both"])
def test_new_version_requires_acceptance_again_without_touching_data(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str], changed: str) -> None:
    accept(dsn, legacy["user"], active)
    with as_user(dsn, legacy["user"]) as c:
        assert len(rows(c, "SELECT id FROM properties")) == 1

    tag = uuid.uuid4().hex[:8]
    current = publish(owner, terms=f"t2-{tag}" if changed != "notice" else None, notice=f"p2-{tag}" if changed != "terms" else None)

    with as_user(dsn, legacy["user"]) as c:
        assert rows(c, "SELECT id FROM properties") == []
        s = one(c, "SELECT get_legal_status()")[0]
        assert (s["blocked"], s["accepted"]) == (True, None)
        with pytest.raises(errors.InvalidParameterValue, match="LEGAL_VERSION_NOT_ACTIVE"):  # the old screen
            c.execute("SELECT accept_legal_documents('email', %s, %s)", (active["terms"], active["privacy_notice"] + "-stale"))
    for table, key in GATED.items():
        assert owner_count(owner, table, legacy[key]) == 1

    accept(dsn, legacy["user"], current)
    with as_user(dsn, legacy["user"]) as c:
        for table, key in GATED.items():
            assert [str(r[0]) for r in rows(c, f"SELECT id FROM {table}")] == [legacy[key]], table
    assert one(owner, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (legacy["user"],))[0] == 2  # history kept


# --- policy expansion ---------------------------------------------------------------------

CLIENT_TABLES = ["properties", "rooms", "inspections", "inspection_items", "inspection_item_tags", "evidence_files",
                 "property_documents", "exports", "maintenance_issues", "move_out_checklists", "move_out_checklist_state",
                 "disputes", "dispute_evidence_links", "profiles", "issue_tags"]


@pytest.mark.parametrize("table", CLIENT_TABLES)
def test_no_command_on_any_client_table_hits_policy_recursion(dsn: str, owner: Any, table: str) -> None:
    """A policy containing a subquery can't be re-entered (42P17, an HTTP 500 through the Data API). The gate
    adds a subquery to seven tables; every command must still expand, whether or not it is then permitted."""
    col = one(owner, """SELECT a.attname FROM pg_attribute a WHERE a.attrelid = %s::regclass AND a.attnum > 0 AND NOT a.attisdropped
                         ORDER BY a.attnum LIMIT 1""", (f"public.{table}",))[0]
    for sql in (f"SELECT * FROM {table}", f"UPDATE {table} SET {col} = {col}", f"DELETE FROM {table}",
                f"INSERT INTO {table} SELECT * FROM {table}"):
        with as_user(dsn, fresh_user(owner)) as c:
            try:
                c.execute(f"EXPLAIN {sql}")
            except errors.InsufficientPrivilege:
                pass  # not granted to the apps: the expected refusal, and it means expansion succeeded


# --- plan shape ---------------------------------------------------------------------------

def test_helper_is_an_initplan_evaluated_once_per_statement(dsn: str, owner: Any, active: dict[str, str]) -> None:
    user = fresh_user(owner)
    accept(dsn, user, active)
    rental = seed_rental(dsn, user)
    owner.execute("INSERT INTO rooms (property_id, name) SELECT %s, 'R' || g FROM generate_series(1, 500) g", (rental["property"],))
    owner.execute("ANALYZE rooms")
    with as_user(dsn, user) as c:
        lines = [r[0] for r in rows(c, "EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF) SELECT id FROM rooms WHERE property_id = %s", (rental["property"],))]
    text = "\n".join(lines)
    assert "InitPlan 1" in text and "(InitPlan 1).col1" in text, text
    assert "rows=501" in text
    result = lines[next(i for i, line in enumerate(lines) if "InitPlan 1" in line and "Filter" not in line) + 1]
    assert "loops=1)" in result, text  # one evaluation for 501 rows


def test_a_blocked_read_returns_no_rows_from_an_initplan_false(dsn: str, owner: Any, legacy: dict[str, Any], active: dict[str, str]) -> None:
    with as_user(dsn, legacy["user"]) as c:
        text = "\n".join(r[0] for r in rows(c, "EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF) SELECT id FROM properties"))
    assert "(InitPlan 1).col1" in text and "actual rows=0" in text, text


# --- forward and rollback -----------------------------------------------------------------

def test_rollback_of_each_migration_restores_the_previous_schema_exactly() -> None:
    down = NEON / "rollback"
    with migrate.scratch_db(migrations_through("1020")) as before:
        through_1020 = migrate.fingerprint(before)
    with migrate.scratch_db(migrations_through("1030")) as mid:
        through_1030 = migrate.fingerprint(mid)
    with migrate.scratch_db(migrations_through("1040")) as mid:
        through_1040 = migrate.fingerprint(mid)
    with migrate.scratch_db(migrations_through("1050")) as conn:
        through_1050 = migrate.fingerprint(conn)
        assert through_1050 != through_1040 != through_1030 != through_1020
        conn.execute((down / "1050_legal_gate_rls_wave2.down.sql").read_text())
        assert migrate.diff(through_1040, migrate.fingerprint(conn), "1040", "rolled back") == []
        conn.execute((down / "1040_legal_gate_rls.down.sql").read_text())
        assert migrate.diff(through_1030, migrate.fingerprint(conn), "1030", "rolled back") == []
        conn.execute((down / "1030_legal_acceptance.down.sql").read_text())
        assert migrate.diff(through_1020, migrate.fingerprint(conn), "1020", "rolled back") == []
        for version in ("1030", "1040", "1050"):  # and forward again
            conn.execute(next((NEON / "migrations").glob(f"{version}_*.sql")).read_text())
        assert migrate.diff(through_1050, migrate.fingerprint(conn), "1050", "reapplied") == []


def test_rolling_back_enforcement_keeps_acceptances_and_reopens_data(dsn: str) -> None:
    uid, down = str(uuid.uuid4()), NEON / "rollback"
    with migrate.scratch_db(migrations_through("1050")) as conn:
        conn.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, "r@qa.test"))
        conn.execute("""INSERT INTO properties (user_id, title, address_line_1, city, province_state, postal_code, country)
                        VALUES (%s, 'x', 'x', 'x', 'x', 'x', 'x')""", (uid,))
        conn.execute("SELECT publish_legal_document('terms', 't1', %s)", (sha("t"),))
        conn.execute("SELECT publish_legal_document('privacy_notice', 'p1', %s)", (sha("p"),))
        conn.execute("UPDATE legal_gate_settings SET enforced = true")

        def visible() -> int:
            conn.execute("SET ROLE authenticated")
            conn.execute("SELECT set_config('request.jwt.claims', %s, false)", (json.dumps({"sub": uid}),))
            found = conn.execute("SELECT count(*) FROM properties").fetchone()[0]
            conn.execute("RESET ROLE")
            return found

        assert visible() == 0
        conn.execute((down / "1050_legal_gate_rls_wave2.down.sql").read_text())
        conn.execute((down / "1040_legal_gate_rls.down.sql").read_text())
        assert visible() == 1  # enforcement went with the policies; the switch and the records stayed
        assert conn.execute("SELECT enforced FROM legal_gate_settings").fetchone()[0] is True
