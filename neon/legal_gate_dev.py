#!/usr/bin/env python3
"""Dev-only controls for the legal gate. Never production: production publishes documents and turns the gate
on through numbered migrations (docs/legal-gate/rollout-plan.md).

    python neon/legal_gate_dev.py --branch dev status
    python neon/legal_gate_dev.py --branch dev seed [--tag 2026-11-07]   # DRAFT documents, is_final = false
    python neon/legal_gate_dev.py --branch dev enforce on|off

`--branch` is dev or a child branch of dev. A seeded row is a draft marked non-final, its version starts with
`draft-`, and its hash covers the text in docs/legal at that moment. Seeding again with a new tag is how to
exercise "new version requires acceptance again".
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import pathlib
import sys

import psycopg

from migrate import PRODUCTION_BRANCH_ID, neon_dsn, refuse

PROJECT = "shiny-poetry-92207621"
PRODUCTION_ENDPOINT = "ep-steep-wind-b56266ss"
LEGAL = pathlib.Path(__file__).resolve().parent.parent / "docs" / "legal"
DOCUMENTS = {"terms": "terms-of-service.md", "privacy_notice": "privacy-policy.md"}


def connect(branch: str) -> psycopg.Connection:
    if branch in ("production", PRODUCTION_BRANCH_ID):
        refuse("this tool is dev-only")
    dsn = neon_dsn(PROJECT, branch)
    if PRODUCTION_ENDPOINT in dsn:
        refuse("branch resolved to the production endpoint")
    conn = psycopg.connect(dsn, autocommit=True)
    if conn.execute("SELECT current_setting('neon.endpoint_id', true)").fetchone()[0] == PRODUCTION_ENDPOINT:
        conn.close()
        refuse("connected to the production endpoint")
    return conn


def status(conn: psycopg.Connection) -> None:
    print("enforced:", conn.execute("SELECT enforced FROM public.legal_gate_settings").fetchone()[0])
    for row in conn.execute("SELECT kind, version, is_final, left(content_hash, 12) FROM public.legal_documents WHERE active ORDER BY kind"):
        print("active:", *row)
    print("acceptances:", conn.execute("SELECT count(*) FROM public.legal_acceptances").fetchone()[0])


def seed(conn: psycopg.Connection, tag: str) -> None:
    with conn.transaction():
        for kind, filename in DOCUMENTS.items():
            digest = hashlib.sha256((LEGAL / filename).read_bytes()).hexdigest()
            conn.execute("SELECT public.publish_legal_document(%s, %s, %s, NULL, false)", (kind, f"draft-{tag}", digest))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--branch", required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    s = sub.add_parser("seed")
    s.add_argument("--tag", default=datetime.date.today().isoformat())
    e = sub.add_parser("enforce")
    e.add_argument("state", choices=["on", "off"])
    args = parser.parse_args()

    with connect(args.branch) as conn:
        if args.command == "seed":
            seed(conn, args.tag)
        elif args.command == "enforce":
            conn.execute("UPDATE public.legal_gate_settings SET enforced = %s, updated_at = now()", (args.state == "on",))
        status(conn)
    return 0


if __name__ == "__main__":
    sys.exit(main())
