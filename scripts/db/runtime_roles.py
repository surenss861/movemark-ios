"""MoveMark — set the runtime roles' passwords on a Neon branch and write their DSNs (0960 roles; 1010 backup).

    ../movemark-api-py/.venv/bin/python scripts/db/runtime_roles.py --project shiny-poetry-92207621 --branch dev
    ... --branch production --production --confirm br-solitary-glade-b5nc31al   (at the Railway cutover only)

Generates a random password per role and sets it with ALTER ROLE over the owner's TLS connection — the
only way Neon accepts for roles created in SQL (its control plane intercepts the statement and takes only
plaintext; its reset-password API refuses roles that never had a password). Writes `<role>.dsn` (pooled
endpoint, mode 0600) to ~/.movemark-qa/<branch>/; the password is never printed. Those DSNs are what the API (`movemark_api`) and worker (`movemark_worker`) use
as DATABASE_URL; the owner credential stays with neon/migrate.py. Rerunning rotates both passwords.
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import pathlib
import secrets
import sys
from urllib.parse import quote, urlsplit, urlunsplit

import psycopg
from psycopg import sql

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("migrate", ROOT / "neon" / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)

ROLES = ("movemark_api", "movemark_worker")
# The scheduled backup's role (1010) gets the direct endpoint: pg_dump needs a session, not PgBouncer's
# transaction pooling. Only `--roles movemark_backup` touches it; its DSN goes to the backup service alone.
DIRECT_ROLES = ("movemark_backup",)


def pooled(owner_dsn: str, role: str, password: str) -> str:
    parts = urlsplit(owner_dsn)
    host = parts.hostname or ""
    if "-pooler" not in host:
        endpoint, rest = host.split(".", 1)
        host = f"{endpoint}-pooler.{rest}"
    netloc = f"{quote(role)}:{quote(password)}@{host}" + (f":{parts.port}" if parts.port else "")
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def direct(owner_dsn: str, role: str, password: str) -> str:
    parts = urlsplit(owner_dsn)
    netloc = f"{quote(role)}:{quote(password)}@{parts.hostname}" + (f":{parts.port}" if parts.port else "")
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--production", action="store_true")
    ap.add_argument("--confirm", default="")
    ap.add_argument("--roles", default=",".join(ROLES), help=f"comma-separated, from {ROLES + DIRECT_ROLES}")
    args = ap.parse_args()
    roles = [r for r in args.roles.split(",") if r]
    if not roles or any(r not in ROLES + DIRECT_ROLES for r in roles):
        sys.exit(f"--roles must name roles from {ROLES + DIRECT_ROLES}")
    try:
        migrate.check_target(args)
    except migrate.RefusedError as error:
        sys.exit(f"refused: {error}")
    out = pathlib.Path.home() / ".movemark-qa" / args.branch
    out.mkdir(mode=0o700, parents=True, exist_ok=True)
    owner_dsn = migrate.neon_dsn(args.project, args.branch)
    with psycopg.connect(owner_dsn, autocommit=True) as conn:
        for role in roles:
            if not conn.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (role,)).fetchone():
                sys.exit(f"{role} does not exist on {args.branch}: apply its migration (0960 / 1010) first")
            password = secrets.token_urlsafe(32)
            conn.execute(sql.SQL("ALTER ROLE {} PASSWORD {}").format(sql.Identifier(role), sql.Literal(password)))
            target = out / f"{role}.dsn"
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as fh:
                fh.write((direct if role in DIRECT_ROLES else pooled)(owner_dsn, role, password) + "\n")
            print(f"{role}: password rotated, DSN written to {target}")
    for role in roles:  # prove each credential works and is what it should be
        with psycopg.connect((out / f"{role}.dsn").read_text().strip()) as conn:
            who, tz, timeout, ro = conn.execute("SELECT current_user, current_setting('TimeZone'), "
                                                "current_setting('statement_timeout'), current_setting('transaction_read_only')").fetchone()
            can_create = conn.execute("SELECT has_schema_privilege('public', 'CREATE')").fetchone()[0]
            print(f"  connected as {who} ({'direct' if role in DIRECT_ROLES else 'pooled'}) timezone={tz} "
                  f"statement_timeout={timeout} read_only={ro} can_create_in_public={can_create}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
