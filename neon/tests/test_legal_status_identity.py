"""1059: an unknown identity can never be read as "acceptance required"; it is an auth error.

Local Postgres only (same harness as test_legal_gate.py). MOVEMARK_LEGAL_THROUGH=1058 builds the database without
1059, to show the defect these tests pin:

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_legal_status_identity.py -q
    MOVEMARK_LEGAL_THROUGH=1058 movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_legal_status_identity.py -q
"""
from __future__ import annotations

import hashlib
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
DB = f"movemark_neon_legal_identity_{THROUGH}"


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
            if f.name[:4] <= THROUGH:
                conn.execute(f.read_text())
    yield url
    with psycopg.connect(ADMIN_DSN, autocommit=True) as admin2:
        admin2.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')


@pytest.fixture(scope="module")
def owner(dsn: str) -> Iterator[Any]:
    with psycopg.connect(dsn, autocommit=True) as conn:
        yield conn


def _status_with_claims(dsn: str, claims: dict[str, Any] | None) -> dict[str, Any]:
    """A Data API request as role `authenticated` with these JWT claims (None: no claims at all)."""
    conn = psycopg.connect(dsn)
    try:
        conn.execute("SET ROLE authenticated")
        if claims is not None:
            conn.execute("SELECT set_config('request.jwt.claims', %s, false)", (json.dumps(claims),))
        return conn.execute("SELECT get_legal_status()").fetchone()[0]
    finally:
        conn.rollback()
        conn.close()


def _user(owner: Any) -> str:
    uid = str(uuid.uuid4())
    owner.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    return uid


def _active(owner: Any) -> dict[str, str]:
    return dict(owner.execute("SELECT kind, version FROM legal_documents WHERE active").fetchall())


def test_published_documents_are_in_place(owner: Any) -> None:
    # 1058 publishes 2.0: the situation in production, where a NULL caller read as "required".
    assert _active(owner) == {"terms": "2.0", "privacy_notice": "2.0"}


@pytest.mark.parametrize("claims", [None, {}, {"sub": ""}, {"role": "authenticated"}], ids=["no-claims", "empty", "empty-sub", "no-sub"])
def test_no_user_id_is_an_auth_error_never_acceptance_required(dsn: str, claims: dict[str, Any] | None) -> None:
    with pytest.raises(errors.InsufficientPrivilege, match="LEGAL_NOT_AUTHENTICATED"):
        status = _status_with_claims(dsn, claims)
        pytest.fail(f"answered for an unknown identity: {status}")


def test_anonymous_still_cannot_call_it(dsn: str) -> None:
    with as_user(dsn, None) as c, pytest.raises(errors.InsufficientPrivilege):
        c.execute("SELECT get_legal_status()")


def test_a_real_account_without_acceptance_is_still_asked(dsn: str, owner: Any) -> None:
    user = _user(owner)
    with as_user(dsn, user) as c:
        status = one(c, "SELECT get_legal_status()")[0]
    assert status["acceptance_required"] is True


def test_a_real_account_that_accepted_is_not_asked(dsn: str, owner: Any) -> None:
    user = _user(owner)
    active = _active(owner)
    with as_user(dsn, user) as c:
        c.execute("SELECT accept_legal_documents('email', %s, %s, 'bands_v2', '18_plus', false)",
                  (active["terms"], active["privacy_notice"]))
        c.commit()
    with as_user(dsn, user) as c:
        status = one(c, "SELECT get_legal_status()")[0]
    assert status["acceptance_required"] is False
    assert status["accepted"]["age_band"] == "18_plus"


def test_signature_language_and_grants(owner: Any) -> None:
    row = owner.execute("""
        SELECT p.prosecdef, l.lanname, pg_get_function_result(p.oid),
               has_function_privilege('authenticated', p.oid, 'EXECUTE'),
               has_function_privilege('anonymous', p.oid, 'EXECUTE')
        FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
        WHERE p.oid = 'public.get_legal_status()'::regprocedure""").fetchone()
    assert row[0] is True and row[2] == "jsonb" and row[3] is True and row[4] is False
    if THROUGH >= "1059":
        assert row[1] == "plpgsql"


def test_rollback_restores_the_1030_body(dsn: str) -> None:
    if THROUGH < "1059":
        pytest.skip("1059 not applied")
    with psycopg.connect(dsn) as conn:
        conn.execute((NEON / "rollback" / "1059_legal_status_requires_identity.down.sql").read_text())
        lang = conn.execute("""SELECT l.lanname FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
                               WHERE p.oid = 'public.get_legal_status()'::regprocedure""").fetchone()[0]
        assert lang == "sql"
        conn.execute("SET ROLE authenticated")
        assert conn.execute("SELECT get_legal_status()").fetchone()[0]["acceptance_required"] is True  # the defect
        conn.rollback()
