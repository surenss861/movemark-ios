"""1061: an unknown identity can never be read as "acceptance required"; it is an auth error.

Local Postgres only (same harness as test_legal_gate.py). MOVEMARK_LEGAL_THROUGH=1058 builds the database without
1061, to show the defect these tests pin:

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_legal_status_identity.py -q
    MOVEMARK_LEGAL_THROUGH=1058 movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_legal_status_identity.py -q

States covered:
  no identity                        -> LEGAL_NOT_AUTHENTICATED (42501), never a status
  an identity that isn't a user id   -> an explicit error, never a status ("status unavailable")
  authenticated, current acceptance  -> acceptance_required false
  authenticated, no acceptance       -> acceptance_required true
  authenticated, a new version       -> acceptance_required true again
No new bypass: anonymous, PUBLIC and authenticated-on-someone-else's-status are all refused; grants are unchanged.
Rollback: apply -> rollback -> the defect returns -> reapply -> fixed.
"""
from __future__ import annotations

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

from test_reconstruction import as_user, one  # noqa: E402

NEON = pathlib.Path(__file__).resolve().parents[1]
ADMIN_DSN = os.getenv("MOVEMARK_TEST_ADMIN_DSN", "postgresql:///postgres")
THROUGH = os.getenv("MOVEMARK_LEGAL_THROUGH", "9999")
FIXED = THROUGH >= "1061"
DB = f"movemark_neon_legal_identity_{THROUGH}"
MIGRATION = NEON / "migrations" / "1061_legal_status_requires_identity.sql"
ROLLBACK = NEON / "rollback" / "1061_legal_status_requires_identity.down.sql"

spec = importlib.util.spec_from_file_location("migrate_for_legal_identity", NEON / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)


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
        for f in migrations_through(THROUGH):
            conn.execute(f.read_text())
    yield url
    with psycopg.connect(ADMIN_DSN, autocommit=True) as admin2:
        admin2.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')


@pytest.fixture(scope="module")
def owner(dsn: str) -> Iterator[Any]:
    with psycopg.connect(dsn, autocommit=True) as conn:
        yield conn


def status_with_claims(conn_or_dsn: Any, claims: dict[str, Any] | None) -> dict[str, Any]:
    """A Data API request as role `authenticated` with these JWT claims (None: no claims at all)."""
    conn = psycopg.connect(conn_or_dsn) if isinstance(conn_or_dsn, str) else conn_or_dsn
    try:
        conn.execute("SET ROLE authenticated")
        conn.execute("SELECT set_config('request.jwt.claims', %s, false)", (json.dumps(claims) if claims is not None else "",))
        return conn.execute("SELECT get_legal_status()").fetchone()[0]
    finally:
        conn.rollback()
        if isinstance(conn_or_dsn, str):
            conn.close()
        else:
            conn.execute("RESET ROLE")


def new_user(owner: Any) -> str:
    uid = str(uuid.uuid4())
    owner.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    return uid


def active(owner: Any) -> dict[str, str]:
    return dict(owner.execute("SELECT kind, version FROM legal_documents WHERE active").fetchall())


def accept(dsn: str, user: str, docs: dict[str, str]) -> None:
    with as_user(dsn, user) as c:
        c.execute("SELECT accept_legal_documents('email', %s, %s, 'bands_v2', '18_plus', false)",
                  (docs["terms"], docs["privacy_notice"]))
        c.commit()


def status_of(dsn: str, user: str) -> dict[str, Any]:
    with as_user(dsn, user) as c:
        return one(c, "SELECT get_legal_status()")[0]


NO_IDENTITY = [None, {}, {"sub": ""}, {"role": "authenticated"}]
NO_IDENTITY_IDS = ["no-claims", "empty-claims", "empty-sub", "no-sub"]


# --- the defect and the fix -------------------------------------------------------------------------------------

def test_documents_are_published_as_in_production(owner: Any) -> None:
    assert active(owner) == {"terms": "2.0", "privacy_notice": "2.0"}


@pytest.mark.parametrize("claims", NO_IDENTITY, ids=NO_IDENTITY_IDS)
def test_no_identity_is_an_auth_error_never_acceptance_required(dsn: str, claims: dict[str, Any] | None) -> None:
    with pytest.raises(errors.InsufficientPrivilege, match="LEGAL_NOT_AUTHENTICATED"):
        status = status_with_claims(dsn, claims)
        pytest.fail(f"answered for an unknown identity: {status}")


def test_an_identity_that_is_not_a_user_id_is_an_explicit_error(dsn: str) -> None:
    # "Status unavailable": the caller gets an error it must show as such, never a status to act on.
    with pytest.raises(errors.InvalidTextRepresentation):
        status_with_claims(dsn, {"sub": "not-a-uuid"})


# --- authenticated states (unchanged) ---------------------------------------------------------------------------

def test_authenticated_with_current_acceptance_is_accepted(dsn: str, owner: Any) -> None:
    user = new_user(owner)
    accept(dsn, user, active(owner))
    status = status_of(dsn, user)
    assert status["acceptance_required"] is False
    assert status["accepted"]["terms_version"] == "2.0" and status["accepted"]["age_band"] == "18_plus"


def test_authenticated_without_acceptance_needs_acceptance(dsn: str, owner: Any) -> None:
    status = status_of(dsn, new_user(owner))
    assert status["acceptance_required"] is True and status["accepted"] is None


def test_authenticated_after_a_new_version_needs_acceptance_again() -> None:
    # Its own database: publishing is append-only and would change the documents for every other test.
    with migrate.scratch_db(migrations_through(THROUGH)) as conn:
        dsn = conn.info.dsn
        user = new_user(conn)
        accept(dsn, user, active(conn))
        assert status_of(dsn, user)["acceptance_required"] is False
        for kind in ("terms", "privacy_notice"):
            text = f"{kind} 2.1"
            conn.execute("SELECT publish_legal_document(%s, '2.1', %s, NULL, true)", (kind, hashlib.sha256(text.encode()).hexdigest()))
        status = status_of(dsn, user)
        assert status["acceptance_required"] is True
        assert status["documents"]["terms"]["version"] == "2.1"
        if FIXED:
            with pytest.raises(errors.InsufficientPrivilege, match="LEGAL_NOT_AUTHENTICATED"):
                status_with_claims(dsn, None)


# --- no new bypass ----------------------------------------------------------------------------------------------

def test_anonymous_cannot_call_either_status_function(dsn: str) -> None:
    for sql in ("SELECT get_legal_status()", f"SELECT legal_status_for_user('{uuid.uuid4()}')"):
        with as_user(dsn, None) as c, pytest.raises(errors.InsufficientPrivilege):
            c.execute(sql)


def test_authenticated_cannot_read_another_accounts_status(dsn: str, owner: Any) -> None:
    other = new_user(owner)
    with as_user(dsn, new_user(owner)) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute("SELECT legal_status_for_user(%s)", (other,))


def test_each_account_only_ever_sees_its_own_status(dsn: str, owner: Any) -> None:
    accepted, fresh = new_user(owner), new_user(owner)
    accept(dsn, accepted, active(owner))
    assert status_of(dsn, fresh)["acceptance_required"] is True
    assert status_of(dsn, accepted)["acceptance_required"] is False


def test_privileges_are_exactly_as_before(owner: Any) -> None:
    def acl(signature: str) -> dict[str, bool]:
        roles = ("authenticated", "anonymous", "movemark_api", "movemark_worker", "public")
        out = {}
        for r in roles:
            if r == "public":
                out[r] = owner.execute(
                    "SELECT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a "
                    "WHERE p.oid = %s::regprocedure AND a.grantee = 0 AND a.privilege_type = 'EXECUTE')", (signature,)).fetchone()[0]
            elif owner.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (r,)).fetchone():
                out[r] = owner.execute("SELECT has_function_privilege(%s, %s, 'EXECUTE')", (r, signature)).fetchone()[0]
        return out

    g = acl("public.get_legal_status()")
    assert g["authenticated"] is True and g["anonymous"] is False and g["public"] is False
    assert g.get("movemark_worker", False) is False
    s = acl("public.legal_status_for_user(uuid)")
    assert s["authenticated"] is False and s["anonymous"] is False and s["public"] is False
    assert s.get("movemark_api", True) is True
    sec = owner.execute("""SELECT p.prosecdef, p.proconfig, l.lanname, pg_get_function_result(p.oid)
                           FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
                           WHERE p.oid = 'public.get_legal_status()'::regprocedure""").fetchone()
    assert sec[0] is True and sec[1] == ["search_path=pg_catalog, public, pg_temp"] and sec[3] == "jsonb"
    assert sec[2] == ("plpgsql" if FIXED else "sql")


# --- rollback procedure -----------------------------------------------------------------------------------------

def test_apply_rollback_reapply() -> None:
    if not FIXED:
        pytest.skip("1061 not in this build")
    with migrate.scratch_db(migrations_through("1058")) as conn:
        dsn = conn.info.dsn
        assert status_with_claims(conn, None)["acceptance_required"] is True       # 1058: the defect
        conn.execute(MIGRATION.read_text())                                         # apply 1061
        with pytest.raises(errors.InsufficientPrivilege, match="LEGAL_NOT_AUTHENTICATED"):
            status_with_claims(dsn, None)
        user = new_user(conn)
        accept(dsn, user, active(conn))
        conn.execute(ROLLBACK.read_text())                                          # roll back
        assert status_with_claims(conn, None)["acceptance_required"] is True       # the defect returns
        assert status_of(dsn, user)["acceptance_required"] is False                # data untouched
        conn.execute(MIGRATION.read_text())                                         # reapply
        with pytest.raises(errors.InsufficientPrivilege, match="LEGAL_NOT_AUTHENTICATED"):
            status_with_claims(dsn, None)
        assert status_of(dsn, user)["acceptance_required"] is False
        g = conn.execute("SELECT has_function_privilege('anonymous', 'public.get_legal_status()', 'EXECUTE'), "
                         "has_function_privilege('authenticated', 'public.get_legal_status()', 'EXECUTE')").fetchone()
        assert g == (False, True)
