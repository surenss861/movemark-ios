"""scripts/dr/deletion_log.py: the log's integrity rules and file replay, without a database."""
from __future__ import annotations

import datetime
import json
import pathlib
import secrets
import uuid

import deletion_log as dl
import pytest
from conftest import DB, World

DAY = datetime.date(2026, 1, 1)


def row(subject: str, kind: str = "account", day: datetime.date = DAY) -> tuple:
    return (kind, dl.subject_hash(subject), day)


def read(world: World) -> dl.Log:
    return dl.verify(dl.read_remote(world.db, DB), world.key)


def batches(world: World) -> list[str]:
    return sorted(world.db.keys(DB, dl.PREFIX))


def test_the_hash_folds_case_and_is_salted() -> None:
    subject = str(uuid.uuid4())
    assert dl.subject_hash(subject) == dl.subject_hash(subject.upper())
    import hashlib
    assert dl.subject_hash(subject) != hashlib.sha256(subject.encode()).hexdigest()


def test_an_export_with_nothing_new_still_writes_a_heartbeat(world: World) -> None:
    world.export()
    world.advance(hours=6)
    world.export()
    log = read(world)
    assert log.batches == 2 and log.entries == {} and log.genesis


def test_the_log_holds_no_raw_id(world: World) -> None:
    subject = str(uuid.uuid4())
    world.export([row(subject)])
    sealed = world.db.current(DB, batches(world)[0]).body
    plain = dl.offsite.unseal(world.key, batches(world)[0], sealed)
    assert subject.encode() not in sealed and subject.encode() not in plain
    assert set(json.loads(plain)["entries"][0]) == {"k", "h", "d"}


def test_export_appends_only_what_the_log_lacks(world: World) -> None:
    first, second = str(uuid.uuid4()), str(uuid.uuid4())
    world.export([row(first)])
    world.advance(hours=6)
    world.export([row(first), row(second)])
    bodies = [json.loads(dl.offsite.unseal(world.key, n, world.db.current(DB, n).body)) for n in batches(world)]
    assert [len(b["entries"]) for b in bodies] == [1, 1]
    assert len(read(world).entries) == 2


def test_a_database_rewound_by_a_restore_does_not_hide_later_deletions(world: World) -> None:
    """A restore rewinds the table. Comparing contents, not a position, means the next deletion still lands."""
    first, second, third = (str(uuid.uuid4()) for _ in range(3))
    world.export([row(first), row(second)])
    world.advance(hours=6)
    world.export([row(first), row(third)])  # restored to before `second`, then `third` deleted
    log = read(world)
    assert log.hashes("account") == {dl.subject_hash(s) for s in (first, second, third)}


def test_expired_rows_are_not_exported_again(world: World) -> None:
    old = (world.now - datetime.timedelta(days=dl.TRACKER_DAYS + 2)).date()
    world.export([row(str(uuid.uuid4()), day=old)])
    assert read(world).entries == {}


def test_a_clock_behind_the_log_stops_the_export(world: World) -> None:
    world.export()
    world.advance(days=-1)
    with pytest.raises(SystemExit):
        world.export()


def chain(world: World, n: int = 4) -> list[tuple[str, bytes]]:
    for i in range(n):
        world.export([row(str(i))])
        world.advance(hours=6)
    return dl.read_remote(world.db, DB)


def test_a_sound_chain_verifies(world: World) -> None:
    log = dl.verify(chain(world), world.key)
    assert log.batches == 4 and len(log.entries) == 4 and log.next_seq == 5


def test_a_removed_batch_is_refused(world: World) -> None:
    items = chain(world)
    with pytest.raises(dl.LogRefused, match="missing"):
        dl.verify(items[:1] + items[2:], world.key)


def test_an_altered_batch_is_refused(world: World) -> None:
    items = chain(world)
    items[1] = (items[1][0], items[1][1][:-1] + bytes([items[1][1][-1] ^ 1]))
    with pytest.raises(dl.LogRefused, match="authenticated"):
        dl.verify(items, world.key)


def test_a_batch_copied_to_another_name_is_refused(world: World) -> None:
    items = chain(world)
    items[1] = (items[1][0], items[2][1])
    with pytest.raises(dl.LogRefused, match="authenticated"):
        dl.verify(items, world.key)


def test_a_substituted_batch_with_the_right_key_is_refused(world: World) -> None:
    items = chain(world)
    name = items[1][0]
    body = json.dumps({"v": 1, "seq": 2, "created_utc": dl._parts(name)[0], "prev_sha256": "0" * 64, "entries": []}).encode()
    items[1] = (name, dl.offsite.seal(world.key, name, body))
    with pytest.raises(dl.LogRefused, match="chain"):
        dl.verify(items, world.key)


def test_the_wrong_key_is_refused(world: World) -> None:
    with pytest.raises(dl.LogRefused):
        dl.verify(chain(world), secrets.token_bytes(32))


def test_a_stray_file_is_refused(world: World) -> None:
    items = chain(world) + [("deletion-log/notes.txt", b"x")]
    with pytest.raises(dl.LogRefused, match="unexpected"):
        dl.verify(items, world.key)


def test_a_log_aged_from_the_front_still_verifies(world: World) -> None:
    log = dl.verify(chain(world)[2:], world.key)
    assert log.batches == 2 and not log.genesis


def test_an_empty_log_is_a_gap(world: World) -> None:
    with pytest.raises(dl.LogGap, match="empty"):
        dl.check_span(dl.verify([], world.key), "20260101T000000Z")


def test_a_log_that_stops_before_the_backup_is_a_gap(world: World) -> None:
    log = dl.verify(chain(world), world.key)
    with pytest.raises(dl.LogGap, match="export had stopped"):
        dl.check_span(log, "20990101T000000Z")


def test_a_log_starting_after_the_backup_is_a_gap_unless_it_is_the_first_batch(world: World) -> None:
    items = chain(world)
    before = "20251201T000000Z"
    dl.check_span(dl.verify(items, world.key), before)  # batch 1: nothing older ever existed
    with pytest.raises(dl.LogGap, match="aged out"):
        dl.check_span(dl.verify(items[2:], world.key), before)


# -- files --------------------------------------------------------------------------------

def tree(tmp_path: pathlib.Path, gone: str, rental: str, kept: str) -> tuple[pathlib.Path, pathlib.Path]:
    objects = tmp_path / "objects"
    rows = []
    for bucket, key in (("inspection-media", f"{gone}/p1/a.jpg"), ("leases", f"{gone.upper()}/p1/old-swift.pdf"),
                        ("inspection-media", f"{kept}/{rental}/b.jpg"), ("inspection-media", f"{kept}/p3/c.jpg")):
        path = objects / bucket / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"x")
        rows.append(f"{bucket}\t{key}\t1\t{'0' * 64}\n")
    manifest = tmp_path / "manifest.tsv"
    manifest.write_text("".join(rows))
    return objects, manifest


def test_replay_removes_logged_files_and_their_manifest_rows_only(tmp_path: pathlib.Path) -> None:
    gone, rental, kept = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    objects, manifest = tree(tmp_path, gone, rental, kept)
    targets = {("account", dl.subject_hash(gone)), ("property", dl.subject_hash(rental))}
    assert dl.replay_objects(objects, manifest, targets) == {"objects_removed": 3}
    left = [str(p.relative_to(objects)) for p in objects.rglob("*") if p.is_file()]
    assert left == [f"inspection-media/{kept}/p3/c.jpg"]
    assert [line.split("\t")[1] for line in manifest.read_text().splitlines()] == [f"{kept}/p3/c.jpg"]


def test_a_kind_is_only_matched_where_it_belongs(tmp_path: pathlib.Path) -> None:
    """An account hash must not match a rental folder, nor a rental hash a user folder."""
    gone, rental, kept = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    objects, manifest = tree(tmp_path, gone, rental, kept)
    assert dl.replay_objects(objects, manifest, {("property", dl.subject_hash(gone)), ("account", dl.subject_hash(rental))}) == {"objects_removed": 0}
