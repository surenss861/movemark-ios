#!/usr/bin/env python3
"""MoveMark social-sign-in security probe (feature/social-welcome).

Runs against the ISOLATED Neon Auth probe project only. Never against dev or production.

    python3 scripts/social-probe/probe.py status
    python3 scripts/social-probe/probe.py seed-unverified --email you+takeover@example.com   # operator only
    python3 scripts/social-probe/probe.py record --case T5 --platform ios --provider google \
        --outcome ok --user-id <uuid from the app's probe dialog> --email <email from the dialog>
    python3 scripts/social-probe/probe.py report

Rules it enforces:
  * The target is SOCIAL_PROBE_AUTH_URL. It must be HTTPS on a Neon Auth host and must not be the app's dev or
    production auth host (MOVEMARK_APP_AUTH_HOSTS, comma-separated, plus the production host below).
  * Nothing it prints or stores contains a token, cookie, password or email address. Emails are kept as SHA-256
    of the lower-cased address; results hold user ids (random UUIDs on a disposable project) and outcomes.
  * A case with no recorded evidence is BLOCKED, never PASS. `report` exits 1 on any FAIL, 2 if anything is
    BLOCKED, 0 only when every case passed.
  * It never configures providers or changes the probe; `status` is read-only.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

PROBE_PROJECT_ID = "shy-lake-41996372"
PRODUCTION_AUTH_HOST_MARKER = "ep-steep-wind"  # Consumer production compute endpoint; never a probe target
DEFAULT_RESULTS = Path(os.environ.get("SOCIAL_PROBE_RESULTS", "/Volumes/sss/movemark/_scratch/social-probe-results.json"))

# Codes Better Auth / Neon Auth use when a social sign-in is refused instead of linked.
REFUSAL_CODES = {"ACCOUNT_NOT_LINKED", "LINKING_NOT_ALLOWED", "UNABLE_TO_LINK_ACCOUNT", "EMAIL_NOT_VERIFIED",
                 "SOCIAL_ACCOUNT_ALREADY_LINKED", "USER_ALREADY_EXISTS"}


# ---- target ---------------------------------------------------------------------------------------------------

def validated_probe_url(raw: str | None, app_hosts: set[str]) -> str | None:
    """Same rule as the apps: HTTPS, a *.neonauth.*.neon.tech host, not an app (dev/production) auth host."""
    if not raw or not raw.strip():
        return None
    url = urlparse(raw.strip())
    host = (url.hostname or "").lower()
    if url.scheme != "https" or ".neonauth." not in host or not host.endswith(".neon.tech"):
        return None
    if PRODUCTION_AUTH_HOST_MARKER in host or host in {h.lower() for h in app_hosts}:
        return None
    return raw.strip().rstrip("/")


def probe_url() -> str:
    hosts = {h.strip() for h in os.environ.get("MOVEMARK_APP_AUTH_HOSTS", "").split(",") if h.strip()}
    url = validated_probe_url(os.environ.get("SOCIAL_PROBE_AUTH_URL"), hosts)
    if not url:
        sys.exit("SOCIAL_PROBE_AUTH_URL must be the isolated probe's Neon Auth URL (HTTPS, *.neonauth.*.neon.tech, "
                 "not the app's dev or production auth host). Set MOVEMARK_APP_AUTH_HOSTS to the dev host too.")
    return url


def email_digest(email: str) -> str:
    return hashlib.sha256(email.strip().lower().encode()).hexdigest()


# ---- results --------------------------------------------------------------------------------------------------

def load_results(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {"seeded": {}, "records": []}


def save_results(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True))
    os.chmod(tmp, 0o600)
    tmp.replace(path)


@dataclass(frozen=True)
class Verdict:
    case: str
    title: str
    status: str  # PASS | FAIL | BLOCKED
    detail: str


CASES = {
    "T1": "First-time sign-in creates one Neon user (per provider/platform)",
    "T2": "Returning sign-in resolves to the same Neon user",
    "T3": "Apple Hide My Email: relay address accepted and stable on return",
    "T4": "Cancelling the provider sheet creates no session and no user",
    "T5": "TAKEOVER: after the real email owner signs in with Google/Apple, whoever registered that email unverified "
          "must not keep access with the original password",
    "T6": "No implicit linking: social sign-in with the email of a VERIFIED email/password account is refused or "
          "kept separate unless the user links explicitly while signed in",
    "T7": "Cross-platform: the same provider identity on iOS and Android resolves to the same Neon user",
    "T8": "Sign-out: the session ends and the app returns to Welcome (probe: 'Signed out of the probe')",
    "T9": "Cleanup: every disposable account is confirmed deleted (sign-in with it fails afterwards)",
}

# Evidence for T5, not a verdict of its own: after a social sign-in reached the seeded user, does the ORIGINAL password
# still sign in? Outcome password_ok (with the user id it reached) or password_rejected.
EVIDENCE_CASES = {"T5P"}


def evaluate(data: dict) -> list[Verdict]:
    recs = data.get("records", [])
    seeded = data.get("seeded", {})

    def of(case: str) -> list[dict]:
        return [r for r in recs if r["case"] == case]

    out: list[Verdict] = []

    # T1 / T2: per (platform, provider), first and returning ids agree.
    firsts = {(r["platform"], r["provider"]): r for r in of("T1") if r["outcome"] == "ok"}
    returns = of("T2")
    if not firsts:
        out.append(Verdict("T1", CASES["T1"], "BLOCKED", "no first-time sign-in recorded"))
    else:
        out.append(Verdict("T1", CASES["T1"], "PASS", f"{len(firsts)} platform/provider pair(s) signed in"))
    if not returns:
        out.append(Verdict("T2", CASES["T2"], "BLOCKED", "no returning sign-in recorded"))
    else:
        bad = [r for r in returns if r["outcome"] != "ok" or (r["platform"], r["provider"]) not in firsts
               or firsts[(r["platform"], r["provider"])]["user_id"] != r["user_id"]]
        out.append(Verdict("T2", CASES["T2"], "FAIL" if bad else "PASS",
                           f"{len(bad)} returning sign-in(s) changed user or had no first sign-in" if bad
                           else f"{len(returns)} returning sign-in(s) kept their user"))

    # T3: Apple relay email, stable id.
    t3 = of("T3")
    if not t3:
        out.append(Verdict("T3", CASES["T3"], "BLOCKED", "no Apple Hide My Email run recorded"))
    else:
        relay = [r for r in t3 if r.get("email_is_relay")]
        ids = {r["user_id"] for r in relay if r["outcome"] == "ok"}
        ok = relay and len(ids) == 1 and all(r["outcome"] == "ok" for r in relay)
        out.append(Verdict("T3", CASES["T3"], "PASS" if ok else "FAIL",
                           "relay address, one stable user" if ok else "relay runs missing, failed or changed user"))

    # T4: cancelled runs carry no user id.
    t4 = of("T4")
    if not t4:
        out.append(Verdict("T4", CASES["T4"], "BLOCKED", "no cancellation recorded"))
    else:
        bad = [r for r in t4 if r["outcome"] != "cancelled" or r.get("user_id")]
        out.append(Verdict("T4", CASES["T4"], "FAIL" if bad else "PASS",
                           "a cancelled run produced a user" if bad else f"{len(t4)} cancellation(s), no user"))

    # T5: reaching the same user id is not itself a takeover. The breach is the unverified registrant KEEPING access:
    # the original password still working after the real owner has signed in through the provider.
    seeds = {d: x for d, x in seeded.items() if x.get("kind") == "unverified"}
    runs = [r for r in of("T5") if r.get("email_sha256") in seeds]
    if not seeds or not runs:
        out.append(Verdict("T5", CASES["T5"], "BLOCKED",
                           "needs a seeded unverified email/password account and a social sign-in with that email"))
    else:
        checks = {r.get("email_sha256"): r for r in of("T5P")}
        breached, pending, unexplained, mitigated, separate = [], [], [], [], []
        for r in runs:
            seed = seeds[r["email_sha256"]]
            if r["outcome"].startswith("rejected:"):
                (separate if r["outcome"].split(":", 1)[1] in REFUSAL_CODES else unexplained).append(r)
            elif r["outcome"] == "ok" and r.get("user_id") == seed["user_id"]:
                check = checks.get(r["email_sha256"])
                if check is None:
                    pending.append(r)
                elif check["outcome"] == "password_ok":
                    breached.append(r)
                elif check["outcome"] == "password_rejected":
                    mitigated.append(r)
                else:
                    pending.append(r)
            else:
                separate.append(r)
        if breached:
            out.append(Verdict("T5", CASES["T5"], "FAIL",
                               f"{len(breached)} account(s) linked to the social identity and the original password still "
                               "signs in: the unverified registrant keeps access"))
        elif unexplained:
            out.append(Verdict("T5", CASES["T5"], "FAIL",
                               f"{len(unexplained)} sign-in(s) failed with an unrecognised code, which is not evidence of safety"))
        elif pending:
            out.append(Verdict("T5", CASES["T5"], "BLOCKED",
                               f"{len(pending)} sign-in(s) reached the seeded user: test whether the original password "
                               "still works (record --case T5P)"))
        else:
            out.append(Verdict("T5", CASES["T5"], "PASS",
                               f"{len(separate)} kept separate or refused; {len(mitigated)} linked with the original password "
                               "no longer working"))

    # T6: for a verified account the same person owns both identities, so linking is a policy question, not a takeover:
    # it must not happen implicitly.
    seeds = {d: x for d, x in seeded.items() if x.get("kind") == "verified"}
    runs = [r for r in of("T6") if r.get("email_sha256") in seeds]
    if not seeds or not runs:
        out.append(Verdict("T6", CASES["T6"], "BLOCKED",
                           "needs a seeded verified email/password account and a social sign-in with that email"))
    else:
        breaches = [r for r in runs
                    if (r["outcome"] == "ok" and r.get("user_id") == seeds[r["email_sha256"]]["user_id"])
                    or (r["outcome"].startswith("rejected:") and r["outcome"].split(":", 1)[1] not in REFUSAL_CODES)]
        out.append(Verdict("T6", CASES["T6"], "FAIL" if breaches else "PASS",
                           f"{len(breaches)} sign-in(s) linked implicitly or failed with an unrecognised code" if breaches
                           else f"{len(runs)} sign-in(s) did not link implicitly"))

    # T7: same provider identity across platforms.
    t7 = [r for r in of("T7") if r["outcome"] == "ok"]
    by_identity: dict[tuple[str, str], dict[str, set[str]]] = {}
    for r in t7:
        by_identity.setdefault((r["provider"], r.get("email_sha256", "")), {}).setdefault(r["platform"], set()).add(r["user_id"])
    pairs = {k: v for k, v in by_identity.items() if {"ios", "android"} <= set(v)}
    if not pairs:
        out.append(Verdict("T7", CASES["T7"], "BLOCKED", "needs the same identity signed in on both iOS and Android"))
    else:
        bad = [k for k, v in pairs.items() if len(v["ios"] | v["android"]) != 1]
        out.append(Verdict("T7", CASES["T7"], "FAIL" if bad else "PASS",
                           f"{len(bad)} identity(ies) resolved to different users" if bad
                           else f"{len(pairs)} identity(ies) matched across platforms"))

    # T8: operator confirms the dialog's sign-out line for each successful run.
    t8 = of("T8")
    if not t8:
        out.append(Verdict("T8", CASES["T8"], "BLOCKED", "no sign-out confirmation recorded"))
    else:
        bad = [r for r in t8 if r["outcome"] != "signed_out"]
        out.append(Verdict("T8", CASES["T8"], "FAIL" if bad else "PASS",
                           "a probe run did not sign out" if bad else f"{len(t8)} run(s) signed out"))
    # T9: every seeded account, and every account a social sign-in created, must be confirmed gone.
    t9 = of("T9")
    if not t9:
        out.append(Verdict("T9", CASES["T9"], "BLOCKED", "no cleanup recorded"))
    else:
        bad = [r for r in t9 if r["outcome"] != "deleted"]
        missing = [d for d in seeded if d not in {r.get("email_sha256") for r in t9}]
        out.append(Verdict("T9", CASES["T9"], "FAIL" if bad else ("BLOCKED" if missing else "PASS"),
                           f"{len(bad)} account(s) still exist" if bad
                           else (f"{len(missing)} seeded account(s) not confirmed deleted" if missing
                                 else f"{len(t9)} account(s) confirmed deleted")))
    return out


# ---- commands -------------------------------------------------------------------------------------------------

def _http(method: str, url: str, body: dict | None = None, headers: dict | None = None) -> tuple[int, dict]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json", **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except ValueError:
            return e.code, {}


def cmd_status(_: argparse.Namespace) -> int:
    url = probe_url()
    status, body = _http("GET", f"{url}/ok")
    print(f"probe auth: {urlparse(url).hostname}  /ok -> HTTP {status} {body if status == 200 else ''}")
    cred = Path.home() / ".config/neon/credentials.json"
    if not cred.exists():
        print("Neon API: not signed in (run `neon auth`); provider configuration not checked")
        return 0
    token = json.loads(cred.read_text()).get("access_token", "")
    api = f"https://console.neon.tech/api/v2/projects/{PROBE_PROJECT_ID}"
    s, branches = _http("GET", f"{api}/branches", headers={"Authorization": f"Bearer {token}"})
    if s != 200:
        print(f"Neon API: HTTP {s} (sign in again with `neon auth`); provider configuration not checked")
        return 0
    default = next(b for b in branches["branches"] if b.get("default"))
    s, providers = _http("GET", f"{api}/branches/{default['id']}/auth/oauth_providers", headers={"Authorization": f"Bearer {token}"})
    ids = sorted(p.get("id", "?") for p in providers.get("providers", [])) if s == 200 else f"HTTP {s}"
    print(f"Neon API: probe branch {default['id']} oauth providers: {ids}")
    return 0


def cmd_seed(args: argparse.Namespace) -> int:
    url = probe_url()
    password = getpass.getpass("Password for the disposable probe account (not echoed, not stored): ")
    if len(password) < 8:
        sys.exit("Use at least 8 characters.")
    status, body = _http("POST", f"{url}/sign-up/email", {"email": args.email, "password": password, "name": ""},
                         headers={"Origin": f"https://{urlparse(url).hostname}"})
    if status != 200:
        sys.exit(f"sign-up refused: HTTP {status} code={body.get('code', '-')}")
    user = body.get("user") or {}
    if not user.get("id"):
        sys.exit("sign-up returned no user")
    verified = bool(user.get("emailVerified"))
    kind = "verified" if verified else "unverified"
    if kind != args.kind:
        print(f"note: the account is {kind}, not {args.kind}; it is recorded as {kind}")
    data = load_results(args.results)
    data["seeded"][email_digest(args.email)] = {"user_id": user["id"].lower(), "kind": kind,
                                                "at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    save_results(args.results, data)
    print(f"seeded {kind} account user={user['id'].lower()} email_sha256={email_digest(args.email)[:12]}…")
    return 0


def cmd_seed_record(args: argparse.Namespace) -> int:
    """Records an account created by hand in the app (production testing): no network, nothing is created here."""
    data = load_results(args.results)
    data["seeded"][email_digest(args.email)] = {"user_id": args.user_id.lower(), "kind": args.kind,
                                                "at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    save_results(args.results, data)
    print(f"recorded {args.kind} seed user={args.user_id.lower()} email_sha256={email_digest(args.email)[:12]}…")
    return 0


def cmd_record(args: argparse.Namespace) -> int:
    if args.case not in CASES and args.case not in EVIDENCE_CASES:
        sys.exit(f"unknown case {args.case}; one of {', '.join([*CASES, *EVIDENCE_CASES])}")
    if args.outcome == "ok" and not args.user_id:
        sys.exit("--outcome ok needs --user-id (from the app's probe dialog)")
    rec = {"case": args.case, "platform": args.platform, "provider": args.provider, "outcome": args.outcome,
           "user_id": (args.user_id or "").lower() or None,
           "email_sha256": email_digest(args.email) if args.email else None,
           "email_is_relay": bool(args.email and args.email.lower().endswith("@privaterelay.appleid.com")),
           "at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    data = load_results(args.results)
    data["records"].append(rec)
    save_results(args.results, data)
    print(f"recorded {args.case} {args.platform}/{args.provider} outcome={args.outcome}")
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    verdicts = evaluate(load_results(args.results))
    for v in verdicts:
        print(f"{v.status:<8} {v.case}  {v.title}\n           {v.detail}")
    if any(v.status == "FAIL" for v in verdicts):
        print("\nRESULT: FAIL — social sign-in must not ship.")
        return 1
    if any(v.status == "BLOCKED" for v in verdicts):
        print("\nRESULT: INCOMPLETE — blocked cases are not evidence of safety.")
        return 2
    print("\nRESULT: all cases passed on the probe.")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--results", type=Path, default=DEFAULT_RESULTS)
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    s = sub.add_parser("seed-unverified", help="create a disposable email/password account on the probe (operator)")
    s.add_argument("--email", required=True)
    s.add_argument("--kind", choices=["unverified", "verified"], default="unverified")
    sr = sub.add_parser("seed-record", help="record an account created by hand in the app; nothing is created")
    sr.add_argument("--email", required=True)
    sr.add_argument("--user-id", required=True)
    sr.add_argument("--kind", choices=["unverified", "verified"], default="unverified")
    r = sub.add_parser("record")
    r.add_argument("--case", required=True)
    r.add_argument("--platform", required=True, choices=["ios", "android"])
    r.add_argument("--provider", required=True, choices=["google", "apple"])
    r.add_argument("--outcome", required=True, help="ok | cancelled | signed_out | deleted | still_exists | password_ok | password_rejected | rejected:<CODE>")
    r.add_argument("--user-id")
    r.add_argument("--email", help="as shown in the app dialog; stored only as SHA-256")
    sub.add_parser("report")
    args = p.parse_args(argv)
    return {"status": cmd_status, "seed-unverified": cmd_seed, "seed-record": cmd_seed_record,
            "record": cmd_record, "report": cmd_report}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
