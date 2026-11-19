# Social sign-in security probe — runbook

**Scope:** MoveMark Consumer, `feature/social-welcome`. This decides whether "Continue with Google / Apple" may
ever reach real accounts.

**Target:** the isolated Neon Auth probe project `movemark-auth-probe` (`shy-lake-41996372`), and nothing else.
Its auth base is `https://ep-long-bird-bd8ytm19.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth`. It has its own
users table and JWKS, and no MoveMark schema or data.

**Ship rule:** if any social sign-in reaches an existing account it does not own (T5 or T6 FAIL), and Neon gives no
setting that prevents it, social sign-in does not ship. A BLOCKED case is not evidence of safety.

## Production testing (owner decision, 2026-11-06)

Testing moved from the probe to Consumer production (`suren` / `production`), using **disposable accounts the owner
controls**. Production provider settings are not changed, and no existing account is touched.

- **Build:** a Debug build on the owner's iPhone, launched with `-MoveMarkSocialLive YES`. This is a real session against
  production. Release builds never show the buttons.
- **Local config:** `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_REVERSED_CLIENT_ID` in
  `Config/Secrets.xcconfig`.
- **T5 setup:** create the unverified account by hand in the app (email/password), note its Neon user id, then
  `probe.py seed-record --email E --user-id <id>`. `seed-unverified` stays probe-only: the harness never writes to production.
- **Cleanup:** delete each disposable account through the app's Delete account flow.

The sections below describe the same cases; only the target differs.

## 0. Gates before anything runs

| Gate | Status today |
|---|---|
| Neon CLI signed in (`neon auth`, by the owner) | Needed for `probe.py status` and provider setup |
| Google: a working web client secret on this Mac | **Blocked.** `~/.movemark-social/google_web_client_secret` holds a client id, not a secret |
| Apple: a Sign in with Apple key that was never exposed | **Blocked.** The only key on file (BD7LL3X2NJ) was exposed; owner decision: don't use it |
| Android OAuth client for the debug build | Not created (see §5) |
| Providers configured on the **probe** branch | Not done; needs the two credential rows above |

Until the provider rows clear, only the offline parts (harness unit tests, UI, request shape) are verified.

## 1. Tools

- **Harness:** `scripts/social-probe/probe.py`, stdlib Python. Its tests are `scripts/social-probe/test_probe.py`.
  - It stores only user ids, outcomes and SHA-256 email digests. It never stores tokens, cookies, passwords or
    email addresses.
  - Results default to `/Volumes/sss/movemark/_scratch/social-probe-results.json` (mode 0600). Override with
    `--results`.
- **iOS Debug build:** launch with
  `-MoveMarkSocialProbeAuthURL https://ep-long-bird-bd8ytm19.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth`
  (Scheme → Run → Arguments).
  - Google also needs `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_REVERSED_CLIENT_ID` in the
    gitignored `Config/Secrets.xcconfig` (see the `.example` file).
  - Release clears all of them, and the buttons never appear.
- **Android debug build:** set `SOCIAL_PROBE_AUTH_URL` and `GOOGLE_WEB_CLIENT_ID` in `movemark-android/local.properties`.
  Release hard-codes both to empty.
- **What the app shows:** after each probe sign-in it shows *Neon user*, *Email* and "Signed out of the probe".
  A refusal shows the server's code in brackets, e.g. `[ACCOUNT_NOT_LINKED]`. Copy those values into `record`.
  Never paste them into chat or a ticket.

```sh
export SOCIAL_PROBE_AUTH_URL=https://ep-long-bird-bd8ytm19.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth
export MOVEMARK_APP_AUTH_HOSTS=<dev branch neonauth host>   # the harness also refuses production's host itself
python3 scripts/social-probe/probe.py status                # read-only: /ok + configured provider ids
```

## 2. Provider setup (probe branch only, once the gates clear)

- **Google:** in the console, add the redirect URI `…/neondb/auth/callback/google` to the web client. Then add the
  web client id and secret to the probe branch (Neon Console → Auth → OAuth, or `neon neon-auth oauth-provider add`).
- **Apple:** use a Services ID whose return URL is `…/neondb/auth/callback/apple`. Add a non-exposed `.p8`, the
  Team ID and the Key ID.
- **Record:** note the Better Auth version Neon reports, and whether any account-linking setting is exposed. The
  self-hosted equivalent is `account.accountLinking.disableImplicitLinking`. Better Auth releases before 1.6.11 (and
  early 1.7 prereleases) had a pre-account-hijack advisory; email verification alone did not prevent it.

## 3. Test cases

Run every case on both platforms where it applies. After each run, record what the app showed.

| Case | Steps | Record |
|---|---|---|
| **T1** first-time | A provider identity never used on the probe → Continue with Google/Apple | `record --case T1 --platform ios --provider google --outcome ok --user-id <id> --email <email>` |
| **T2** returning | The same identity again | `--case T2 … --user-id <id>` (must equal T1's) |
| **T3** Hide My Email | Apple → "Hide My Email", twice | `--case T3 --provider apple … --email <relay address>` |
| **T4** cancel | Open the sheet, then close it | `--case T4 --outcome cancelled` (no user id) |
| **T5** takeover (unverified) | ① Create an unverified email/password account with address E (a disposable identity you control) and note its user id. ② Sign out. ③ Sign in with Google/Apple whose account email is E. ④ If that reached the same user id, sign out and **try the original password**. | ③ `--case T5 … --outcome ok --user-id <id> --email E`, or `--outcome rejected:<CODE> --email E`. ④ `--case T5P … --outcome password_ok\|password_rejected --email E` |
| **T6** implicit link (verified) | As T5, but verify E first (probe email delivery permitting), seeded with `--kind verified` | `--case T6 …` |
| **T7** cross-platform | The same Google identity on iOS, then on Android (Apple on Android once its browser flow exists) | `--case T7` once per platform |
| **T8** sign-out | For each successful run, sign out and confirm the app returns to Welcome | `--case T8 --outcome signed_out` |
| **T9** cleanup | Delete every disposable account, then confirm: signing in with it must fail | `--case T9 --outcome deleted\|still_exists --email E` |

**Seeding** (`seed-unverified`) is the only step that creates an account. The owner runs it, against the probe only.
It asks for a password without echoing it and stores nothing but the user id and the email digest.

```sh
python3 scripts/social-probe/probe.py report   # exit 0 all pass · 1 any FAIL · 2 anything BLOCKED
```

**Interpretation:**
- **T5 FAIL:** the social sign-in linked to the seeded account and the original password still signs in, so whoever
  registered the email keeps access to the real owner's vault; or it failed with an unrecognised code. Stop. Social
  sign-in does not ship unless Neon offers a control that turns the result into PASS on a re-run.
- **T5 BLOCKED after a link:** the same user id alone is not a verdict. Test the original password (T5P).
- **T5 PASS:** kept as a separate user, refused with a recognised code (ACCOUNT_NOT_LINKED, LINKING_NOT_ALLOWED, …), or
  linked with the original password no longer working.
- **T6 FAIL:** a verified account was linked implicitly. Not a takeover, since one person owns both identities, but it
  breaks the rule that linking needs the user's approval, so it stays a release decision.
- **T7 FAIL:** iOS and Android disagree on the user for the same identity. Investigate before any further work.

## 4. Native-token audience (decides iOS Apple)

- **iOS Apple:** native Sign in with Apple tokens carry `aud` = the bundle id `movemark.movemork`, not the Services
  ID. If Neon rejects them (T1 on iOS Apple fails with an audience or token error), iOS Apple needs the browser flow
  that Android needs too.
- **Google:** native tokens carry `aud` = the web client id (via `serverClientID` / Credential Manager's
  `serverClientId`), which is what the probe's Google provider is configured with.

## 5. Android OAuth client (Google Cloud → Auth Platform → Clients → Create → Android)

| Field | Value |
|---|---|
| Package name | `com.surensureshkumar.movemark` (debug has no applicationId suffix) |
| SHA-1 (this Mac's debug keystore) | `B7:E4:A2:18:6E:D1:25:7F:EF:55:C8:28:9F:AE:E7:B7:2D:76:DF:66` |
| Release / Play | Add separate clients later: the upload-key SHA-1 and Play App Signing's SHA-1 |

- No secret is involved. Credential Manager asks for the **web** client id (`GOOGLE_WEB_CLIENT_ID`), and Google
  matches the calling app by package and signature against this Android client.
- While the consent screen is in Testing, add every test Google account as a test user.

## 6. Cleanup

- Delete seeded and test users from the probe (Neon Console → Auth → Users) after each round.
- Remove the results file.
- Remove the probe providers when the probe is retired.
- None of this touches dev or production.
