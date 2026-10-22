"""MoveMark — set the runtime roles' passwords on a Neon branch and write their pooled DSNs (0960 roles).

    ../movemark-api-py/.venv/bin/python scripts/db/runtime_roles.py --project shiny-poetry-92207621 --branch dev
    ... --branch production --production --confirm br-solitary-glade-b5nc31al   (at the Railway cutover only)

Generates a fresh random password per role, sends Postgres only its SCRAM-SHA-256 verifier (the plaintext
never reaches the server or its logs), and writes `<role>.dsn` (pooled endpoint, mode 0600) to
~/.movemark-qa/<branch>/. Those DSNs are what the API (`movemark_api`) and worker (`movemark_worker`) use
as DATABASE_URL; the owner credential stays with neon/migrate.py. Rerunning rotates both passwords.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import importlib.util
import os
import pathlib
import secrets
import sys
from urllib.parse import quote, urlsplit, urlunsplit

import psycopg

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("migrate", ROOT / "neon" / "migrate.py")
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)

ROLES = ("movemark_api", "movemark_worker")


def scram_verifier(password: str, iterations: int = 4096) -> str:
    salt = secrets.token_bytes(16)
    salted = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, iterations)
    client_key = hmac.new(salted, b"Client Key", hashlib.sha256).digest()
    server_key = hmac.new(salted, b"Server Key", hashlib.sha256).digest()
    b64 = lambda b: base64.b64encode(b).decode()  # noqa: E731
    return f"SCRAM-SHA-256${iterations}:{b64(salt)}${b64(hashlib.sha256(client_key).digest())}:{b64(server_key)}"


def pooled(owner_dsn: str, role: str, password: str) -> str:
    parts = urlsplit(owner_dsn)
    host = parts.hostname or ""
    if "-pooler" not in host:
        endpoint, rest = host.split(".", 1)
        host = f"{endpoint}-pooler.{rest}"
    netloc = f"{quote(role)}:{quote(password)}@{host}" + (f":{parts.port}" if parts.port else "")
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--production", action="store_true")
    ap.add_argument("--confirm", default="")
    args = ap.parse_args()
    try:
        migrate.check_target(args)
    except migrate.RefusedError as error:
        sys.exit(f"refused: {error}")
    out = pathlib.Path.home() / ".movemark-qa" / args.branch
    out.mkdir(mode=0o700, parents=True, exist_ok=True)
    owner_dsn = migrate.neon_dsn(args.project, args.branch)
    with psycopg.connect(owner_dsn, autocommit=True) as conn:
        for role in ROLES:
            if not conn.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (role,)).fetchone():
                sys.exit(f"{role} does not exist on {args.branch}: apply migration 0960 first")
            password = secrets.token_urlsafe(32)
            conn.execute(f"ALTER ROLE {role} PASSWORD '{scram_verifier(password)}'")
            target = out / f"{role}.dsn"
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as fh:
                fh.write(pooled(owner_dsn, role, password) + "\n")
            print(f"{role}: password rotated, DSN written to {target}")
    for role in ROLES:  # prove each credential works through the pooler and is what it should be
        with psycopg.connect((out / f"{role}.dsn").read_text().strip()) as conn:
            who, tz, timeout = conn.execute("SELECT current_user, current_setting('TimeZone'), current_setting('statement_timeout')").fetchone()
            can_create = conn.execute("SELECT has_schema_privilege('public', 'CREATE')").fetchone()[0]
            print(f"  connected as {who} (pooled) timezone={tz} statement_timeout={timeout} can_create_in_public={can_create}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
