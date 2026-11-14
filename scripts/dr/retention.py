"""MoveMark — enforce the backup retention limit on the two B2 buckets. Dry run unless told otherwise.

PROPOSED, not live. Nothing schedules this yet; see docs/backup-retention-design.md.

    ../movemark-api-py/.venv/bin/python scripts/dr/retention.py prune --key-file <key>
    ../movemark-api-py/.venv/bin/python scripts/dr/retention.py prune --key-file <key> --apply \\
        --confirm-db-bucket <name> --confirm-evidence-bucket <name>

It reads every file version in both buckets, decrypts every manifest inside the restore window, works out what
may go, and prints counts. With --apply it then deletes those versions by version id and lists the buckets again
to confirm they are gone. Output holds counts and ages only: object names contain user ids.

What may go, with W = Policy.window_days:
  db/, monthly/   a backup older than W, never the newest complete one.
  manifests/      a manifest older than W, never the newest.
  objects/        a version no manifest from the last W days needs. A manifest is a list of (name, SHA-256),
                  and each version carries its SHA-256 as metadata, so a version superseded at the source goes
                  while the current one stays. The last manifest to list an object was written no later than
                  the object stopped being live, so W counts from at or before the moment it stopped.
  deletion-log/   a batch past Policy.tracker_days, oldest first, never the newest, and only if no kept backup
                  is older than it. Replay needs the log to reach back past the backup being restored.
  hide markers    once no version of that name is left: the name itself holds a user id.

It refuses to delete anything at all, in either bucket, if:
  - any kept manifest can't be read or decrypted;
  - the newest manifest or newest complete backup is stale, which also catches a wrong clock;
  - something the newest manifest lists is missing, hidden or the wrong size;
  - the newest manifest shrank sharply, or the plan removes an unusual share of what is stored. Live storage
    wiped, or a sync that listed nothing, looks exactly like mass deletion. Needs --allow-large after review.

A version that can't be deleted yet is left alone and reported. It never sends a governance bypass, and it
never needs a key with bypassGovernance. Object Lock is honoured as the provider enforces it.

Run it from its own service with its own key. The backup job's key should not hold deleteFiles.
B2_DB_KEY_ID and friends are read as in scripts/dr/offsite.py, so that service sets them to the prune key.

Exit codes: 0 clean; 2 refused, nothing deleted; 3 ran, but something needs a person before the limit is reached.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime
import importlib.util
import json
import pathlib
import re
import sys
from collections import defaultdict
from typing import Iterable

from botocore.exceptions import ClientError

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("offsite", ROOT / "scripts" / "dr" / "offsite.py")
offsite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(offsite)

SEAL_OVERHEAD = len(offsite.OBJECT_MAGIC) + 12 + 16  # magic, nonce, GCM tag: stored size = source size + this
STAMP = re.compile(r"(\d{8}T\d{6}Z)")
DENIED = {"AccessDenied", "Forbidden", "InvalidRequest", "MethodNotAllowed"}
NO_LOCK = {"NoSuchObjectLockConfiguration", "ObjectLockConfigurationNotFoundError"}
DB_FILE = re.compile(r"^(?P<base>(?:db|monthly/\d{6})/movemark-[a-z0-9-]+-\d{8}T\d{6}Z)(?:\.mmbk|\.mmbk\.sha256|\.json)$")


class Refused(Exception):
    pass


@dataclasses.dataclass(frozen=True)
class Policy:
    promise_days: int = 90      # what the Privacy Policy would say
    window_days: int = 80       # restore points kept; the 10 days after it absorb failed runs
    alarm_days: int = 85        # past this, anything still present needs a person
    lock_days: int = 30         # B2 default retention, per docs/disaster-recovery.md
    orphan_grace_days: int = 7  # an upload no manifest knows yet may belong to a sync still running
    stale_hours: int = 48       # the newest manifest and backup must be younger
    tracker_days: int = 120     # = public.record_deletion (1060), deletion_log.TRACKER_DAYS
    max_delete_fraction: float = 0.25
    max_manifest_drop: float = 0.5

    def __post_init__(self) -> None:
        if not self.lock_days < self.window_days < self.alarm_days < self.promise_days < self.tracker_days:
            raise ValueError("need lock < window < alarm < promise < tracker")


@dataclasses.dataclass(frozen=True)
class Version:
    key: str
    version_id: str
    modified: datetime.datetime
    size: int
    latest: bool
    marker: bool


@dataclasses.dataclass
class Plan:
    bucket: str
    delete: list[Version] = dataclasses.field(default_factory=list)
    kept: int = 0
    locked: int = 0
    blocked: int = 0   # should have gone and couldn't be checked or deleted
    unknown: int = 0   # not a name this tool recognises; left alone
    alarms: list[str] = dataclasses.field(default_factory=list)


def list_versions(client, bucket: str) -> list[Version]:
    """Every version and hide marker. Listing current files would miss exactly what this exists to find."""
    found = []
    for page in client.get_paginator("list_object_versions").paginate(Bucket=bucket):
        for item in page.get("Versions", []):
            found.append(Version(item["Key"], item["VersionId"], item["LastModified"], item["Size"], item["IsLatest"], False))
        for item in page.get("DeleteMarkers", []):
            found.append(Version(item["Key"], item["VersionId"], item["LastModified"], 0, item["IsLatest"], True))
    return found


def stamp_of(name: str) -> datetime.datetime | None:
    match = STAMP.search(name)
    if not match:
        return None
    return datetime.datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=datetime.UTC)


def days(delta: datetime.timedelta) -> float:
    return delta.total_seconds() / 86400


def age_days(version: Version, now: datetime.datetime) -> float:
    """By the later of the stamp in its name and the upload time, so a wrong name can't age a file early."""
    stamp = stamp_of(version.key)
    return days(now - max(stamp, version.modified) if stamp else now - version.modified)


def check_clock(versions: Iterable[Version], now: datetime.datetime) -> None:
    if any(v.modified > now + datetime.timedelta(hours=1) for v in versions):
        raise Refused("a file is dated in the future: this machine's clock is wrong")


def lock_state(client, bucket: str, version: Version, now: datetime.datetime) -> str | datetime.datetime:
    """'free', 'held', 'unknown', or the time the lock ends. Asked per version, through the two calls Backblaze
    documents. Any answer that isn't clear is 'unknown', and unknown is not deleted."""
    args = {"Bucket": bucket, "Key": version.key, "VersionId": version.version_id}
    try:
        retention = client.get_object_retention(**args).get("Retention") or {}
    except ClientError as error:
        if error.response["Error"]["Code"] not in NO_LOCK:
            return "unknown"
        retention = {}
    try:
        hold = (client.get_object_legal_hold(**args).get("LegalHold") or {}).get("Status")
    except ClientError as error:
        if error.response["Error"]["Code"] not in NO_LOCK:
            return "unknown"
        hold = None
    if hold == "ON":
        return "held"
    until = retention.get("RetainUntilDate")
    return until if until and until > now else "free"


def schedule(client, plan: Plan, version: Version, policy: Policy, now: datetime.datetime, reason_age: float | None = None) -> None:
    """Put one expired version on the plan, unless its lock or an unclear answer says to wait."""
    state = lock_state(client, plan.bucket, version, now)
    if state == "free":
        plan.delete.append(version)
    elif state == "unknown":
        plan.blocked += 1
        plan.alarms.append("a version's lock state can't be read: the key may lack readFileRetentions or readFileLegalHolds")
    elif state == "held":
        plan.locked += 1
        plan.alarms.append("a version due for deletion is under legal hold")
    else:
        plan.locked += 1
        # A default lock ends 30 days after upload. One ending past upload + the limit was set by someone.
        if state > version.modified + datetime.timedelta(days=policy.promise_days):
            plan.alarms.append(f"a version is locked for {days(state - now):.0f} more days, past the limit")
        elif reason_age is not None and reason_age >= policy.alarm_days:
            plan.alarms.append(f"a version {reason_age:.0f} days old is still locked")


def markers_after(plan: Plan, versions: list[Version]) -> None:
    """A hide marker goes once every upload under its name is going. Deleting one earlier would un-hide the file."""
    going = {v.version_id for v in plan.delete}
    by_key: dict[str, list[Version]] = defaultdict(list)
    for version in versions:
        by_key[version.key].append(version)
    for group in by_key.values():
        uploads = [v for v in group if not v.marker]
        if all(v.version_id in going for v in uploads):
            plan.delete.extend(v for v in group if v.marker)


# -- DB bucket ---------------------------------------------------------------------------

def plan_db(client, bucket: str, now: datetime.datetime, policy: Policy) -> Plan:
    plan = Plan(bucket)
    versions = list_versions(client, bucket)
    check_clock(versions, now)
    backups = [v for v in versions if DB_FILE.match(v.key)]
    log = [v for v in versions if v.key.startswith("deletion-log/")]
    plan.unknown = len(versions) - len(backups) - len(log)

    sets: dict[str, set[str]] = defaultdict(set)
    for version in backups:
        if not version.marker and version.latest:  # a hidden backup can't be pulled, so it doesn't count
            sets[DB_FILE.match(version.key).group("base")].add(version.key)
    complete = [base for base, keys in sets.items() if len(keys) == 3 and base.startswith("db/")]
    if not complete:
        raise Refused("no complete database backup under db/")
    newest = max(complete, key=lambda base: stamp_of(base))
    if days(now - stamp_of(newest)) * 24 > policy.stale_hours:
        raise Refused(f"the newest complete backup is {days(now - stamp_of(newest)):.1f} days old")

    kept_stamps = []
    for version in (v for v in backups if not v.marker):
        base = DB_FILE.match(version.key).group("base")
        age = age_days(version, now)
        if base == newest or age <= policy.window_days:
            plan.kept += 1
            kept_stamps.append(stamp_of(version.key))
        else:
            schedule(client, plan, version, policy, now, age)
    oldest_kept = min(kept_stamps)

    # The log needs to reach back past every kept backup, and it can only lose its oldest end.
    uploads = sorted((v for v in log if not v.marker), key=lambda v: v.key)
    open_end = True
    for index, version in enumerate(uploads):
        stamp = stamp_of(version.key)
        expired = stamp is not None and days(now - stamp) > policy.tracker_days and stamp < oldest_kept
        if open_end and expired and index < len(uploads) - 1:
            before = len(plan.delete)
            schedule(client, plan, version, policy, now)
            open_end = len(plan.delete) > before
            continue
        open_end = False
        plan.kept += 1
    markers_after(plan, backups + log)
    return plan


# -- evidence bucket ---------------------------------------------------------------------

def read_manifest_version(client, bucket: str, version: Version, key: bytes) -> list[tuple[str, int, str]]:
    """(stored name, source bytes, sha256) for one manifest version. Any failure refuses the whole run."""
    try:
        sealed = client.get_object(Bucket=bucket, Key=version.key, VersionId=version.version_id)["Body"].read()
        text = offsite.unseal(key, version.key, sealed).decode()
        rows = []
        for line in text.splitlines():
            src_bucket, obj_key, size, digest, _ = line.split("\t")
            rows.append((f"objects/{src_bucket}/{obj_key}", int(size), digest))
        return rows
    except Exception as error:  # noqa: BLE001
        raise Refused(f"a kept manifest can't be read ({type(error).__name__})") from error


def plan_evidence(client, bucket: str, key: bytes, now: datetime.datetime, policy: Policy, allow_large: bool = False) -> Plan:
    plan = Plan(bucket)
    versions = list_versions(client, bucket)
    check_clock(versions, now)
    manifests = [v for v in versions if v.key.startswith("manifests/") and stamp_of(v.key)]
    objects = [v for v in versions if v.key.startswith("objects/")]
    plan.unknown = len(versions) - len(manifests) - len(objects)

    uploads = sorted((v for v in manifests if not v.marker), key=lambda v: v.key)
    if not uploads:
        raise Refused("no manifest in the bucket")
    newest = uploads[-1]
    if days(now - stamp_of(newest.key)) * 24 > policy.stale_hours:
        raise Refused(f"the newest manifest is {days(now - stamp_of(newest.key)):.1f} days old")
    if not newest.latest:
        raise Refused("the newest manifest is hidden")

    # A manifest hidden inside the window still counts: it may be the only record of what a backup needs.
    kept = [v for v in uploads if age_days(v, now) <= policy.window_days or v is newest]
    expired = [v for v in uploads if v not in kept]
    needed: dict[str, set[str]] = defaultdict(set)
    sizes = []
    for version in kept:
        rows = read_manifest_version(client, bucket, version, key)
        sizes.append(len(rows))
        for name, _, digest in rows:
            needed[name].add(digest)
    current = read_manifest_version(client, bucket, newest, key)
    if len(current) < (1 - policy.max_manifest_drop) * max(sizes) and not allow_large:
        raise Refused(f"the newest manifest lists {len(current)} objects, the largest kept one {max(sizes)}")

    by_key: dict[str, list[Version]] = defaultdict(list)
    for version in objects:
        by_key[version.key].append(version)
    for name, size, _ in current:
        group = by_key.get(name, [])
        if not any(v.latest and not v.marker for v in group):
            raise Refused("an object in the newest manifest is missing or hidden")
        if not any(v.size == size + SEAL_OVERHEAD for v in group if not v.marker):
            raise Refused("an object in the newest manifest is the wrong size")

    for name, group in by_key.items():
        plan_object(client, plan, name, group, needed.get(name), now, policy)
    plan.kept += len(kept)

    total = sum(1 for v in objects if not v.marker)
    going = sum(1 for v in plan.delete if not v.marker)
    if total and going / total > policy.max_delete_fraction and not allow_large:
        raise Refused(f"the plan removes {going} of {total} stored versions")

    for version in expired:
        schedule(client, plan, version, policy, now, age_days(version, now))
    markers_after(plan, objects + manifests)
    return plan


def plan_object(client, plan: Plan, name: str, group: list[Version], digests: set[str] | None,
                now: datetime.datetime, policy: Policy) -> None:
    uploads = sorted((v for v in group if not v.marker), key=lambda v: v.modified)
    if name.split("/")[1] not in offsite.backup.BUCKETS:
        plan.unknown += len(group)
        return
    for version in uploads:
        young = days(now - version.modified) < policy.orphan_grace_days
        if digests is None:  # no kept manifest lists this name
            if young:
                plan.kept += 1
            else:
                schedule(client, plan, version, policy, now)
            continue
        if version.latest or len(uploads) == 1 or young:
            plan.kept += 1
            continue
        try:  # listed, and this is an older version: is it the content a kept manifest names?
            digest = client.head_object(Bucket=plan.bucket, Key=name, VersionId=version.version_id)["Metadata"].get("sha256")
        except ClientError:
            digest = None
        if digest is None:
            plan.kept += 1
            plan.blocked += 1
            plan.alarms.append("an older version carries no readable sha256, so it can't be matched to a manifest")
        elif digest in digests:
            plan.kept += 1
        else:
            schedule(client, plan, version, policy, now)


# -- applying ----------------------------------------------------------------------------

def apply(client, plan: Plan) -> int:
    """Delete by version id only: a delete without one writes a hide marker and removes nothing. Uploads go before
    markers, so a file can't reappear halfway. A refusal is counted; anything else stops the run."""
    deleted = 0
    for version in sorted(plan.delete, key=lambda v: v.marker):
        try:
            client.delete_object(Bucket=plan.bucket, Key=version.key, VersionId=version.version_id)
            deleted += 1
        except ClientError as error:
            if error.response["Error"]["Code"] not in DENIED:
                raise
            plan.blocked += 1
            plan.alarms.append("the provider refused a delete: see Object Lock and the key's capabilities")
    return deleted


def confirm_gone(client, plan: Plan) -> int:
    """Removed, not just hidden: list every version again and look for what was deleted."""
    remaining = {v.version_id for v in list_versions(client, plan.bucket)}
    return sum(1 for v in plan.delete if v.version_id in remaining)


def run(db_client, db_bucket: str, ev_client, ev_bucket: str, key: bytes, now: datetime.datetime, policy: Policy,
        do_apply: bool = False, allow_large: bool = False) -> tuple[int, dict]:
    """Both plans are made before anything is deleted, so a refusal in either bucket stops both."""
    try:
        plans = [plan_db(db_client, db_bucket, now, policy), plan_evidence(ev_client, ev_bucket, key, now, policy, allow_large)]
    except Refused as error:
        return 2, {"result": "REFUSED", "reason": str(error), "deleted": 0}
    clients = (db_client, ev_client)
    report: dict = {"result": "APPLIED" if do_apply else "DRY_RUN", "deleted": 0, "buckets": []}
    code = 0
    for client, plan in zip(clients, plans):
        entry = {"would_delete": len(plan.delete), "kept": plan.kept, "locked": plan.locked, "unknown": plan.unknown}
        if do_apply:
            deleted = apply(client, plan)
            report["deleted"] += deleted
            still_there = confirm_gone(client, plan) - (len(plan.delete) - deleted)  # refusals are already reported
            entry |= {"deleted": deleted, "still_listed_after_delete": max(still_there, 0)}
            if still_there > 0:
                plan.alarms.append("a deleted version is still listed")
        entry |= {"blocked": plan.blocked, "alarms": sorted(set(plan.alarms))}
        code = 3 if plan.alarms else code
        report["buckets"].append(entry)
    return code, report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prune")
    p.add_argument("--key-file", type=pathlib.Path, required=True)
    p.add_argument("--apply", action="store_true", help="delete; without it nothing is changed")
    p.add_argument("--confirm-db-bucket", default="")
    p.add_argument("--confirm-evidence-bucket", default="")
    p.add_argument("--allow-large", action="store_true", help="after a person has reviewed why so much would go")
    args = ap.parse_args()
    db_client, db_bucket = offsite.b2("DB")
    ev_client, ev_bucket = offsite.b2("EVIDENCE")
    if args.apply and (args.confirm_db_bucket != db_bucket or args.confirm_evidence_bucket != ev_bucket):
        sys.exit("--apply needs --confirm-db-bucket and --confirm-evidence-bucket naming the buckets in the environment")
    code, report = run(db_client, db_bucket, ev_client, ev_bucket, args.key_file.expanduser().read_bytes(),
                       datetime.datetime.now(datetime.UTC), Policy(), args.apply, args.allow_large)
    print(json.dumps(report, indent=2))
    print("RETENTION", report["result"], "exit", code)
    return code


if __name__ == "__main__":
    sys.exit(main())
