"""1056: a teen account's photos and documents can only point at objects the API checked for metadata.

Local Postgres only, like test_legal_gate.py.
"""
from __future__ import annotations

import os
import pathlib
import uuid
from typing import Any, Iterator

import pytest

psycopg = pytest.importorskip("psycopg")
from psycopg import errors  # noqa: E402

from test_reconstruction import as_user, one, seed_rental  # noqa: E402

NEON = pathlib.Path(__file__).resolve().parents[1]
ADMIN_DSN = os.getenv("MOVEMARK_TEST_ADMIN_DSN", "postgresql:///postgres")
DB = "movemark_neon_teen_uploads"


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


def account(owner: Any, dsn: str, category: str | None) -> dict[str, str]:
    uid = str(uuid.uuid4())
    owner.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    ids = {"user": uid, **seed_rental(dsn, uid)}  # seeded before the category, as an adult would have
    if category:
        owner.execute("INSERT INTO account_age_categories (user_id, category) VALUES (%s, %s)", (uid, category))
    return ids


def ticket(owner: Any, a: dict[str, str], kind: str, *, checked: bool, state: str = "finalized", source: bool = True,
           thumb: bool = True) -> dict[str, str]:
    base = f"{a['user']}/{a['property']}/{'move-in/' + a['room'] if kind == 'evidence' else 'lease'}/{uuid.uuid4().hex}"
    keys = {"object": f"{base}.jpg", "thumb": f"{base}_thumb.jpg", "source": f"{base}_source.jpg" if source else None}
    owner.execute(
        """INSERT INTO storage_upload_tickets (id, user_id, property_id, kind, bucket, object_key, thumbnail_key, resource_id,
               expires_at, state, source_key, source_mime_type, source_byte_size, source_sha256, source_width, source_height,
               capture_source, thumbnail_present, finalized_at, metadata_checked)
           VALUES (gen_random_uuid(), %s, %s, %s, 'b', %s, %s, %s, now() + interval '1 hour', %s, %s, %s, %s, %s, %s, %s, %s, %s,
                   now(), %s)""",
        (a["user"], a["property"], kind, keys["object"], keys["thumb"], a["room"] if kind == "evidence" else None, state,
         keys["source"], "image/jpeg" if source else None, 100 if source else None, "a" * 64 if source else None,
         10 if source else None, 10 if source else None, "library" if source else None, thumb, checked))
    return keys


def insert_evidence(dsn: str, a: dict[str, str], keys: dict[str, str] | None) -> None:
    with as_user(dsn, a["user"]) as c:
        if keys is None:  # legacy: derivative only, no source
            base = f"{a['user']}/{a['property']}/move-in/{a['room']}/{uuid.uuid4().hex}"
            c.execute("""INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type)
                         VALUES (%s, %s, %s, 'image')""", (a["property"], a["item"], f"{base}.jpg"))
        else:
            c.execute("""INSERT INTO evidence_files (property_id, inspection_item_id, file_path, file_type, thumbnail_path, source_path)
                         VALUES (%s, %s, %s, 'image', %s, %s)""", (a["property"], a["item"], keys["object"], keys["thumb"], keys["source"]))
        c.commit()


def insert_document(dsn: str, a: dict[str, str], path: str, thumb: str | None) -> None:
    with as_user(dsn, a["user"]) as c:
        c.execute("""INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name, thumbnail_path)
                     VALUES (%s, %s, 'lease', %s, 'lease.jpg', %s)""", (a["property"], a["user"], path, thumb))
        c.commit()


# --- evidence --------------------------------------------------------------------------------

def test_teen_legacy_evidence_without_a_source_is_refused(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    with pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):
        insert_evidence(dsn, teen, None)


def test_teen_evidence_from_an_unchecked_ticket_is_refused(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    with pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):
        insert_evidence(dsn, teen, ticket(owner, teen, "evidence", checked=False))


def test_teen_evidence_from_a_checked_ticket_is_accepted(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    keys = ticket(owner, teen, "evidence", checked=True)
    insert_evidence(dsn, teen, keys)
    assert one(owner, "SELECT state FROM storage_upload_tickets WHERE source_key = %s", (keys["source"],))[0] == "consumed"


@pytest.mark.parametrize("category", ["adult", None])
def test_adults_and_undeclared_accounts_are_unchanged(dsn: str, owner: Any, category: str | None) -> None:
    a = account(owner, dsn, category)
    insert_evidence(dsn, a, None)
    insert_evidence(dsn, a, ticket(owner, a, "evidence", checked=False))


def test_teen_cannot_swap_an_evidence_file(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")  # seed_rental's legacy row predates the declaration
    with as_user(dsn, teen["user"]) as c, pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):
        c.execute("UPDATE evidence_files SET file_path = file_path || '.x' WHERE id = %s", (teen["evidence"],))


# --- documents --------------------------------------------------------------------------------

def test_teen_document_without_a_ticket_is_refused(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    with pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):
        insert_document(dsn, teen, f"{teen['user']}/{teen['property']}/lease/raw.jpg", None)


@pytest.mark.parametrize("problem", ["unchecked", "issued", "thumbnail_mismatch"])
def test_teen_document_from_a_bad_ticket_is_refused(dsn: str, owner: Any, problem: str) -> None:
    teen = account(owner, dsn, "teen")
    keys = ticket(owner, teen, "document", checked=problem != "unchecked", state="issued" if problem == "issued" else "finalized",
                  source=False)
    with pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):
        insert_document(dsn, teen, keys["object"], None if problem == "thumbnail_mismatch" else keys["thumb"])


def test_teen_document_from_a_checked_ticket_is_accepted_once(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    keys = ticket(owner, teen, "document", checked=True, source=False)
    insert_document(dsn, teen, keys["object"], keys["thumb"])
    assert one(owner, "SELECT state FROM storage_upload_tickets WHERE object_key = %s", (keys["object"],))[0] == "consumed"
    with pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):  # a consumed ticket can't be reused
        insert_document(dsn, teen, keys["object"], keys["thumb"])


def test_teen_cannot_repoint_a_document(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    with as_user(dsn, teen["user"]) as c, pytest.raises(errors.InsufficientPrivilege, match="TEEN_UPLOAD_PRIVACY"):
        c.execute("UPDATE property_documents SET file_path = file_path || '.x' WHERE id = %s", (teen["document"],))


def test_adult_documents_are_unchanged(dsn: str, owner: Any) -> None:
    a = account(owner, dsn, "adult")
    insert_document(dsn, a, f"{a['user']}/{a['property']}/lease/raw.jpg", None)


def test_the_trusted_backend_is_not_restricted(dsn: str, owner: Any) -> None:
    teen = account(owner, dsn, "teen")
    owner.execute("""INSERT INTO property_documents (property_id, user_id, document_type, file_path, file_name)
                     VALUES (%s, %s, 'lease', %s, 'x.pdf')""", (teen["property"], teen["user"], f"{teen['user']}/{teen['property']}/lease/b.pdf"))
