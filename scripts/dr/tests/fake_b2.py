"""An in-memory stand-in for the B2 S3-compatible API, as far as scripts/dr uses it. No network.

It encodes this repository's reading of Backblaze's documentation, listed in docs/backup-retention-design.md:
  - every bucket is versioned; a new upload to a name is a new version, and the old one stays;
  - a delete with a version id removes that version; a delete without one adds a hide marker and removes nothing;
  - uploads carry the bucket's default retention from upload time; a locked or held version can't be deleted,
    and a delete of one fails with AccessDenied unless a governance bypass is sent, which is recorded here so
    tests can prove it never is;
  - lifecycle rules run once a day, and a rule's deletion of a locked version does not happen.

Passing against this proves the code follows those rules. It does not prove B2 behaves this way.
"""
from __future__ import annotations

import dataclasses
import datetime
import hashlib
import io
import itertools
from typing import Callable

from botocore.exceptions import ClientError


def error(code: str, operation: str) -> ClientError:
    return ClientError({"Error": {"Code": code, "Message": code}}, operation)


@dataclasses.dataclass
class Item:
    bucket: str
    key: str
    id: str
    modified: datetime.datetime
    body: bytes = b""
    meta: dict = dataclasses.field(default_factory=dict)
    marker: bool = False
    retain_until: datetime.datetime | None = None
    hold: bool = False
    hidden_at: datetime.datetime | None = None


class Paginator:
    def __init__(self, fake: "FakeB2", name: str) -> None:
        self.fake, self.name = fake, name

    def paginate(self, Bucket: str, Prefix: str = ""):  # noqa: N803
        items = [i for i in self.fake.items if i.bucket == Bucket and i.key.startswith(Prefix)]
        items.sort(key=lambda i: (i.key, int(i.id)))
        self.latest = {i.key: i for i in items}  # sorted, so the last write per key wins
        size = self.fake.page_size
        if self.name == "list_objects_v2":
            items = [i for i in items if self.latest[i.key] is i and not i.marker]
            for start in range(0, len(items), size):
                yield {"Contents": [{"Key": i.key, "ETag": f'"{hashlib.md5(i.body).hexdigest()}"', "Size": len(i.body),  # noqa: S324
                                     "LastModified": i.modified} for i in items[start:start + size]]}
            return
        for start in range(0, len(items), size):
            page = items[start:start + size]
            yield {"Versions": [self._row(i) | {"Size": len(i.body)} for i in page if not i.marker],
                   "DeleteMarkers": [self._row(i) for i in page if i.marker]}

    def _row(self, item: Item) -> dict:
        return {"Key": item.key, "VersionId": item.id, "LastModified": item.modified,
                "IsLatest": self.latest[item.key] is item}


class FakeB2:
    def __init__(self, clock: Callable[[], datetime.datetime], lock_days: int = 0, page_size: int = 4) -> None:
        self.clock, self.lock_days, self.page_size = clock, lock_days, page_size
        self.items: list[Item] = []
        self.ids = itertools.count(1)
        self.deletes: list[dict] = []
        self.bypass_requests = 0
        self.refuse_retention_reads = False
        self.refuse_deletes = False
        self._index_mark: tuple = ()
        self._index: dict[tuple[str, str], list[Item]] = {}

    # helpers -----------------------------------------------------------------------
    def versions(self, bucket: str, key: str) -> list[Item]:
        mark = (id(self.items), len(self.items), self.items[-1].id if self.items else "")
        if mark != self._index_mark:  # tests also edit self.items directly
            self._index_mark, self._index = mark, {}
            for item in self.items:
                self._index.setdefault((item.bucket, item.key), []).append(item)
        return sorted(self._index.get((bucket, key), ()), key=lambda i: int(i.id))

    def current(self, bucket: str, key: str) -> Item | None:
        found = self.versions(bucket, key)
        return found[-1] if found else None

    def keys(self, bucket: str, prefix: str = "") -> set[str]:
        return {i.key for i in self.items if i.bucket == bucket and i.key.startswith(prefix)}

    def stored_bytes(self, bucket: str, prefix: str = "") -> int:
        return sum(len(i.body) for i in self.items if i.bucket == bucket and i.key.startswith(prefix))

    def run_lifecycle(self, bucket: str, prefix: str, hide_after: int | None, delete_after: int | None) -> None:
        """One daily pass of one rule."""
        now = self.clock()
        for item in [i for i in self.items if i.bucket == bucket and i.key.startswith(prefix)]:
            age = (now - item.modified).days
            if hide_after and not item.marker and self.current(bucket, item.key) is item and age >= hide_after:
                self.delete_object(Bucket=bucket, Key=item.key)
        for key in self.keys(bucket, prefix):
            found = self.versions(bucket, key)
            for older, newer in zip(found, found[1:]):
                older.hidden_at = older.hidden_at or newer.modified
            for item in found[:-1]:
                if delete_after and (now - item.hidden_at).days >= delete_after and not self._locked(item):
                    self.items.remove(item)

    def _locked(self, item: Item) -> bool:
        return item.hold or (item.retain_until is not None and item.retain_until > self.clock())

    def _find(self, bucket: str, key: str, version: str | None, operation: str) -> Item:
        found = next((i for i in self.versions(bucket, key) if i.id == version), None) if version else self.current(bucket, key)
        if found is None or (found.marker and not version):
            raise error("NoSuchKey", operation)
        return found

    # the S3 surface ----------------------------------------------------------------
    def put_object(self, Bucket: str, Key: str, Body: bytes, ContentMD5: str | None = None, Metadata: dict | None = None, **_) -> dict:  # noqa: N803
        if self.lock_days and not ContentMD5:
            raise error("InvalidRequest", "PutObject")  # Object Lock uploads need Content-MD5
        now = self.clock()
        until = now + datetime.timedelta(days=self.lock_days) if self.lock_days else None
        self.items.append(Item(Bucket, Key, str(next(self.ids)), now, Body, dict(Metadata or {}), retain_until=until))
        return {}

    def get_object(self, Bucket: str, Key: str, VersionId: str | None = None) -> dict:  # noqa: N803
        return {"Body": io.BytesIO(self._find(Bucket, Key, VersionId, "GetObject").body)}

    def head_object(self, Bucket: str, Key: str, VersionId: str | None = None) -> dict:  # noqa: N803
        return {"Metadata": self._find(Bucket, Key, VersionId, "HeadObject").meta}

    def delete_object(self, Bucket: str, Key: str, VersionId: str | None = None, BypassGovernanceRetention: bool | None = None) -> dict:  # noqa: N803
        self.deletes.append({"Key": Key, "VersionId": VersionId})
        if BypassGovernanceRetention:
            self.bypass_requests += 1
        if VersionId is None:
            self.items.append(Item(Bucket, Key, str(next(self.ids)), self.clock(), marker=True))
            return {}
        if self.refuse_deletes:
            raise error("AccessDenied", "DeleteObject")
        item = self._find(Bucket, Key, VersionId, "DeleteObject")
        if self._locked(item):
            raise error("AccessDenied", "DeleteObject")
        self.items.remove(item)
        return {}

    def get_object_retention(self, Bucket: str, Key: str, VersionId: str) -> dict:  # noqa: N803
        if self.refuse_retention_reads:
            raise error("AccessDenied", "GetObjectRetention")
        item = self._find(Bucket, Key, VersionId, "GetObjectRetention")
        if item.retain_until is None:
            raise error("NoSuchObjectLockConfiguration", "GetObjectRetention")
        return {"Retention": {"Mode": "GOVERNANCE", "RetainUntilDate": item.retain_until}}

    def get_object_legal_hold(self, Bucket: str, Key: str, VersionId: str) -> dict:  # noqa: N803
        return {"LegalHold": {"Status": "ON" if self._find(Bucket, Key, VersionId, "GetObjectLegalHold").hold else "OFF"}}

    def list_objects_v2(self, Bucket: str, Prefix: str = "") -> dict:  # noqa: N803
        found = [c for page in self.get_paginator("list_objects_v2").paginate(Bucket=Bucket, Prefix=Prefix) for c in page["Contents"]]
        return {"KeyCount": len(found), "Contents": found}

    def get_paginator(self, name: str) -> Paginator:
        return Paginator(self, name)
