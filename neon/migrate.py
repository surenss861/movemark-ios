#!/usr/bin/env python3
"""MoveMark migration runner — the only way schema changes reach a Neon branch.

    python neon/migrate.py --project shiny-poetry-92207621 --branch dev status
    python neon/migrate.py --project … --branch dev check         # from-zero + upgrade-path proof, no writes
    python neon/migrate.py --project … --branch dev apply
    python neon/migrate.py --project … --branch production --production --confirm br-solitary-glade-b5nc31al apply
    python neon/migrate.py --project … --branch production --production --confirm … baseline --through 0940

Rules it enforces:
  * Only `neon/migrations/NNNN_*.sql` are ever run. Nothing under `neon/tests/` (the local shim, gates)
    can be selected — the runner takes no file arguments.
  * Every applied migration is recorded in `movemark_meta.schema_migrations` with its SHA-256 and time.
    That schema is outside `public`, so the Data API never exposes it.
  * An applied migration whose file has since changed stops everything (migrations are immutable once
    applied). A pending migration numbered below the newest applied one is out of order and refused.
  * The target is explicit (project + branch). Production additionally needs `--production` and the
    branch id typed into `--confirm`.
  * Before applying, `check` proves (1) the full chain builds from zero, and (2) the target's applied
    prefix plus the pending files produces exactly the same schema as the from-zero build (upgrade
    path), comparing a catalog fingerprint. `apply` runs `check` first.
  * `baseline` records already-applied migrations WITHOUT running them — only into an empty ledger, and
    only after proving: the live schema's fingerprint equals a from-zero build of exactly those files,
    and every file is committed and unmodified in git (so the recorded checksums are the repository's).
  * Any write (apply/baseline) requires the runner and every migration file to be committed and
    unmodified; the ledger records the runner's git commit for each row.
  * `status` exits non-zero on CHECKSUM MISMATCH, OUT-OF-ORDER or MISSING, so CI can enforce it.

Connection strings come from the Neon CLI at run time (`neon connection-string …`); none are stored.
The local reference builds use MOVEMARK_TEST_ADMIN_DSN (default postgresql:///postgres).
"""

from __future__ import annotations

import argparse
import hashlib
import os
import pathlib
import re
import subprocess
import sys
import uuid
from contextlib import contextmanager
from typing import Iterator

import psycopg

NEON = pathlib.Path(__file__).resolve().parent
MIGRATIONS = NEON / "migrations"
SHIM = NEON / "tests" / "neon_platform_shim.sql"  # local reference builds only, never a Neon target
NAME = re.compile(r"^(\d{4})_[a-z0-9_]+\.sql$")
PRODUCTION_BRANCH_ID = "br-solitary-glade-b5nc31al"
LOCAL_ADMIN = os.getenv("MOVEMARK_TEST_ADMIN_DSN", "postgresql:///postgres")
LOCK_KEY = 0x6D6F76656D61726B  # "movemark": one runner per database at a time

LEDGER_DDL = """
CREATE SCHEMA IF NOT EXISTS movemark_meta;
REVOKE ALL ON SCHEMA movemark_meta FROM PUBLIC;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN EXECUTE 'REVOKE ALL ON SCHEMA movemark_meta FROM authenticated'; END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anonymous') THEN EXECUTE 'REVOKE ALL ON SCHEMA movemark_meta FROM anonymous'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS movemark_meta.schema_migrations (
  version     text PRIMARY KEY,
  filename    text NOT NULL UNIQUE,
  sha256      text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  applied_at  timestamptz NOT NULL DEFAULT now(),
  applied_by  text NOT NULL DEFAULT current_user,
  method      text NOT NULL CHECK (method IN ('runner', 'baseline'))
);
ALTER TABLE movemark_meta.schema_migrations ADD COLUMN IF NOT EXISTS runner_commit text;
"""

# One row per schema fact. Owners, OIDs and Neon-provided objects (auth, neon_auth) are left out so a
# local reference build and a Neon branch compare equal when — and only when — the MoveMark schema is.
FINGERPRINT_SQL = """
SELECT 'column', c.table_name || '.' || c.column_name,
       c.data_type || ' null=' || c.is_nullable || ' default=' || coalesce(c.column_default, '')
  FROM information_schema.columns c WHERE c.table_schema = 'public'
UNION ALL
SELECT 'constraint', cl.relname || '.' || co.conname, pg_get_constraintdef(co.oid)
  FROM pg_constraint co JOIN pg_class cl ON cl.oid = co.conrelid JOIN pg_namespace n ON n.oid = cl.relnamespace
 WHERE n.nspname = 'public' AND co.contype <> 'n'  -- PG18 names NOT NULLs; nullability is in the column facts
UNION ALL
SELECT 'index', indexname, indexdef FROM pg_indexes WHERE schemaname = 'public'
UNION ALL
SELECT 'rls', c.relname, c.relrowsecurity::text || ' force=' || c.relforcerowsecurity::text
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind = 'r'
UNION ALL
SELECT 'policy', tablename || '.' || policyname,
       permissive || ' ' || cmd || ' roles=' || array_to_string(roles, ',') || ' using=' || coalesce(qual, '') || ' check=' || coalesce(with_check, '')
  FROM pg_policies WHERE schemaname = 'public'
UNION ALL
SELECT 'function', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
       md5(p.prosrc) || ' definer=' || p.prosecdef::text || ' config=' || coalesce(array_to_string(p.proconfig, ','), '')
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public'
UNION ALL
SELECT 'trigger', c.relname || '.' || t.tgname, pg_get_triggerdef(t.oid)
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND NOT t.tgisinternal
UNION ALL
SELECT 'table_grant', table_name || ' ' || grantee, string_agg(privilege_type, ',' ORDER BY privilege_type)
  FROM information_schema.role_table_grants
 WHERE table_schema = 'public' AND grantee IN ('authenticated', 'anonymous', 'movemark_backend', 'PUBLIC')
 GROUP BY table_name, grantee
UNION ALL
SELECT 'routine_grant', routine_name || ' ' || grantee, string_agg(privilege_type, ',' ORDER BY privilege_type)
  FROM information_schema.role_routine_grants
 WHERE routine_schema = 'public' AND grantee IN ('authenticated', 'anonymous', 'movemark_backend', 'PUBLIC')
 GROUP BY routine_name, grantee
UNION ALL
SELECT 'role', rolname, 'exists' FROM pg_roles WHERE rolname = 'movemark_backend'
"""


class RefusedError(SystemExit):
    pass


def refuse(message: str) -> None:
    raise RefusedError(f"REFUSED: {message}")


# -- migration files ------------------------------------------------------------------

def migration_files() -> list[tuple[str, pathlib.Path, str]]:
    """(version, path, sha256) for every runnable migration, in order. Anything else in the folder is an error."""
    found = []
    for path in sorted(MIGRATIONS.iterdir()):
        if path.name.startswith(".") or path.is_dir():
            continue
        m = NAME.match(path.name)
        if not m:
            refuse(f"unexpected file in migrations/: {path.name} (expected NNNN_name.sql)")
        found.append((m.group(1), path, hashlib.sha256(path.read_bytes()).hexdigest()))
    versions = [v for v, _, _ in found]
    if len(set(versions)) != len(versions):
        refuse("two migrations share a version number")
    return found


def runner_commit() -> str:
    """The git commit this runner and the migrations come from; refuses if either is uncommitted."""
    repo = NEON.parent
    def git(*a: str) -> subprocess.CompletedProcess:
        return subprocess.run(["git", "-C", str(repo), *a], capture_output=True, text=True)
    dirty = git("status", "--porcelain", "--", "neon/migrate.py", "neon/migrations").stdout.strip()
    if dirty:
        refuse("the runner or migrations have uncommitted changes; commit them before writing to a database:\n" + dirty)
    sha = git("rev-parse", "HEAD").stdout.strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        refuse("could not determine the git commit")
    return sha


# -- targets --------------------------------------------------------------------------

def neon_dsn(project: str, branch: str) -> str:
    out = subprocess.run(
        ["neon", "connection-string", branch, "--project-id", project, "--role-name", "neondb_owner", "--database-name", "neondb"],
        capture_output=True, text=True,
    )
    dsn = out.stdout.strip()
    if out.returncode != 0 or not dsn.startswith("postgres"):
        refuse(f"could not resolve a connection string for {project}/{branch}: {out.stderr.strip()[:200]}")
    return dsn


def check_target(args: argparse.Namespace) -> str:
    is_production = args.branch in ("production", PRODUCTION_BRANCH_ID)
    if is_production:
        if not args.production:
            refuse("target is the production branch: pass --production")
        if args.confirm != PRODUCTION_BRANCH_ID:
            refuse(f"production requires --confirm {PRODUCTION_BRANCH_ID}")
    elif args.production:
        refuse("--production given for a non-production branch")
    dsn = neon_dsn(args.project, args.branch)
    if is_production != ("ep-steep-wind" in dsn):  # production's compute endpoint
        refuse("branch/endpoint mismatch: refusing to guess which database this is")
    return dsn


# -- ledger and fingerprints ----------------------------------------------------------

def ledger(conn: psycopg.Connection) -> dict[str, tuple[str, str]]:
    exists = conn.execute("SELECT to_regclass('movemark_meta.schema_migrations') IS NOT NULL").fetchone()[0]
    if not exists:
        return {}
    return {v: (f, s) for v, f, s in conn.execute("SELECT version, filename, sha256 FROM movemark_meta.schema_migrations")}


def fingerprint(conn: psycopg.Connection) -> set[tuple[str, str, str]]:
    return {tuple(r) for r in conn.execute(FINGERPRINT_SQL).fetchall()}


@contextmanager
def scratch_db(files: list[pathlib.Path]) -> Iterator[psycopg.Connection]:
    """A throwaway local database built from the shim + the given migrations."""
    name = f"mm_migrate_{uuid.uuid4().hex[:10]}"
    with psycopg.connect(LOCAL_ADMIN, autocommit=True) as admin:
        admin.execute(f'CREATE DATABASE "{name}"')
    try:
        dsn = LOCAL_ADMIN.rsplit("/", 1)[0] + "/" + name
        with psycopg.connect(dsn, autocommit=True) as conn:
            conn.execute(SHIM.read_text())
            for path in files:
                conn.execute(path.read_text())
            yield conn
    finally:
        with psycopg.connect(LOCAL_ADMIN, autocommit=True) as admin:
            admin.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


def diff(a: set, b: set, label_a: str, label_b: str) -> list[str]:
    lines = [f"  only in {label_a}: {r}" for r in sorted(a - b)] + [f"  only in {label_b}: {r}" for r in sorted(b - a)]
    return lines


# -- commands -------------------------------------------------------------------------

def plan(conn: psycopg.Connection) -> tuple[list, list]:
    files = migration_files()
    applied = ledger(conn)
    on_disk = {v for v, _, _ in files}
    problems = []
    for version, (filename, sha) in sorted(applied.items()):
        match = next((f for f in files if f[0] == version), None)
        if match is None:
            problems.append(f"applied {filename} is missing from neon/migrations")
        elif match[2] != sha:
            problems.append(f"applied {filename} has changed since it was applied (ledger {sha[:12]}…, file {match[2][:12]}…)")
        elif match[1].name != filename:
            problems.append(f"applied {filename} was renamed to {match[1].name}")
    pending = [f for f in files if f[0] not in applied]
    newest = max(applied, default="")
    late = [f[1].name for f in pending if f[0] < newest]
    if late:
        problems.append(f"out-of-order migrations (numbered below applied {newest}): {', '.join(late)}")
    _ = on_disk
    return pending, problems


def cmd_status(conn: psycopg.Connection) -> int:
    files = migration_files()
    applied = ledger(conn)
    pending, problems = plan(conn)
    newest = max(applied, default="")
    for version, path, sha in files:
        if version in applied:
            state = "APPLIED" if applied[version][1] == sha else "CHECKSUM MISMATCH"
        else:
            state = "OUT-OF-ORDER" if version < newest else "PENDING"
        print(f"  {state:<17} {path.name}")
    on_disk = {v for v, _, _ in files}
    for version, (filename, _) in sorted(applied.items()):
        if version not in on_disk:
            print(f"  {'MISSING':<17} {filename} (applied, not in the repository)")
    print(f"\n{len(applied)} applied, {len(pending)} pending" + ("" if applied else " (ledger empty)"))
    for p in problems:
        print(f"PROBLEM: {p}")
    return 1 if problems else 0


def cmd_check(conn: psycopg.Connection) -> int:
    files = migration_files()
    pending, problems = plan(conn)
    if problems:
        for p in problems:
            print(f"PROBLEM: {p}")
        return 1
    applied_paths = [p for v, p, _ in files if v not in {x[0] for x in pending}]
    # The live schema must equal a from-zero build of exactly the migrations its ledger records — checked
    # before anything pending is considered, so objects created outside the runner (SQL editor, another
    # tool) stop an apply instead of being silently built on.
    with scratch_db(applied_paths) as prefix:
        drift = diff(fingerprint(prefix), fingerprint(conn), "ledger build", "target")
    if drift:
        print("  target schema drifts from its ledger (changes made outside the runner):\n" + "\n".join(drift[:40]))
        return 1
    print(f"  target schema matches its ledger ({len(applied_paths)} migrations, no drift)")
    with scratch_db([p for _, p, _ in files]) as full:
        reference = fingerprint(full)
        print(f"  from-zero build of {len(files)} migrations: ok ({len(reference)} schema facts)")
        with scratch_db(applied_paths) as upgraded:
            for _, path, _ in pending:
                upgraded.execute(path.read_text())
            gaps = diff(reference, fingerprint(upgraded), "from-zero", "upgrade-path")
        if gaps:
            print("  upgrade path differs from the from-zero build:\n" + "\n".join(gaps[:40]))
            return 1
        print(f"  upgrade path ({len(applied_paths)} applied + {len(pending)} pending): identical to from-zero")
    return 0


def cmd_apply(conn: psycopg.Connection) -> int:
    if cmd_check(conn) != 0:
        print("check failed: nothing applied")
        return 1
    pending, _ = plan(conn)
    if not pending:
        print("nothing to apply")
        return 0
    commit = runner_commit()
    conn.execute(LEDGER_DDL)
    for version, path, sha in pending:
        with conn.transaction():
            conn.execute(path.read_text())
            conn.execute("INSERT INTO movemark_meta.schema_migrations (version, filename, sha256, method, runner_commit) "
                         "VALUES (%s, %s, %s, 'runner', %s)", (version, path.name, sha, commit))
        print(f"  applied {path.name}")
    return cmd_check(conn)


def cmd_baseline(conn: psycopg.Connection, through: str, dry_run: bool = False) -> int:
    if ledger(conn):
        refuse("baseline only initialises an empty ledger")
    files = [f for f in migration_files() if f[0] <= through]
    if not files or files[-1][0] != through:
        refuse(f"no migration numbered {through}")
    with scratch_db([p for _, p, _ in files]) as reference_db:
        reference = fingerprint(reference_db)
    drift = diff(reference, fingerprint(conn), f"from-zero through {through}", "target")
    if drift:
        print("REFUSED: the live schema does not match a from-zero build through " + through + ":\n" + "\n".join(drift[:60]))
        return 1
    if dry_run:
        print(f"dry run: live schema identical to a from-zero build through {through}; baseline would record {len(files)} migrations")
        return 0
    commit = runner_commit()  # recorded checksums must be the committed repository's
    conn.execute(LEDGER_DDL)
    with conn.transaction():
        for version, path, sha in files:
            conn.execute("INSERT INTO movemark_meta.schema_migrations (version, filename, sha256, method, runner_commit) "
                         "VALUES (%s, %s, %s, 'baseline', %s)", (version, path.name, sha, commit))
    print(f"baseline recorded: {len(files)} migrations through {through} (schema verified identical to a from-zero build)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", required=True)
    parser.add_argument("--branch", required=True, help="Neon branch name or id (dev, production, …)")
    parser.add_argument("--production", action="store_true")
    parser.add_argument("--confirm", default="")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    sub.add_parser("check")
    sub.add_parser("apply")
    b = sub.add_parser("baseline")
    b.add_argument("--through", required=True)
    b.add_argument("--dry-run", action="store_true", help="verify the schema matches; write nothing")
    args = parser.parse_args()

    dsn = check_target(args)
    with psycopg.connect(dsn, autocommit=True) as conn:
        conn.execute("SET application_name = 'movemark-migrate'")
        if not conn.execute("SELECT pg_try_advisory_lock(%s)", (LOCK_KEY,)).fetchone()[0]:
            refuse("another migration runner holds the lock on this database")
        print(f"target: {args.project}/{args.branch}  command: {args.command}")
        if args.command == "status":
            return cmd_status(conn)
        if args.command == "check":
            return cmd_check(conn)
        if args.command == "apply":
            return cmd_apply(conn)
        return cmd_baseline(conn, args.through, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
