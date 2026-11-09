"""1058 publishes Terms 2.0 and Privacy 2.0 as final documents: a data-only, user-facing migration.

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_publish_1058.py -q

Optional cross-check against the website: set MOVEMARK_WEB_DIR to the website checkout (default ../wt-web-legal
next to this repository's worktree) and the hashes in 1058 must equal src/content/legal/manifest.ts.
"""
from __future__ import annotations

import importlib.util
import os
import pathlib
import re
import uuid
from typing import Any

import pytest

psycopg = pytest.importorskip("psycopg")

from test_reconstruction import as_user, one, rows  # noqa: E402

NEON = pathlib.Path(__file__).resolve().parents[1]
MIGRATION = NEON / "migrations" / "1058_publish_legal_documents_2_0.sql"
ROLLBACK = NEON / "rollback" / "1058_publish_legal_documents_2_0.down.sql"

spec = importlib.util.spec_from_file_location("migrate_for_1058", NEON / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)


def through(version: str) -> list[pathlib.Path]:
    return [p for p in sorted((NEON / "migrations").glob("*.sql")) if p.name[:4] <= version]


def hashes_in_migration() -> dict[str, str]:
    text = MIGRATION.read_text()
    found = dict(re.findall(r"'(terms|privacy_notice)', '2\.0',\s*'([0-9a-f]{64})'", text))
    assert set(found) == {"terms", "privacy_notice"}
    return found


def dsn_of(conn: Any) -> str:
    return migrate.LOCAL_ADMIN.rsplit("/", 1)[0] + "/" + conn.info.dbname


def existing_user(conn: Any) -> str:
    uid = str(uuid.uuid4())
    conn.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    return uid


def status(dsn: str, user: str) -> dict[str, Any]:
    with as_user(dsn, user) as c:
        return one(c, "SELECT get_legal_status()")[0]


def test_1058_publishes_both_final_documents_and_changes_no_schema() -> None:
    with migrate.scratch_db(through("1057")) as conn:
        before = migrate.fingerprint(conn)
        assert rows(conn, "SELECT kind FROM legal_documents WHERE active") == []
        conn.execute(MIGRATION.read_text())
        assert migrate.diff(before, migrate.fingerprint(conn), "1057", "1058") == []  # data only
        active = {k: (v, h, u, f) for k, v, h, u, f in rows(
            conn, "SELECT kind, version, content_hash, url, is_final FROM legal_documents WHERE active")}
        expected = hashes_in_migration()
        assert active == {
            "terms": ("2.0", expected["terms"], "https://movemark.ca/terms", True),
            "privacy_notice": ("2.0", expected["privacy_notice"], "https://movemark.ca/privacy", True),
        }
        assert one(conn, "SELECT enforced FROM legal_gate_settings")[0] is False  # enforcement is separate


def test_existing_users_must_accept_after_1058_and_a_bands_v2_acceptance_clears_it() -> None:
    with migrate.scratch_db(through("1057")) as conn:
        dsn = dsn_of(conn)
        user = existing_user(conn)
        assert status(dsn, user)["acceptance_required"] is False  # nothing published: no gate
        conn.execute(MIGRATION.read_text())
        after = status(dsn, user)
        assert after["acceptance_required"] is True and after["enforced"] is False
        with as_user(dsn, user) as c:  # an old 5-argument client can't accept under bands_v2
            with pytest.raises(psycopg.Error):
                c.execute("SELECT accept_legal_documents('email', '2.0', '2.0', 'bands_v1', '18_plus')")
        with as_user(dsn, user) as c:  # RC5: age range + "No" to Quebec
            one(c, "SELECT accept_legal_documents('email', '2.0', '2.0', 'bands_v2', '18_plus', false)")
            c.commit()
        assert status(dsn, user)["acceptance_required"] is False
        recorded = one(conn, "SELECT document_hashes, residence FROM legal_acceptances WHERE user_id = %s", (user,))
        assert recorded[0] == hashes_in_migration() and recorded[1] == "outside_quebec"


def test_quebec_yes_is_refused_after_1058_and_records_nothing() -> None:
    with migrate.scratch_db(through("1058")) as conn:
        dsn = dsn_of(conn)
        user = existing_user(conn)
        with as_user(dsn, user) as c:
            with pytest.raises(psycopg.Error, match="LEGAL_REGION_NOT_AVAILABLE"):
                c.execute("SELECT accept_legal_documents('email', '2.0', '2.0', 'bands_v2', '18_plus', true)")
        assert one(conn, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (user,))[0] == 0
        assert status(dsn, user)["acceptance_required"] is True


def test_rollback_retires_2_0_keeps_acceptances_and_removes_the_gate() -> None:
    with migrate.scratch_db(through("1058")) as conn:
        dsn = dsn_of(conn)
        before = migrate.fingerprint(conn)
        accepted, pending = existing_user(conn), existing_user(conn)
        with as_user(dsn, accepted) as c:
            one(c, "SELECT accept_legal_documents('email', '2.0', '2.0', 'bands_v2', '18_plus', false)")
            c.commit()
        conn.execute(ROLLBACK.read_text())
        assert migrate.diff(before, migrate.fingerprint(conn), "1058", "rolled back") == []
        assert rows(conn, "SELECT kind FROM legal_documents WHERE active") == []
        assert one(conn, "SELECT count(*) FROM legal_documents WHERE version = '2.0'")[0] == 2  # append-only: kept
        assert one(conn, "SELECT count(*) FROM legal_acceptances WHERE user_id = %s", (accepted,))[0] == 1
        assert status(dsn, pending)["acceptance_required"] is False


def test_1058_hashes_equal_the_website_manifest() -> None:
    default = NEON.parents[1] / "wt-web-legal"
    web = pathlib.Path(os.getenv("MOVEMARK_WEB_DIR", str(default)))
    manifest = web / "src" / "content" / "legal" / "manifest.ts"
    if not manifest.exists():
        pytest.skip(f"website checkout not found at {web}")
    text = manifest.read_text()
    live = dict(re.findall(r'^\s*(terms|privacy_notice): \{[^}]*?contentHash: "([0-9a-f]{64})"', text, re.M))
    assert live == hashes_in_migration(), "1058 is stale: re-run npm run legal:manifest and update the migration"
