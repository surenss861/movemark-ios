"""scripts/dr/retention.py against the fake B2. Timelines go through the real sync_evidence and push_db."""
from __future__ import annotations

import argparse
import datetime
import pathlib
import random
import secrets

import pytest
import retention
from conftest import DB, EV, SRC, World

A, B = "user-a/prop/1.jpg", "user-b/prop/2.jpg"


def stored(name: str) -> str:
    return f"objects/{SRC}/{name}"


def run_days(world: World, n: int, runs_per_day: int = 1) -> None:
    for _ in range(n):
        for _ in range(runs_per_day):
            world.advance(hours=24 / runs_per_day)
            world.backup()


def assert_nothing_deleted(world: World) -> None:
    assert [d for d in world.db.deletes + world.ev.deletes if d["VersionId"]] == []


# -- basic behaviour ---------------------------------------------------------------------

def test_dry_run_is_the_default_and_changes_nothing(world: World) -> None:
    world.upload(A)
    world.backup()
    world.remove(A)
    run_days(world, 100)
    before = len(world.ev.items), len(world.db.items)
    code, report = retention.run(world.db, DB, world.ev, EV, world.key, world.now, world.policy, allow_large=True)
    assert code == 0 and report["result"] == "DRY_RUN" and report["deleted"] == 0
    assert report["buckets"][1]["would_delete"] > 0
    assert (len(world.ev.items), len(world.db.items)) == before
    assert_nothing_deleted(world)


def test_a_deleted_object_goes_only_after_the_window(world: World) -> None:
    world.upload(A)
    world.upload(B)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 78)  # day 79 from the last manifest listing A
    assert world.prune()[0] == 0
    assert stored(A) in world.ev.keys(EV)
    run_days(world, 2)  # day 81
    assert world.prune()[0] == 0
    assert stored(A) not in world.ev.keys(EV)
    assert stored(B) in world.ev.keys(EV)


def test_an_old_object_that_is_still_live_is_never_pruned(world: World) -> None:
    world.upload(A)
    world.backup()
    run_days(world, 200)
    world.prune()
    assert stored(A) in world.ev.keys(EV)
    assert len(world.ev.versions(EV, stored(A))) == 1


def test_a_replaced_object_loses_its_old_version_but_keeps_the_current_one(world: World) -> None:
    world.upload(A, b"first")
    world.backup()
    world.advance(days=1)
    world.upload(A, b"second")
    world.backup()
    current = world.ev.current(EV, stored(A)).id
    run_days(world, 70)
    world.prune()
    assert len(world.ev.versions(EV, stored(A))) == 2  # an older manifest inside the window still names the first
    run_days(world, 15)
    world.prune()
    assert [v.id for v in world.ev.versions(EV, stored(A))] == [current]


def test_identical_content_under_two_names_is_two_stored_copies(world: World) -> None:
    """Storage isn't content-addressed: names are unique, so one name going can't touch the other."""
    world.upload(A, b"same bytes")
    world.upload(B, b"same bytes")
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 90)
    world.prune()
    assert stored(A) not in world.ev.keys(EV) and stored(B) in world.ev.keys(EV)


def test_a_name_that_came_back_keeps_its_new_content(world: World) -> None:
    world.upload(A, b"old")
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 85)
    world.upload(A, b"new")
    world.backup()
    world.prune()
    assert len(world.ev.versions(EV, stored(A))) == 1
    sealed = world.ev.current(EV, stored(A)).body
    assert retention.offsite.unseal(world.key, stored(A), sealed) == b"new"


def test_an_upload_no_manifest_knows_yet_is_left_alone(world: World) -> None:
    world.upload(A)
    world.backup()
    world.ev.put_object(Bucket=EV, Key=stored("in-flight/x.jpg"), Body=b"x", ContentMD5="y", Metadata={"sha256": "0" * 64})
    world.advance(days=1)
    world.backup()
    code, report = world.prune()
    assert code == 0 and stored("in-flight/x.jpg") in world.ev.keys(EV)


def test_files_outside_the_known_layout_are_untouched_and_counted(world: World) -> None:
    world.upload(A)
    world.backup()
    world.ev.put_object(Bucket=EV, Key="something-else/x", Body=b"x", ContentMD5="y")
    world.ev.put_object(Bucket=EV, Key="objects/not-a-bucket/x", Body=b"x", ContentMD5="y")
    world.db.put_object(Bucket=DB, Key="notes/x", Body=b"x", ContentMD5="y")
    run_days(world, 100)
    _, report = world.prune()
    assert {"something-else/x", "objects/not-a-bucket/x"} <= world.ev.keys(EV)
    assert "notes/x" in world.db.keys(DB)
    assert report["buckets"][0]["unknown"] == 1 and report["buckets"][1]["unknown"] == 2


# -- Object Lock --------------------------------------------------------------------------

def test_a_locked_version_waits_and_goes_when_the_lock_ends(world: World) -> None:
    world.upload(A)
    world.backup()
    orphan = stored("orphan/x.jpg")  # a crashed sync's upload: nothing lists it, its lock still runs
    world.advance(days=8)
    world.ev.put_object(Bucket=EV, Key=orphan, Body=b"x", ContentMD5="y", Metadata={"sha256": "0" * 64})
    world.backup()
    run_days(world, 8)
    code, report = world.prune()
    assert code == 0 and report["buckets"][1]["locked"] == 1 and orphan in world.ev.keys(EV)
    run_days(world, 23)
    code, report = world.prune()
    assert code == 0 and orphan not in world.ev.keys(EV)


def test_a_governance_bypass_is_never_sent(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 100)
    world.prune()
    assert world.db.bypass_requests == world.ev.bypass_requests == 0


def test_every_delete_names_a_version(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 100)
    world.prune()
    assert all(d["VersionId"] for d in world.db.deletes + world.ev.deletes)


def test_a_lock_running_past_the_limit_raises_the_alarm(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 90)
    world.ev.current(EV, stored(A)).retain_until = world.now + datetime.timedelta(days=30)
    code, report = world.prune()
    assert code == 3 and stored(A) in world.ev.keys(EV)
    assert "past the limit" in report["buckets"][1]["alarms"][0]


def test_a_legal_hold_is_respected_and_reported(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 90)
    world.ev.current(EV, stored(A)).hold = True
    code, report = world.prune()
    assert code == 3 and stored(A) in world.ev.keys(EV)
    assert "legal hold" in report["buckets"][1]["alarms"][0]


def test_an_unreadable_lock_state_means_keep(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 90)
    world.ev.refuse_retention_reads = True
    code, report = world.prune()
    assert code == 3 and stored(A) in world.ev.keys(EV) and report["buckets"][1]["blocked"] > 0


def test_a_delete_the_provider_refuses_is_reported_not_retried_around(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 90)
    world.ev.refuse_deletes = True
    code, report = world.prune()
    assert code == 3 and stored(A) in world.ev.keys(EV)
    assert report["buckets"][1]["deleted"] == 0 and world.ev.bypass_requests == 0


# -- hide markers and versions ------------------------------------------------------------

def test_hidden_versions_are_found_and_really_removed(world: World) -> None:
    """A hidden file doesn't show in a normal listing, and it is still stored."""
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    world.ev.delete_object(Bucket=EV, Key=stored(A))  # a hide marker on top
    assert stored(A) not in {o["Key"] for o in world.ev.list_objects_v2(Bucket=EV, Prefix="objects/")["Contents"]}
    assert world.ev.stored_bytes(EV, stored(A)) > 0
    run_days(world, 90)
    code, report = world.prune()
    assert code == 0 and world.ev.versions(EV, stored(A)) == []
    assert report["buckets"][1]["still_listed_after_delete"] == 0


def test_a_hide_marker_outlives_nothing_it_hides(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    world.ev.delete_object(Bucket=EV, Key=stored(A))
    run_days(world, 90)
    world.ev.current(EV, stored(A)).hold = False
    upload = world.ev.versions(EV, stored(A))[0]
    upload.hold = True  # the upload can't go, so its marker must stay
    world.prune()
    assert [v.marker for v in world.ev.versions(EV, stored(A))] == [False, True]


def test_a_delete_without_a_version_would_remove_nothing(world: World) -> None:
    """Why apply() always names a version: the fake, like B2, only adds a marker otherwise."""
    world.upload(A)
    world.backup()
    size = world.ev.stored_bytes(EV, stored(A))
    world.ev.delete_object(Bucket=EV, Key=stored(A))
    assert world.ev.stored_bytes(EV, stored(A)) == size


# -- backups and manifests ----------------------------------------------------------------

def test_database_backups_and_manifests_stop_at_the_window(world: World) -> None:
    world.upload(A)
    world.backup()
    run_days(world, 120)
    assert world.prune()[0] == 0
    oldest = world.now - datetime.timedelta(days=world.policy.window_days + 1)
    for bucket, store, prefix in ((DB, world.db, "db/"), (DB, world.db, "monthly/"), (EV, world.ev, "manifests/")):
        ages = [retention.stamp_of(k) for k in store.keys(bucket, prefix)]
        assert ages and min(ages) >= oldest, prefix


def test_the_newest_backup_is_kept_whatever_its_age(world: World) -> None:
    world.upload(A)
    world.backup()
    policy = retention.Policy(lock_days=1, window_days=2, alarm_days=3, promise_days=4, tracker_days=5)
    world.advance(days=1)
    code, _ = world.prune(policy=policy)
    assert code == 0 and len(world.db.keys(DB, "db/")) == 3


def test_an_incomplete_newest_backup_does_not_count(world: World) -> None:
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.db.put_object(Bucket=DB, Key="db/movemark-production-20991231T000000Z.mmbk", Body=b"x", ContentMD5="y")
    world.db.items[-1].modified = world.now
    world.advance(days=3)
    assert world.prune()[1]["result"] == "REFUSED"


def test_after_a_prune_the_newest_set_still_restores_from_b2(world: World, tmp_path: pathlib.Path) -> None:
    keep = {f"keep/{n}.jpg": world.upload(f"keep/{n}.jpg") for n in range(6)}
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 100)
    assert world.prune()[0] == 0
    out = tmp_path / "pulled"
    retention.offsite.pull(argparse.Namespace(key_file=world.key_file, to=out))
    for name, body in keep.items():
        assert (out / "evidence" / "objects" / SRC / name).read_bytes() == body
    assert not (out / "evidence" / "objects" / SRC / A).exists()


# -- refusals: nothing goes from either bucket ---------------------------------------------

def primed(world: World) -> None:
    """Dead objects and expired backups, all due for deletion, so a refusal has something to protect."""
    for n in range(6):
        world.upload(f"keep/{n}.jpg")
    world.upload(A)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 100)


def expect_refusal(world: World, text: str, allow_large: bool = True) -> None:
    code, report = world.prune(allow_large=allow_large)
    assert code == 2 and report["result"] == "REFUSED" and text in report["reason"]
    assert_nothing_deleted(world)


def test_refuses_when_a_kept_manifest_is_corrupt(world: World) -> None:
    primed(world)
    newest = max(world.ev.keys(EV, "manifests/"))
    middle = sorted(k for k in world.ev.keys(EV, "manifests/") if k != newest)[-10]
    world.ev.current(EV, middle).body = b"MMOB1\nnonsense-and-more-nonsense"
    expect_refusal(world, "can't be read")


def test_refuses_with_the_wrong_key(world: World) -> None:
    primed(world)
    world.key = secrets.token_bytes(32)
    expect_refusal(world, "can't be read")


def test_refuses_when_the_sync_has_stopped(world: World) -> None:
    primed(world)
    world.advance(days=3)
    world.push()
    expect_refusal(world, "newest manifest is")


def test_refuses_when_backups_have_stopped(world: World) -> None:
    primed(world)
    world.advance(days=3)
    world.sync()
    expect_refusal(world, "newest complete backup")


def test_refuses_on_a_clock_far_ahead(world: World) -> None:
    primed(world)
    world.advance(days=400)
    expect_refusal(world, "days old")


def test_refuses_on_a_clock_far_behind(world: World) -> None:
    primed(world)
    world.advance(days=-50)
    expect_refusal(world, "clock is wrong")


def test_refuses_when_a_current_object_is_missing(world: World) -> None:
    primed(world)
    world.ev.items = [i for i in world.ev.items if i.key != stored("keep/1.jpg")]
    expect_refusal(world, "missing or hidden")


def test_refuses_when_a_current_object_is_hidden(world: World) -> None:
    primed(world)
    world.ev.delete_object(Bucket=EV, Key=stored("keep/1.jpg"))
    expect_refusal(world, "missing or hidden")


def test_refuses_when_a_current_object_is_the_wrong_size(world: World) -> None:
    primed(world)
    world.ev.current(EV, stored("keep/1.jpg")).body += b"x"
    expect_refusal(world, "wrong size")


def test_refuses_a_hidden_newest_manifest(world: World) -> None:
    primed(world)
    world.ev.delete_object(Bucket=EV, Key=max(world.ev.keys(EV, "manifests/")))
    expect_refusal(world, "hidden")


def test_refuses_when_there_is_no_manifest(world: World) -> None:
    world.upload(A)
    world.push()
    expect_refusal(world, "no manifest")


def test_a_hidden_newest_backup_does_not_count(world: World) -> None:
    primed(world)
    newest = max(world.db.keys(DB, "db/"))
    world.db.delete_object(Bucket=DB, Key=newest)  # hide one of the newest set: only older ones are complete now
    world.advance(days=3)
    world.sync()
    expect_refusal(world, "newest complete backup")


def test_refuses_when_there_is_no_backup(world: World) -> None:
    world.upload(A)
    world.sync()
    expect_refusal(world, "no complete database backup")


def test_wiped_live_storage_does_not_take_the_backups_with_it(world: World) -> None:
    """The source is emptied, the sync dutifully writes empty manifests, and 80 days later everything is unlisted."""
    for n in range(10):
        world.upload(f"keep/{n}.jpg")
    world.backup()
    run_days(world, 60)
    world.source.items = []
    run_days(world, 1)
    expect_refusal(world, "the newest manifest lists 0", allow_large=False)
    run_days(world, 90)
    expect_refusal(world, "the plan removes", allow_large=False)


def test_a_large_removal_goes_ahead_only_with_a_person_saying_so(world: World) -> None:
    world.upload(A)
    world.upload(B)
    world.backup()
    world.advance(days=1)
    world.remove(A)
    run_days(world, 90)
    expect_refusal(world, "the plan removes", allow_large=False)
    assert world.prune(allow_large=True)[0] == 0
    assert stored(A) not in world.ev.keys(EV)


def test_the_policy_can_not_be_set_to_something_incoherent() -> None:
    for bad in ({"window_days": 20}, {"window_days": 95}, {"promise_days": 130}, {"alarm_days": 95}):
        with pytest.raises(ValueError):
            retention.Policy(**bad)


# -- the deletion log's own retention -----------------------------------------------------

def test_the_log_ages_out_from_its_oldest_end_only(world: World) -> None:
    world.upload(A)
    world.backup()
    run_days(world, 130)
    world.prune()
    log = sorted(world.db.keys(DB, "deletion-log/"))
    assert log, "the log must never be emptied"
    assert retention.stamp_of(log[0]) >= world.now - datetime.timedelta(days=world.policy.tracker_days + 1)
    numbers = [int(k.rsplit("-", 1)[1].split(".")[0]) for k in log]
    assert numbers == list(range(numbers[0], numbers[0] + len(numbers)))


def test_the_log_outlasts_every_kept_backup(world: World) -> None:
    world.upload(A)
    world.backup()
    run_days(world, 130)
    world.prune()
    oldest_backup = min(retention.stamp_of(k) for k in world.db.keys(DB, "db/") | world.db.keys(DB, "monthly/"))
    oldest_batch = min(retention.stamp_of(k) for k in world.db.keys(DB, "deletion-log/"))
    assert oldest_batch < oldest_backup


def test_the_newest_batch_survives_any_age(world: World) -> None:
    world.upload(A)
    world.backup()
    policy = retention.Policy(lock_days=1, window_days=2, alarm_days=3, promise_days=4, tracker_days=5)
    world.advance(days=1)
    world.backup()
    world.advance(days=10, hours=0)
    world.backup()
    world.prune(policy=policy)
    assert len(world.db.keys(DB, "deletion-log/")) >= 1


# -- the guarantee, over time -------------------------------------------------------------

@pytest.mark.parametrize("seed", range(3))
def test_simulated_year_holds_both_guarantees(world: World, seed: int) -> None:
    """A year of random uploads, replacements and deletions, two syncs a day, a daily prune that sometimes fails
    for up to 8 days, and the lifecycle backstop. Checked daily: no stored version outlives what it was by more
    than the 90 days, and every live object restores. Checked weekly, as it reads every manifest: everything
    every kept manifest lists is still there."""
    rng = random.Random(seed)
    world.policy = retention.Policy()
    live: dict[str, bytes] = {}
    stopped: dict[tuple[str, int], datetime.datetime] = {}  # (name, content hash): when it stopped being live
    outage_until = -1
    for n in range(40):
        name = f"u{n % 7}/p{n}/{n}.jpg"
        live[name] = world.upload(name)
    world.backup()
    for day in range(365):
        for _ in range(2):
            world.advance(hours=12)
            for _ in range(rng.randint(0, 2)):
                action = rng.choice(("new", "new", "replace", "delete"))
                if action == "new":
                    name = f"u{rng.randint(0, 6)}/p{rng.randint(0, 99)}/{secrets.token_hex(3)}.jpg"
                    live[name] = world.upload(name)
                elif live and action == "replace":
                    name = rng.choice(sorted(live))
                    stopped[(name, hash(live[name]))] = world.now
                    world.remove(name)
                    live[name] = world.upload(name)
                elif len(live) > 25:
                    name = rng.choice(sorted(live))
                    stopped[(name, hash(live[name]))] = world.now
                    world.remove(name)
                    del live[name]
            world.backup()
        world.lifecycle()
        if outage_until < day and rng.random() < 0.03:
            outage_until = day + rng.randint(1, 8)
        if day > outage_until:
            code, report = world.prune()
            assert code == 0, report

        # no copy past the limit
        for item in world.ev.items:
            if item.marker or not item.key.startswith("objects/"):
                continue
            name = item.key.split("/", 2)[2]
            plain = retention.offsite.unseal(world.key, item.key, item.body)
            ended = stopped.get((name, hash(plain)))
            if ended and live.get(name) != plain:
                assert (world.now - ended).days <= world.policy.promise_days
        for store, bucket in ((world.db, DB), (world.ev, EV)):
            for item in store.items:
                if item.key.startswith(("db/", "monthly/", "manifests/")):
                    assert (world.now - item.modified).days <= world.policy.promise_days

        # nothing current lost
        kept = retention.list_versions(world.ev, EV) if day % 7 == 0 else []
        for version in (v for v in kept if v.key.startswith("manifests/") and not v.marker):
            rows = retention.read_manifest_version(world.ev, EV, version, world.key)
            for name, size, _ in rows:
                if retention.age_days(version, world.now) <= world.policy.window_days:
                    assert any(not i.marker and len(i.body) == size + retention.SEAL_OVERHEAD
                               for i in world.ev.versions(EV, name)), "a kept manifest lost an object"
        for name, body in live.items():
            sealed = world.ev.current(EV, stored(name)).body
            assert retention.offsite.unseal(world.key, stored(name), sealed) == body
