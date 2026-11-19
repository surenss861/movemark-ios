"""A simulated pair of B2 buckets and a source store, driven through the real offsite.py code.

    ../movemark-api-py/.venv/bin/python -m pytest scripts/dr/tests -q
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import secrets
import sys
import types
from typing import Any

import pytest

HERE = pathlib.Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent)]

import deletion_log  # noqa: E402
import retention  # noqa: E402
from fake_b2 import FakeB2  # noqa: E402

DB, EV, SRC = "db-bucket", "evidence-bucket", "inspection-media"
START = datetime.datetime(2026, 1, 1, 0, 17, tzinfo=datetime.UTC)


class World:
    """Real sync_evidence and push_db, a fake clock, a fake B2 with a 30-day lock, one source bucket."""

    def __init__(self, tmp: pathlib.Path, monkeypatch: pytest.MonkeyPatch) -> None:
        self.now = START
        self.tmp = tmp
        self.key = secrets.token_bytes(32)
        self.key_file = tmp / "backup.key"
        self.key_file.write_bytes(self.key)
        self.db = FakeB2(lambda: self.now, lock_days=30)
        self.ev = FakeB2(lambda: self.now, lock_days=30)
        self.source = FakeB2(lambda: self.now)
        self.policy = retention.Policy()
        for module in (retention.offsite, deletion_log.offsite):
            clock = types.SimpleNamespace(datetime=types.SimpleNamespace(now=lambda _tz: self.now), UTC=datetime.UTC)
            monkeypatch.setattr(module, "datetime", clock)
            monkeypatch.setattr(module, "boto3", types.SimpleNamespace(client=lambda *_a, **_k: self.source))
            monkeypatch.setattr(module, "b2", lambda which: (self.db, DB) if which == "DB" else (self.ev, EV))
        monkeypatch.setenv("AWS_ENDPOINT_URL_S3", "http://fake.invalid")

    # the outside world -------------------------------------------------------------
    def advance(self, days: float = 0, hours: float = 0) -> None:
        self.now += datetime.timedelta(days=days, hours=hours)

    def upload(self, key: str, body: bytes | None = None, bucket: str = SRC) -> bytes:
        body = secrets.token_bytes(64) if body is None else body
        self.source.put_object(Bucket=bucket, Key=key, Body=body)
        return body

    def remove(self, key: str, bucket: str = SRC) -> None:
        self.source.items = [i for i in self.source.items if not (i.bucket == bucket and i.key == key)]

    # the backup job ----------------------------------------------------------------
    def sync(self) -> None:
        retention.offsite.sync_evidence(argparse.Namespace(key_file=self.key_file, full=False))

    def push(self) -> str:
        stamp = self.now.strftime("%Y%m%dT%H%M%SZ")
        archive = self.tmp / f"movemark-production-{stamp}.mmbk"
        archive.write_bytes(secrets.token_bytes(32))
        archive.with_name(archive.name + ".sha256").write_text(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
        archive.with_suffix(".json").write_text(json.dumps({"created_utc": stamp}))
        retention.offsite.push_db(argparse.Namespace(archive=archive))
        return stamp

    def backup(self) -> None:
        self.push()
        self.sync()
        self.export()

    def export(self, rows: list[tuple] | None = None) -> None:
        deletion_log.export_batch(TombstoneConn(rows or []), self.db, DB, self.key, self.now)

    def lifecycle(self) -> None:
        """The rule set in docs/backup-retention-design.md."""
        self.db.run_lifecycle(DB, "db/", 35, 1)
        self.db.run_lifecycle(DB, "monthly/", 84, 1)
        self.ev.run_lifecycle(EV, "manifests/", 84, 1)
        self.ev.run_lifecycle(EV, "objects/", None, 85)

    def prune(self, apply: bool = True, allow_large: bool = True, policy: Any = None) -> tuple[int, dict]:
        return retention.run(self.db, DB, self.ev, EV, self.key, self.now, policy or self.policy, apply, allow_large)

    def seal_size(self, key: str) -> int:
        return len(self.ev.current(EV, f"objects/{SRC}/{key}").body)


class TombstoneConn:
    """Just enough of a connection for export_batch."""

    def __init__(self, rows: list[tuple]) -> None:
        self.rows = rows

    def execute(self, statement: str, params: Any = None) -> Any:
        if "to_regclass" in statement:
            return types.SimpleNamespace(fetchone=lambda: ("public.deletion_tombstones",))
        return types.SimpleNamespace(fetchall=lambda: [r for r in self.rows if r[2] >= params[0]])


@pytest.fixture
def world(tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch) -> World:
    return World(tmp_path, monkeypatch)
