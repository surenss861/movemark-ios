"""Migration runner guards (neon/migrate.py), against throwaway local databases — never Neon.

    movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests/test_migrate.py -q
"""

from __future__ import annotations

import argparse
import importlib.util
import pathlib
import shutil
import uuid
from typing import Any, Iterator

import pytest

psycopg = pytest.importorskip("psycopg")

NEON = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("migrate", NEON / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)


@pytest.fixture
def migrations(tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch) -> pathlib.Path:
    """A copy of the real migration folder the runner reads instead of the repository's."""
    folder = tmp_path / "migrations"
    shutil.copytree(NEON / "migrations", folder)
    monkeypatch.setattr(migrate, "MIGRATIONS", folder)
    monkeypatch.setattr(migrate, "runner_commit", lambda: "0" * 40)  # git cleanliness is tested separately
    return folder


@pytest.fixture
def target() -> Iterator[Any]:
    """An empty local database standing in for a branch."""
    name = f"mm_migrate_target_{uuid.uuid4().hex[:8]}"
    with psycopg.connect(migrate.LOCAL_ADMIN, autocommit=True) as admin:
        admin.execute(f'CREATE DATABASE "{name}"')
    dsn = migrate.LOCAL_ADMIN.rsplit("/", 1)[0] + "/" + name
    with psycopg.connect(dsn, autocommit=True) as conn:
        conn.execute(migrate.SHIM.read_text())  # the platform objects Neon provides
        yield conn
    with psycopg.connect(migrate.LOCAL_ADMIN, autocommit=True) as admin:
        admin.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


def test_apply_from_zero_then_nothing_pending_and_no_drift(migrations: pathlib.Path, target: Any, capsys: Any) -> None:
    assert migrate.cmd_apply(target) == 0
    assert migrate.cmd_status(target) == 0
    out = capsys.readouterr().out
    assert "0 pending" in out and "PENDING" not in out.split("command")[-1].split("\n\n")[0]
    rows = target.execute("SELECT count(*), count(DISTINCT runner_commit), min(method) FROM movemark_meta.schema_migrations").fetchone()
    assert rows == (len(list(migrations.glob("*.sql"))), 1, "runner")
    assert migrate.cmd_check(target) == 0  # target matches the from-zero build


def test_changed_applied_migration_is_a_checksum_mismatch(migrations: pathlib.Path, target: Any, capsys: Any) -> None:
    migrate.cmd_apply(target)
    victim = sorted(migrations.glob("*.sql"))[5]
    victim.write_text(victim.read_text() + "\n-- edited after it was applied\n")
    capsys.readouterr()
    assert migrate.cmd_status(target) == 1
    assert f"CHECKSUM MISMATCH {victim.name}" in capsys.readouterr().out
    assert migrate.cmd_apply(target) == 1  # and nothing is applied on top of it


def test_out_of_order_and_missing_are_refused(migrations: pathlib.Path, target: Any, capsys: Any) -> None:
    migrate.cmd_apply(target)
    (migrations / "0005_late_arrival.sql").write_text("SELECT 1;\n")
    capsys.readouterr()
    assert migrate.cmd_status(target) == 1
    assert "OUT-OF-ORDER      0005_late_arrival.sql" in capsys.readouterr().out
    (migrations / "0005_late_arrival.sql").unlink()
    gone = sorted(migrations.glob("*.sql"))[-1]
    gone.unlink()
    assert migrate.cmd_status(target) == 1
    assert f"MISSING           {gone.name}" in capsys.readouterr().out


def test_unexpected_files_are_refused(migrations: pathlib.Path) -> None:
    (migrations / "fixup.sql").write_text("SELECT 1;\n")
    with pytest.raises(migrate.RefusedError, match="unexpected file"):
        migrate.migration_files()


def test_new_pending_migration_applies_with_upgrade_path_check(migrations: pathlib.Path, target: Any) -> None:
    migrate.cmd_apply(target)
    (migrations / "9990_add_probe_column.sql").write_text("ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS probe text;\n")
    assert migrate.cmd_apply(target) == 0
    assert target.execute("SELECT version FROM movemark_meta.schema_migrations ORDER BY version DESC LIMIT 1").fetchone()[0] == "9990"


def test_baseline_records_without_running_and_refuses_drift(migrations: pathlib.Path, target: Any, capsys: Any) -> None:
    # Build the schema by hand (as production was), outside the ledger.
    for path in sorted(migrations.glob("*.sql")):
        target.execute(path.read_text())
    newest = sorted(migrations.glob("*.sql"))[-1].name[:4]
    target.execute("ALTER TABLE public.rooms ADD COLUMN drifted text")  # a change no migration made
    assert migrate.cmd_baseline(target, newest) == 1
    assert "only in target" in capsys.readouterr().out
    assert target.execute("SELECT to_regclass('movemark_meta.schema_migrations')").fetchone()[0] is None
    target.execute("ALTER TABLE public.rooms DROP COLUMN drifted")
    # Baseline must not execute the files: a statement that would fail if re-run proves it.
    probe = migrations / "0001_reconstructed_base_schema.sql"
    assert migrate.cmd_baseline(target, newest) == 0
    assert target.execute("SELECT count(*), min(method) FROM movemark_meta.schema_migrations").fetchone() == (len(list(migrations.glob('*.sql'))), "baseline")
    assert probe.exists()
    with pytest.raises(migrate.RefusedError, match="empty ledger"):
        migrate.cmd_baseline(target, newest)
    assert migrate.cmd_status(target) == 0


def test_production_guard() -> None:
    def args(**kw: Any) -> argparse.Namespace:
        return argparse.Namespace(project="p", branch=kw.get("branch", "production"), production=kw.get("production", False), confirm=kw.get("confirm", ""))
    with pytest.raises(migrate.RefusedError, match="pass --production"):
        migrate.check_target(args())
    with pytest.raises(migrate.RefusedError, match="requires --confirm"):
        migrate.check_target(args(production=True, confirm="br-wrong"))
    with pytest.raises(migrate.RefusedError, match="non-production"):
        migrate.check_target(args(branch="dev", production=True))


def test_writes_require_committed_runner_and_migrations(monkeypatch: pytest.MonkeyPatch, tmp_path: pathlib.Path) -> None:
    class Proc:
        def __init__(self, out: str) -> None:
            self.stdout = out
    monkeypatch.setattr(migrate.subprocess, "run", lambda cmd, **k: Proc(" M neon/migrations/0940_x.sql" if "status" in cmd else "a" * 40))
    with pytest.raises(migrate.RefusedError, match="uncommitted"):
        migrate.runner_commit()
    monkeypatch.setattr(migrate.subprocess, "run", lambda cmd, **k: Proc("" if "status" in cmd else "b" * 40))
    assert migrate.runner_commit() == "b" * 40


def test_out_of_band_changes_block_apply_even_with_pending_migrations(migrations: pathlib.Path, target: Any, capsys: Any) -> None:
    # Production 2026-10-22: migrations were executed outside the runner while later ones were pending; check
    # only compared the live schema when nothing was pending, so apply went ahead. Now it must refuse.
    files = sorted(migrations.glob("*.sql"))
    for path in files[:-1]:
        target.execute(path.read_text())
    newest_applied = files[-2].name[:4]
    assert migrate.cmd_baseline(target, newest_applied) == 0
    (migrations / "9990_pending.sql").write_text("CREATE INDEX IF NOT EXISTS pending_probe ON public.rooms (name);\n")
    target.execute("CREATE POLICY out_of_band ON public.rooms FOR SELECT TO anonymous USING (false)")  # not in any migration
    capsys.readouterr()
    assert migrate.cmd_check(target) == 1
    assert "drifts from its ledger" in capsys.readouterr().out
    assert migrate.cmd_apply(target) == 1
    assert target.execute("SELECT count(*) FROM movemark_meta.schema_migrations WHERE version = '9990'").fetchone()[0] == 0
