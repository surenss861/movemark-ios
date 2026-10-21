"""Generate the Neon versions of the tracked Supabase migrations.

The originals in movemork/supabase/migrations are never edited. Each output file
records its source file and SHA-256 and lists exactly which substitutions were
applied, so the port is reviewable and reproducible:

    python3 neon/port_migrations.py        # (re)writes neon/migrations/0100_* ...

Substitutions (behaviour-preserving):
  auth.uid()          -> (auth.user_id())::uuid     Neon Data API helper; Neon Auth ids are UUIDs
  auth.users          -> neon_auth."user"           Managed Better Auth users table
  service_role        -> movemark_backend           trusted-backend role (0000)
Superseded (not ported; replacement noted in README):
  *_remote_baseline   placeholders                  -> 0001_reconstructed_base_schema.sql
  storage bucket/policy migrations                  -> Neon Object Storage + API-issued presigned URLs
  supabase_realtime publication block               -> clients' existing polling
  *.sql.txt (never applied in production)
"""
from __future__ import annotations

import hashlib
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT.parent / "supabase" / "migrations"
OUT = ROOT / "migrations"

SUPERSEDED = {
    "20260329000001_storage_buckets_and_policies.sql": "Supabase Storage policies; Neon Object Storage access is via API-issued presigned URLs",
    "20260329100000_storage_policies_uuid_case_insensitive.sql": "repair of the Supabase Storage policies above",
}

# The whole "Realtime on exports" section (its header comment claims Realtime replaces polling;
# on Neon it doesn't exist) becomes one accurate line.
REALTIME_BLOCK = re.compile(
    r"-- -+\n-- 3\. Realtime on exports.*?\$exports_realtime\$;\s*", re.S
)


def port(sql: str) -> tuple[str, list[str]]:
    applied: list[str] = []
    new, n = REALTIME_BLOCK.subn(
        "-- 3. [neon] Supabase-only Realtime on exports — not ported. There is no supabase_realtime\n"
        "-- publication on Neon; clients poll export status (iOS since S7; Android's Realtime watcher is replaced in S8).\n",
        sql,
    )
    if n:
        applied.append(f"removed supabase_realtime publication block x{n}")
    for pattern, repl, label in [
        (r"auth\.uid\(\)", "(auth.user_id())::uuid", "auth.uid() -> (auth.user_id())::uuid"),
        (r"\bauth\.users\b", 'neon_auth."user"', 'auth.users -> neon_auth."user"'),
        (r"\bservice_role\b", "movemark_backend", "service_role -> movemark_backend"),
    ]:
        new, n = re.subn(pattern, repl, new)
        if n:
            applied.append(f"{label} x{n}")
    return new, applied


def main() -> None:
    for old in OUT.glob("01*_*.sql"):
        old.unlink()
    seq = 100
    for src in sorted(SRC.glob("*.sql")):
        name = src.name
        if name.endswith("_remote_baseline.sql"):
            continue
        sql = src.read_text()
        digest = hashlib.sha256(sql.encode()).hexdigest()[:16]
        if name in SUPERSEDED:
            body, applied = f"-- superseded: {SUPERSEDED[name]}\nSELECT 1;\n", ["not ported (superseded)"]
        else:
            body, applied = port(sql)
        header = (
            f"-- PORTED for Neon by neon/port_migrations.py — do not edit by hand.\n"
            f"-- source: supabase/migrations/{name} (sha256 {digest})\n"
            + "".join(f"-- change: {a}\n" for a in (applied or ["none (verbatim)"]))
            + "\n"
        )
        (OUT / f"{seq:04d}_{name}").write_text(header + body)
        seq += 10
    print(f"ported {len(list(OUT.glob('01*_*.sql')) + list(OUT.glob('02*_*.sql')) + list(OUT.glob('03*_*.sql')))} files")


if __name__ == "__main__":
    main()
