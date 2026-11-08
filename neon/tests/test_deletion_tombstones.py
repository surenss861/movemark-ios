"""Deletion tombstones (1060). Local Postgres only, like test_reconstruction.py, whose helpers it shares.

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_deletion_tombstones.py -q
"""
from __future__ import annotations

import hashlib
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
DB = "movemark_neon_tombstones"
RUNTIME_ROLES = ("anonymous", "authenticated", "movemark_backend", "movemark_api", "movemark_worker")


def expected_hash(subject: str) -> str:
    return hashlib.sha256(("movemark-deletion-v1:" + subject.lower()).encode()).hexdigest()


@pytest.fixture(scope="module")
def dsn() -> Iterator[str]:
    try:
        admin = psycopg.connect(ADMIN_DSN, autocommit=True, connect_timeout=3)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"no local Postgres: {e}")
    with admin:
        admin.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')
        admin.execute(f'CREATE DATABASE "{DB}"')
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
        conn.execute("DELETE FROM public.deletion_tombstones")
        yield conn


def fresh_user(owner: Any, seed: str | None = None) -> str:
    uid = str(uuid.uuid4())
    owner.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    return uid


def delete_account(owner: Any, uid: str) -> None:
    owner.execute("SELECT public.delete_user_owned_data(%s)", (uid,))
    owner.execute("DELETE FROM public.storage_upload_tickets WHERE user_id = %s", (uid,))
    owner.execute("SELECT public.delete_auth_user(%s)", (uid,))


def tombstones(owner: Any) -> set[tuple[str, str]]:
    return {tuple(r) for r in rows(owner, "SELECT kind, subject_hash FROM public.deletion_tombstones")}


def test_the_sql_hash_equals_the_python_hash(owner: Any) -> None:
    subject = str(uuid.uuid4())
    owner.execute("SELECT public.record_deletion('account', %s)", (subject,))
    assert tombstones(owner) == {("account", expected_hash(subject))}


def test_account_deletion_records_one_tombstone_and_rentals_too(dsn: str, owner: Any) -> None:
    uid = fresh_user(owner)
    ids = seed_rental(dsn, uid)
    delete_account(owner, uid)
    assert tombstones(owner) == {("account", expected_hash(uid)), ("property", expected_hash(ids["property"]))}


def test_a_row_holds_nothing_but_the_hash_kind_and_day(dsn: str, owner: Any) -> None:
    columns = [r[0] for r in rows(owner, """SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'deletion_tombstones' ORDER BY ordinal_position""")]
    assert columns == ["kind", "subject_hash", "deleted_on"]
    uid = fresh_user(owner)
    delete_account(owner, uid)
    assert uid not in str(rows(owner, "SELECT * FROM public.deletion_tombstones"))


def test_a_deletion_that_fails_partway_is_already_recorded(dsn: str, owner: Any) -> None:
    """Storage cleanup fails after the rows commit: the identity stays, so a restore must still finish the job."""
    uid = fresh_user(owner)
    seed_rental(dsn, uid)
    owner.execute("SELECT public.delete_user_owned_data(%s)", (uid,))
    assert one(owner, 'SELECT count(*) FROM neon_auth."user" WHERE id = %s', (uid,))[0] == 1
    assert ("account", expected_hash(uid)) in tombstones(owner)


def test_a_rolled_back_deletion_records_nothing(dsn: str) -> None:
    with psycopg.connect(dsn) as conn:
        conn.execute("DELETE FROM public.deletion_tombstones")
        conn.commit()
        conn.execute("SELECT public.record_deletion('account', %s)", (str(uuid.uuid4()),))
        conn.rollback()
        assert one(conn, "SELECT count(*) FROM public.deletion_tombstones")[0] == 0


def test_the_identity_step_alone_records_the_account(owner: Any) -> None:
    uid = fresh_user(owner)
    owner.execute("SELECT public.delete_auth_user(%s)", (uid,))
    assert tombstones(owner) == {("account", expected_hash(uid))}


def test_repeating_a_deletion_keeps_the_first_day(owner: Any) -> None:
    uid = fresh_user(owner)
    owner.execute("SELECT public.delete_user_owned_data(%s)", (uid,))
    owner.execute("UPDATE public.deletion_tombstones SET deleted_on = current_date - 3")
    day = one(owner, "SELECT deleted_on FROM public.deletion_tombstones")[0]
    delete_account(owner, uid)
    assert rows(owner, "SELECT deleted_on FROM public.deletion_tombstones") == [(day,)]


def test_rental_deletion_is_recorded_on_every_path(dsn: str, owner: Any) -> None:
    uid = fresh_user(owner)
    ids = seed_rental(dsn, uid)
    owner.execute("DELETE FROM public.dispute_evidence_links")
    list(rows(owner, "SELECT * FROM public.delete_property_owned_data(%s, %s)", (uid, ids["property"])))
    assert tombstones(owner) == {("property", expected_hash(ids["property"]))}


def test_a_null_id_is_refused(owner: Any) -> None:
    with pytest.raises(errors.RaiseException):
        owner.execute("SELECT public.record_deletion('account', NULL)")


def test_an_unknown_kind_is_refused(owner: Any) -> None:
    with pytest.raises(errors.CheckViolation):
        owner.execute("SELECT public.record_deletion('photo', %s)", (str(uuid.uuid4()),))


def test_tombstones_expire_after_120_days_and_not_before(owner: Any) -> None:
    owner.execute("INSERT INTO public.deletion_tombstones VALUES ('account', %s, (now() AT TIME ZONE 'utc')::date - 121)", ("a" * 64,))
    owner.execute("INSERT INTO public.deletion_tombstones VALUES ('account', %s, (now() AT TIME ZONE 'utc')::date - 120)", ("b" * 64,))
    owner.execute("SELECT public.record_deletion('account', %s)", (str(uuid.uuid4()),))
    held = {h for _, h in tombstones(owner)}
    assert "a" * 64 not in held and "b" * 64 in held and len(held) == 2


@pytest.mark.parametrize("role", RUNTIME_ROLES)
@pytest.mark.parametrize("privilege", ("SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"))
def test_no_client_or_runtime_role_reaches_the_table(owner: Any, role: str, privilege: str) -> None:
    assert one(owner, "SELECT has_table_privilege(%s, 'public.deletion_tombstones', %s)", (role, privilege))[0] is False


@pytest.mark.parametrize("role", RUNTIME_ROLES)
def test_no_role_can_call_the_trigger_function(owner: Any, role: str) -> None:
    assert one(owner, "SELECT has_function_privilege(%s, 'public.record_property_deletion()', 'EXECUTE')", (role,))[0] is False


def test_rls_is_on_with_no_policies(owner: Any) -> None:
    assert one(owner, "SELECT relrowsecurity FROM pg_class WHERE oid = 'public.deletion_tombstones'::regclass")[0] is True
    assert one(owner, "SELECT count(*) FROM pg_policies WHERE tablename = 'deletion_tombstones'")[0] == 0


def test_a_data_api_client_cannot_read_or_forge(dsn: str, owner: Any) -> None:
    uid = fresh_user(owner)
    for statement in ("SELECT * FROM public.deletion_tombstones",
                      "INSERT INTO public.deletion_tombstones VALUES ('account', repeat('a', 64))"):
        with as_user(dsn, uid) as c, pytest.raises(errors.InsufficientPrivilege):
            c.execute(statement)
    with as_user(dsn, uid) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute("SELECT public.record_deletion('account', %s)", (uid,))


def test_the_backup_role_reads_it_and_only_reads(owner: Any) -> None:
    assert one(owner, "SELECT has_table_privilege('movemark_backup', 'public.deletion_tombstones', 'SELECT')")[0] is True
    assert one(owner, "SELECT has_table_privilege('movemark_backup', 'public.deletion_tombstones', 'INSERT')")[0] is False


def test_the_runtime_role_can_still_delete_an_account_as_it_does_today(dsn: str, owner: Any) -> None:
    """movemark_api has EXECUTE on the two functions and nothing on the tombstones, and that must be enough."""
    uid = fresh_user(owner)
    seed_rental(dsn, uid)
    with psycopg.connect(dsn) as conn:
        conn.execute("SET ROLE movemark_api")
        conn.execute("SELECT public.delete_user_owned_data(%s)", (uid,))
        conn.execute("SELECT public.delete_auth_user(%s)", (uid,))
        conn.commit()
    assert ("account", expected_hash(uid)) in tombstones(owner)


def test_rollback_body_returns_the_earlier_functions_exactly(dsn: str) -> None:
    """Applied to a scratch copy: fingerprint equals a build through 1055 (the migration before 1060)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("migrate_for_tombstones", NEON / "migrate.py")
    migrate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migrate)
    files = sorted((NEON / "migrations").glob("*.sql"))
    with migrate.scratch_db([p for p in files if p.name[:4] <= "1055"]) as before:
        reference = migrate.fingerprint(before)
    with migrate.scratch_db(files) as after:
        after.execute((NEON / "rollback" / "1060_deletion_tombstones.down.sql").read_text())
        assert migrate.diff(reference, migrate.fingerprint(after), "through 1055", "1060 rolled back") == []
