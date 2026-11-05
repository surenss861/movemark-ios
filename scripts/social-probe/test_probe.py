"""Unit tests for the social-sign-in probe's evaluation and target rules (no network).

    movemark-api-py/.venv/bin/python -m pytest movemork/scripts/social-probe -q
"""

import importlib.util
import json
import sys
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location("probe", Path(__file__).with_name("probe.py"))
probe = importlib.util.module_from_spec(spec)
sys.modules["probe"] = probe  # dataclasses resolve their module through sys.modules
spec.loader.exec_module(probe)

U0 = "11111111-1111-4111-8111-111111111111"
U1 = "22222222-2222-4222-8222-222222222222"
EMAIL = "victim@example.com"


def status(verdicts, case):
    return next(v for v in verdicts if v.case == case).status


def rec(case, outcome="ok", user=U1, platform="ios", provider="google", email=EMAIL, relay=False):
    return {"case": case, "platform": platform, "provider": provider, "outcome": outcome, "user_id": user,
            "email_sha256": probe.email_digest(email) if email else None, "email_is_relay": relay}


def seeded(kind="unverified", user=U0, email=EMAIL):
    return {probe.email_digest(email): {"user_id": user, "kind": kind}}


# ---- target ----

@pytest.mark.parametrize("raw,ok", [
    ("https://ep-long-bird-bd8ytm19.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", True),
    ("http://ep-long-bird-bd8ytm19.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", False),
    ("https://ep-steep-wind-x.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", False),  # production endpoint
    ("https://ep-dev-host.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", False),      # listed app (dev) host
    ("https://ep-x.neonauth.us-east-2.aws.neon.tech.evil.example/auth", False),
    ("", False),
    (None, False),
])
def test_probe_target_rule(raw, ok):
    hosts = {"ep-dev-host.neonauth.c-8.us-east-2.aws.neon.tech"}
    assert (probe.validated_probe_url(raw, hosts) is not None) == ok


def test_email_is_only_ever_a_case_insensitive_digest():
    assert probe.email_digest(" Victim@Example.com ") == probe.email_digest(EMAIL)
    assert EMAIL not in probe.email_digest(EMAIL)


# ---- nothing recorded: everything blocked, never passed ----

def test_no_evidence_is_blocked_not_passed():
    verdicts = probe.evaluate({"seeded": {}, "records": []})
    assert {v.status for v in verdicts} == {"BLOCKED"}
    assert {v.case for v in verdicts} == set(probe.CASES)


# ---- T5 takeover gate ----

def test_takeover_fails_when_social_sign_in_reaches_the_unverified_account():
    v = probe.evaluate({"seeded": seeded(), "records": [rec("T5", user=U0)]})
    assert status(v, "T5") == "FAIL"


def test_takeover_passes_on_a_recognised_refusal():
    v = probe.evaluate({"seeded": seeded(), "records": [rec("T5", outcome="rejected:ACCOUNT_NOT_LINKED", user=None)]})
    assert status(v, "T5") == "PASS"


def test_takeover_passes_when_kept_as_a_separate_user():
    v = probe.evaluate({"seeded": seeded(), "records": [rec("T5", user=U1)]})
    assert status(v, "T5") == "PASS"


def test_unexplained_refusal_is_not_evidence_of_safety():
    v = probe.evaluate({"seeded": seeded(), "records": [rec("T5", outcome="rejected:INTERNAL_ERROR", user=None)]})
    assert status(v, "T5") == "FAIL"


def test_takeover_needs_a_matching_seeded_email():
    v = probe.evaluate({"seeded": seeded(), "records": [rec("T5", email="someone-else@example.com")]})
    assert status(v, "T5") == "BLOCKED"


def test_verified_seed_does_not_satisfy_the_unverified_gate():
    v = probe.evaluate({"seeded": seeded(kind="verified"), "records": [rec("T5", user=U1)]})
    assert status(v, "T5") == "BLOCKED"


def test_implicit_linking_gate_T6():
    assert status(probe.evaluate({"seeded": seeded(kind="verified"), "records": [rec("T6", user=U0)]}), "T6") == "FAIL"
    assert status(probe.evaluate({"seeded": seeded(kind="verified"), "records": [rec("T6", user=U1)]}), "T6") == "PASS"


# ---- identity continuity ----

def test_returning_sign_in_must_keep_the_user():
    first = rec("T1", user=U1)
    assert status(probe.evaluate({"seeded": {}, "records": [first, rec("T2", user=U1)]}), "T2") == "PASS"
    assert status(probe.evaluate({"seeded": {}, "records": [first, rec("T2", user=U0)]}), "T2") == "FAIL"
    assert status(probe.evaluate({"seeded": {}, "records": [rec("T2", user=U1)]}), "T2") == "FAIL"  # no first sign-in


def test_cross_platform_identity():
    same = [rec("T7", platform="ios"), rec("T7", platform="android")]
    assert status(probe.evaluate({"seeded": {}, "records": same}), "T7") == "PASS"
    split = [rec("T7", platform="ios", user=U0), rec("T7", platform="android", user=U1)]
    assert status(probe.evaluate({"seeded": {}, "records": split}), "T7") == "FAIL"
    assert status(probe.evaluate({"seeded": {}, "records": [rec("T7", platform="ios")]}), "T7") == "BLOCKED"


def test_hide_my_email_and_cancellation_and_sign_out():
    relay = "abc@privaterelay.appleid.com"
    hme = [rec("T3", provider="apple", email=relay, relay=True), rec("T3", provider="apple", email=relay, relay=True)]
    assert status(probe.evaluate({"seeded": {}, "records": hme}), "T3") == "PASS"
    assert status(probe.evaluate({"seeded": {}, "records": [rec("T4", outcome="cancelled", user=None)]}), "T4") == "PASS"
    assert status(probe.evaluate({"seeded": {}, "records": [rec("T4", outcome="cancelled", user=U1)]}), "T4") == "FAIL"
    assert status(probe.evaluate({"seeded": {}, "records": [rec("T8", outcome="signed_out")]}), "T8") == "PASS"


# ---- CLI round trip: results never contain the email ----

def test_record_and_report_store_no_email(tmp_path, capsys):
    results = tmp_path / "r.json"
    assert probe.main(["--results", str(results), "record", "--case", "T1", "--platform", "ios", "--provider",
                       "google", "--outcome", "ok", "--user-id", U1.upper(), "--email", EMAIL]) == 0
    raw = results.read_text()
    assert EMAIL not in raw and U1 in raw
    assert oct(results.stat().st_mode & 0o777) == "0o600"
    assert probe.main(["--results", str(results), "report"]) == 2  # incomplete: everything else is blocked
    assert "INCOMPLETE" in capsys.readouterr().out
    assert json.loads(raw)["records"][0]["email_sha256"] == probe.email_digest(EMAIL)
