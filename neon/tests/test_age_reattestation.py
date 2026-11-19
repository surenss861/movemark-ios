"""1062 (prepared, not applied): asking again after the iOS 1.4 age-band defect, without reclassifying anyone.

Local Postgres only (same harness as test_legal_status_identity.py):

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_age_reattestation.py -q

The database is built through 1061, accounts are seeded as the 1.4 defect left them, then 1062 is applied:
  a '13_17' range acceptance        -> asked again (acceptance_required), category still 'teen' until answered
  an '18_plus' acceptance           -> not asked again
  answering again '18_plus'         -> band 18_plus, category adult, flag cleared, not asked again
  answering again '13_17'           -> band 13_17, category teen (unchanged), flag cleared, not asked again
  an acceptance made after 1062     -> never flagged
  rentals, rooms and evidence rows  -> untouched by 1062 and by answering again
Rollback: the 1057 bodies come back and the column goes.
"""
from __future__ import annotations

import os
import pathlib
import uuid
from typing import Any, Iterator

import pytest

psycopg = pytest.importorskip("psycopg")

from test_reconstruction import as_user, one, seed_rental  # noqa: E402

NEON = pathlib.Path(__file__).resolve().parents[1]
ADMIN_DSN = os.getenv("MOVEMARK_TEST_ADMIN_DSN", "postgresql:///postgres")
DB = "movemark_neon_age_reattest_1062"
MIGRATION = NEON / "migrations" / "1062_age_reattestation.sql"
ROLLBACK = NEON / "rollback" / "1062_age_reattestation.down.sql"


def migrations_before_1062() -> list[pathlib.Path]:
    return [p for p in sorted((NEON / "migrations").glob("*.sql")) if p.name[:4] < "1062"]


def new_user(owner: Any) -> str:
    uid = str(uuid.uuid4())
    owner.execute('INSERT INTO neon_auth."user" (id, email) VALUES (%s, %s)', (uid, f"{uid[:8]}@qa.test"))
    return uid


def docs(owner: Any) -> dict[str, str]:
    return dict(owner.execute("SELECT kind, version FROM legal_documents WHERE active").fetchall())


def accept(dsn: str, owner: Any, user: str, band: str) -> None:
    d = docs(owner)
    with as_user(dsn, user) as c:
        c.execute("SELECT accept_legal_documents('email', %s, %s, 'bands_v2', %s, false)",
                  (d["terms"], d["privacy_notice"], band))
        c.commit()


def status(dsn: str, user: str) -> dict[str, Any]:
    with as_user(dsn, user) as c:
        return one(c, "SELECT get_legal_status()")[0]


def category(owner: Any, user: str) -> str | None:
    row = owner.execute("SELECT category FROM account_age_categories WHERE user_id = %s", (user,)).fetchone()
    return row[0] if row else None


def counts(owner: Any, user: str) -> tuple[int, int, int]:
    return owner.execute(
        "SELECT (SELECT count(*) FROM properties WHERE user_id = %s),"
        "       (SELECT count(*) FROM rooms r JOIN properties p ON p.id = r.property_id WHERE p.user_id = %s),"
        "       (SELECT count(*) FROM evidence_files e JOIN properties p ON p.id = e.property_id WHERE p.user_id = %s)",
        (user, user, user)).fetchone()


@pytest.fixture(scope="module")
def world() -> Iterator[dict[str, Any]]:
    try:
        admin = psycopg.connect(ADMIN_DSN, autocommit=True, connect_timeout=3)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"no local Postgres: {e}")
    with admin, admin.cursor() as cur:
        cur.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')
        cur.execute(f'CREATE DATABASE "{DB}"')
    dsn = f"postgresql:///{DB}"
    owner = psycopg.connect(dsn, autocommit=True)
    owner.execute((NEON / "tests" / "neon_platform_shim.sql").read_text())
    for f in migrations_before_1062():
        owner.execute(f.read_text())
    # As 1.4 left them: the corrupted adult and the real teen are indistinguishable ('13_17' both).
    w: dict[str, Any] = {"dsn": dsn, "owner": owner}
    w["with_rental"] = new_user(owner)
    seed_rental(dsn, w["with_rental"])  # evidence first: the account had photos before it answered on 1.4
    for name, band in (("corrupted_adult", "13_17"), ("real_teen", "13_17"), ("adult", "18_plus"), ("with_rental", "13_17")):
        w.setdefault(name, new_user(owner))
        accept(dsn, owner, w[name], band)
    w["rental_before"] = counts(owner, w["with_rental"])
    owner.execute(MIGRATION.read_text())
    yield w
    owner.close()
    with psycopg.connect(ADMIN_DSN, autocommit=True) as admin2:
        admin2.execute(f'DROP DATABASE IF EXISTS "{DB}" WITH (FORCE)')


def test_a_13_17_range_acceptance_is_asked_again_without_reclassification(world: dict[str, Any]) -> None:
    for name in ("corrupted_adult", "real_teen", "with_rental"):
        s = status(world["dsn"], world[name])
        assert s["acceptance_required"] is True, name
        assert s["accepted"]["age_reattest_required"] is True
        assert category(world["owner"], world[name]) == "teen"  # strict until the person answers


def test_an_18_plus_acceptance_is_not_asked_again(world: dict[str, Any]) -> None:
    s = status(world["dsn"], world["adult"])
    assert s["acceptance_required"] is False and s["accepted"]["age_reattest_required"] is False
    assert category(world["owner"], world["adult"]) == "adult"


def test_answering_18_plus_again_makes_the_account_adult_by_its_own_answer(world: dict[str, Any]) -> None:
    u = world["corrupted_adult"]
    accept(world["dsn"], world["owner"], u, "18_plus")
    s = status(world["dsn"], u)
    assert s["acceptance_required"] is False
    assert s["accepted"]["age_band"] == "18_plus" and s["accepted"]["age_reattest_required"] is False
    assert category(world["owner"], u) == "adult"


def test_answering_13_17_again_keeps_teen_and_clears_the_question(world: dict[str, Any]) -> None:
    u = world["real_teen"]
    accept(world["dsn"], world["owner"], u, "13_17")
    s = status(world["dsn"], u)
    assert s["acceptance_required"] is False
    assert s["accepted"]["age_band"] == "13_17" and s["accepted"]["age_reattest_required"] is False
    assert category(world["owner"], u) == "teen"


def test_an_acceptance_after_1062_is_never_flagged(world: dict[str, Any]) -> None:
    u = new_user(world["owner"])
    accept(world["dsn"], world["owner"], u, "13_17")
    s = status(world["dsn"], u)
    assert s["acceptance_required"] is False and s["accepted"]["age_reattest_required"] is False


def test_rentals_and_evidence_are_untouched(world: dict[str, Any]) -> None:
    u = world["with_rental"]
    assert counts(world["owner"], u) == world["rental_before"]
    accept(world["dsn"], world["owner"], u, "18_plus")
    assert counts(world["owner"], u) == world["rental_before"]
    assert world["rental_before"][0] >= 1


def test_rollback_restores_1057_and_drops_the_column(world: dict[str, Any]) -> None:
    owner = world["owner"]
    owner.execute(ROLLBACK.read_text())
    assert owner.execute("SELECT count(*) FROM information_schema.columns WHERE table_name = 'legal_acceptances' "
                         "AND column_name = 'age_reattest_required'").fetchone()[0] == 0
    s = status(world["dsn"], world["adult"])
    assert "age_reattest_required" not in s["accepted"]
    owner.execute(MIGRATION.read_text())  # forward again cleanly
