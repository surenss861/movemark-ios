# MoveMark Consumer: unknown legal facts, decisions and conflicts

Working paper for the owner and the reviewing Ontario technology/privacy lawyer. It goes with `terms-of-service.md` and `privacy-policy.md`, and is not for publication.

**Prepared:** 2026-11-07, from a read of the code only. No database, dashboard, live site or credential was used.

**What was read**

- iOS and Android: `wt-legal-gate`, branch `feature/legal-gate` at `2f318c7`. This branch is ahead of the build in TestFlight (1.4 build 20261106.2).
- API: `movemark-api-py`, branch `recovery/neon-api` at `aeba6d6`. That commit is one ahead of `origin`, so it is not confirmed live.
- Schema: `neon/migrations` through 1020. Operations docs in `docs/` and `neon/`.
- Backup code: `scripts/dr`.
- `account-site`.

**What was not checked**

- `movemark-web` (movemark.ca) was deliberately not opened, per the brief. Its analytics, cookies and forms are unknown (U11).
- Provider dashboards. Facts about B2 lifecycle rules, Neon retention and the email sender come from repo docs, not live settings.
- Whether the Apple and Google store listings or privacy labels match these drafts.

**Key to the brackets in the drafts:** `[UNKNOWN: …]` = section A. `[LAWYER DECISION: …]` = section B. `[CONFLICT C#: …]` = section C.

---

## A. Unknown facts

| # | Unknown | Why it matters | Who can answer |
|---|---|---|---|
| U1 | Legal name of the operating business, and whether it is incorporated. The Android package uses the owner's name; no entity appears in the code. | Identifies the contracting party and the organization accountable under PIPEDA. It also has to match the Apple and Google seller name. | Owner, accountant |
| U2 | Mailing address | Expected in the Terms and privacy contact. Apple, Google and consumer law may require one. | Owner |
| U3 | Designated privacy officer (name or title) | PIPEDA requires someone to be accountable, and their contact details to be available on request. Quebec requires publication if in scope. | Owner |
| U4 | Effective date, and the final public URLs of both documents | Currently Notion links in the apps (C15). | Owner |
| U5 | Countries and provinces at launch. The app says "For Ontario apartment renters" (`MoveMarkGrowthCopy.swift`); the brief says Canada. | Decides whether Quebec law (Law 25, French language) and BC/Alberta PIPA apply. | Owner |
| U6 | Are there existing users on earlier versions? What happened to their data when the Supabase project was deleted (2026-10), and which terms did they accept? | New terms may need fresh consent. Lost data could raise notice questions. | Owner |
| U7 | Retention period for inactive accounts, old reports and deleted-account backups | No such period exists in code. PIPEDA expects retention limits and documented maximums. See C1, C12. | Owner with lawyer |
| U8 | Railway region, and Railway log retention | Needed for the transfer notice and retention table. Logs hold account IDs and, on rate-limit events, IP addresses. | Owner (Railway dashboard) |
| U9 | Production B2 endpoint. `docs/disaster-recovery.md` records `us-east-005`; `offsite.py` defaults mention `us-west-004`. Also whether the lifecycle rules in the doc are really set. | Transfer notice and retention table. | Owner (B2 dashboard) |
| U10 | Current production email sender. `docs/database-production-readiness.md:46` says Neon's shared sender remains "until Postmark is configured". No code or config shows Postmark in use. | Decides whether Postmark is listed. Password-reset emails carry the user's email address and a token. | Owner (Neon Auth console) |
| U11 | Does movemark.ca use analytics, cookies, forms or a waitlist? Is it on Vercel? (Project notes say yes; not verified here.) | The Privacy Policy may need a website section. Cookie rules may apply. | Owner, or a read of `movemark-web` |
| U12 | Does Neon Auth store IP address and user agent on sessions? Better Auth normally can; nothing in this repo confirms it for this deployment. | Would be a further collected data type. | Owner (Neon docs, or read-only schema check) |
| U13 | Retention at Sentry, RevenueCat and Titan, and how user deletion works at each | Retention table, and C7. | Owner (dashboards, provider docs) |
| U14 | Do signed data processing agreements exist with Neon, Railway, Backblaze, RevenueCat, Sentry, Vercel and Titan? What do their terms say about sub-processors and location? | PIPEDA keeps MoveMark accountable for data sent to processors. The policy says contracts give comparable protection, and that must be true. | Owner, lawyer |
| U15 | Encryption at rest at Neon, Railway Redis and Sentry | The draft makes no claim on this until confirmed. | Owner (provider docs) |
| U16 | Is Android launching with iOS? Is a Sentry DSN set in release Android builds? (It comes from `local.properties`.) Which app store account publishes it? | Billing wording, crash-reporting disclosure and the Data Safety form. | Owner |
| U17 | Is Sign in with Apple/Google live at launch? On for TestFlight only in `SocialSignIn.swift`; off in Android release. | If not live, remove the paragraph in Privacy section 7. | Owner |
| U18 | Final plans, Canadian prices, trial or introductory offers, and whether credits expire. No trial code exists. `MoveMark.storekit` holds test values only. | Consumer disclosure and paywall accuracy. Who collects GST/HST also matters. | Owner, accountant |
| U19 | Is it a lasting commitment that user content is never sold, never used for advertising, never used to train models, and never viewed by staff except for support, security or legal reasons? | The code supports these today. A policy turns them into promises. | Owner |
| U20 | Breach response: who decides, who notifies, where the breach log is kept | Required under PIPEDA (notify the OPC and affected people when there is a real risk of significant harm; keep records of all breaches). `docs/security` covers technical items only. | Owner, lawyer |
| U21 | Process for access, correction and deletion requests by email: identity check, owner, timing | See C13. | Owner |
| U22 | Suspension and takedown process. `app/auth.py` rejects tokens for banned users, but no procedure or admin tool is documented. | Terms section 13. | Owner |
| U23 | How users will be told about changes to the policy or Terms. No notification system exists. | The drafts promise notice of material changes. | Owner |
| U24 | Ownership of the MoveMark name and any trademark | Terms section 15. | Owner, lawyer |
| U25 | Titan as support mailbox. Known only from project notes. | If correct, Titan processes support mail, and should stay listed. | Owner |
| U26 | Password reset link lifetime. Set by Neon Auth; the app only says "it expires soon". | Retention table. | Owner (Neon Auth console) |
| U27 | Session behaviour: code comments say 7 days; whether it renews on use isn't shown. | Retention table. | Neon docs |
| U28 | Are tax or accounting records held that need separate retention? | Retention carve-out. | Accountant |

---

## B. Decisions for the lawyer

| # | Decision | Notes |
|---|---|---|
| L1 | Governing law and forum | Owner assumes Ontario. Mandatory consumer rights elsewhere may override it. |
| L2 | Limitation of liability, and any cap | No figure chosen. Check against the Ontario *Consumer Protection Act, 2002* (CPA), including limits on waiving implied warranties. Confirm whether the *Consumer Protection Act, 2023* is in force at launch. |
| L3 | Arbitration and class waiver | Left out of the draft because the CPA restricts them for consumers. |
| L4 | Indemnity in consumer terms | Drafted narrowly in section 18. May be better removed. |
| L5 | Minimum age | Ontario's age of majority is 18, but a younger person may hold a tenancy. Also affects consent, and the store age rating. |
| L6 | Form of acceptance and consent | Clickwrap, versioning, separate express consent for sensitive data and cross-border processing. See C4. |
| L7 | Is the GPS in originals justified? | See C3. Weigh evidence integrity against limiting collection. |
| L8 | Treatment of third parties' data | Roommates, landlords and tradespeople appear in photos and leases, and users enter landlord names, emails and phones. MoveMark holds this without those people's knowledge. Consider what the policy should say, and how to handle a request from such a person. |
| L9 | Auto-renewal, price-change and internet-agreement disclosure | CPA internet agreement rules, plus Apple and Google rules. |
| L10 | Quebec | Law 25 (privacy officer, transfer assessment, consent), and French-language rules for consumer contracts and apps. Decide whether to offer in Quebec at launch. |
| L11 | Custom EULA or Apple's standard EULA | Section 22 follows Apple's minimum terms as understood when drafted. Check the current version. |
| L12 | "Deposit" language | The product talks about protecting deposits, while Ontario limits what landlords may collect as deposits. Check copy doesn't mislead Ontario renters about their rights. Not a legal view, only a flag. |
| L13 | Disclosure to authorities and legal process | Whether to promise user notice. Note MoveMark holds evidence relevant to third parties' disputes, and could receive a subpoena or summons. |
| L14 | Suspension when a user has a live dispute | Cutting off access could harm a renter with a deadline. Consider a grace period for retrieval. |
| L15 | Whether "unlimited" reports is accurate, given the limit of 3 per hour per rental and type | Consider wording. |

---

## C. Where the code conflicts with what a policy should say

Ordered by severity. "Draft says" is how the documents handle it until it's resolved. **C1 to C5 should be treated as blockers to publication.**

### Blockers

**C1. "Permanently deleted" is not true for backups: file copies never expire. (High)**

- The app says your account, photos and stored evidence "will be permanently deleted" (`DeleteAccountView.swift:48`, `AccountHomeView.swift:156,317`; Android `AccountScreen.kt`).
- `offsite.py sync_evidence` copies objects into B2 and has **no delete path at all**. When a source object is removed, it just drops from the next manifest.
- `docs/disaster-recovery.md`: `objects/` is "not expired". So every photo, GPS-bearing original, lease and report ever uploaded stays in B2 indefinitely, encrypted, including after photo, rental or account deletion.
- Database backups, which include Neon Auth identities, last about 36 days, and each month's first backup lasts 365 days. Manifests listing bucket, key, size and hash last 400 days. Neon history lasts 7 days.
- Object Lock means nothing can be removed for 30 days, so immediate backup deletion is impossible by design.
- **Fix:** a pruning job for objects absent from the manifest once the lock lapses, or per-user encryption keys that can be destroyed. Set one stated maximum. Change app wording, for example "deleted from MoveMark; encrypted backups are removed within X days".
- **Draft says:** Privacy sections 10 and 11 state plainly that backups outlast deletion and have no end date yet.

**C2. A restore would bring deleted accounts back. (High)**

Nothing records deletions for replay after a restore (`scripts/dr/restore.py`, `docs/disaster-recovery.md`). Any account deleted after the chosen backup returns, including its sign-in identity. Backed-up files for accounts in that database remain available too.
**Fix:** keep a minimal deletion log outside the backup scope and re-apply it after any restore.
**Draft says:** disclosed in Privacy section 11.

**C3. Originals keep GPS and all other metadata, with no product use for it. (High)**

- `MMEvidenceImport.swift` header: the source "keeps all of its metadata, GPS included". Android `EvidenceImport.kt` is the same. Library picks reach the server as original bytes (`MMEvidencePicker.swift`).
- No code reads the GPS. No endpoint serves the source (`routers/storage.py` signs only `file_path` and `thumbnail_path`). A user can't see it or remove it short of deleting the photo. Sources are also mirrored to B2 (C1).
- Any statement like "we remove location data" is only true of working copies and thumbnails.
- Android's photo picker may redact location in some cases. Not verified.
- **Decision (L7):** keep byte-exact originals for evidence integrity and disclose this, or warn at import, or stop storing originals that carry GPS.
- **Draft says:** explained in Privacy section 4.

**C4. No real acceptance of Terms or consent. (High)**

- iOS has only a passive line "By continuing, you agree to Terms & Privacy" (`AuthContainerView.swift:409`).
- **Android sign-up shows no Terms or Privacy link at all.** They appear only in Account and the paywall.
- Neither app records acceptance. The schema has no accepted-at or version column (`profiles`).
- This weakens enforceability of the Terms and is a poor fit for sensitive data and cross-border consent.
- **Fix:** an acceptance step on both platforms, storing the version and time. Note the schema is under change control, so this needs a migration.

**C5. No age check. (High)**

No date of birth, age prompt or minimum-age copy anywhere in either app or the schema.
**Fix:** decide L5, then add at least a confirmation at sign-up.

### Important

**C6. Marketing and report wording claims more than the product proves. (Medium-High)**

- Copy: "Prove what was already there", "Document now. Prove it later.", "timestamped report", "Build a dispute-ready packet", "Don't get blamed for damage you didn't cause", "Private evidence" (`MoveMarkGrowthCopy.swift`, `PaywallReason.swift`). The trust line "Private evidence" also sits awkwardly with data that isn't end-to-end encrypted.
- PDF captions print `capturedAt or createdAt` with no label (`pdf.py:_photo_caption_lines`). A reader can't tell a file-declared time, which isn't verified (migration 0940, `MMEvidenceImport.swift`), from MoveMark's receipt time. A library photo looks the same as a camera photo. The fingerprint isn't printed.
- **Fix:** label each time as "from file" or "received by MoveMark", and show the source. Have the lawyer review the copy. The PDF disclaimer itself (`pdf.py` `DISCLAIMER`) is good.
- **Draft says:** Terms sections 3 and 7.

**C7. Deletion doesn't reach third parties. (Medium)**

`delete_account.py` touches only Postgres, Object Storage, Neon Auth and the cache. Nothing deletes the RevenueCat subscriber, Sentry events or Railway logs. App wording suggests everything goes.
**Fix:** call RevenueCat's delete-subscriber API, and describe the rest.
**Draft says:** Privacy section 11.

**C8. Android doesn't warn that deletion leaves a subscription running. (Medium)**

The iOS screen says so, and mentions Report Pack credits. The Android dialog (`AccountScreen.kt`, "This permanently deletes…") mentions neither. There's also an Android "Account & Data Deletion" row, "Request account removal", that opens a Notion page, alongside the in-app delete.
**Fix:** match the iOS wording. Replace the Notion link.

**C9. Some cached data survives sign-out and deletion on the device. (Medium)**

- iOS: `DeleteAccountView.swift` has the comment "Nothing of the account stays on this iPhone", but neither the Nuke cache (`com.movemark.evidence`, up to 400 MB, `MMEvidenceImage.swift`) nor `MMImageCache` (`MMCachedAsyncImage.swift`) is cleared anywhere. Cached copies of evidence photos stay on a shared phone until iOS evicts them.
- Android: `LocalUserFiles` clears reports, documents and captures, but no code clears Coil's disk cache. `DisputeDraftStore` has no clear path.
- **Fix:** purge both on sign-out and deletion.
- **Draft says:** Privacy section 11 flags it.

**C10. Reports can't be deleted individually, and deleted photos live on in them. (Medium)**

No delete route exists for exports (`routers/exports.py`), users have only SELECT on `exports` (migration 0960), and `_delete` in `routers/storage.py` leaves existing PDFs alone. Only account deletion removes them.
**Fix:** add report deletion.
**Draft says:** Privacy section 11, Terms section 9.

**C11. Delete rental isn't shipped. (Medium)**

`DELETE /api/properties/{id}` is in local commit `aeba6d6`, not on `origin`. Neither client on this branch has any UI for it. Migration 1020 is on production per project notes. If it ships, note that storage failures are logged, not retried (`delete_property.py`), so a rental can disappear from the app while some files remain.
**Draft says:** left out behind an `[UNKNOWN]`.

**C12. No retention schedule. (Medium)**

The worker sweeps only abandoned uploads and stuck export jobs. Inactive accounts and old reports live forever.
**Fix:** set a policy (U7), and implement it with a warning email.

**C13. No self-serve export, and originals can't be obtained. (Medium)**

No endpoint exports a whole account, or serves originals. PIPEDA access requests would need manual work with production access. Terms section 13 also promises time to save records if the service closes.
**Fix:** build an export, or at least document a manual procedure.

**C14. Emails aren't verified. (Medium)**

Production Neon Auth doesn't require verification (`docs/production-security-gate.md`, finding 8, "accepted until Gate 3"). Someone could sign up with another person's email. A privacy notice or reset email could reach the wrong person, and account-holder identity checks for rights requests are weak.
**Fix:** turn on verification with the production sender.

**C15. Stale contact details and legal links in shipped code. (Medium)**

- `support@movemark.app`: `Info.plist` `LegalSupportEmail`, Android `AccountViewModel.kt` `SUPPORT_EMAIL`. Canonical address is `connect@movemark.ca`. Confirm whether movemark.app is even controlled.
- All Terms, Privacy, Support and Deletion links point at Notion pages with old text (`Info.plist`, `AccountViewModel.kt`, `docs/app-review.md`). The old text says Apple handles all billing and deletion is by request to support. Neither is true now.
- **Fix:** move URLs to movemark.ca. App Store Connect and Play Console must match.

**C16. Who can reach production data isn't settled. (Medium)**

- `docs/production-access-audit.md` records SQL run on production through the Neon console, as the owner, on 2026-10-22, by an actor the audit couldn't identify ("a person, a browser agent… or Neon's in-console assistant"). Project notes confirm the console as the source, not who drove it.
- Two forensic Neon branches of production were kept. They hold copies of production data outside any deletion flow.
- `backup.py` can also write local archives (`~/.movemark-dr/backups`).
- Production credentials exist on the development machine, where AI coding tools run.
- **Fix:** before stating that access is restricted, close this out, delete the forensic branches, and write down who can access what.
- **Draft says:** no claim made. Marked in Privacy section 13.

**C17. Device backups differ by platform. (Low-Medium)**

- iOS pending originals are "included in device backups" (`PendingEvidenceStore.swift`), including GPS, and use until-first-unlock protection.
- Android excludes pending photos and shared preferences, but `backup_rules.xml` and `data_extraction_rules.xml` don't exclude the Room cache `movemark_cache.db` (rental snapshots) or DataStore (dispute drafts). With `allowBackup="true"`, these may reach the user's Google backup. This is inferred from the rules, not tested.
- **Fix:** exclude them, or disclose it.

### Lower priority

**C18. Sentry detail. (Low)**

- Only the worker calls `init_sentry()`. The API process never does, so `capture_exception` there does nothing, and API errors go only to Railway logs.
- The worker sets no `send_default_pii` (default off) and doesn't turn off local-variable capture, which is on by default in the Python SDK as far as I know. A failed PDF job could send address or notes fragments. Please verify.
- iOS relies on defaults for screenshots and view hierarchy. Android turns them off explicitly.
- The Sentry organization is named after another of the owner's products. If that's a different legal entity, check the account owner matches U1.

**C19. "Analytics" isn't what its name suggests. (Low)**

`MoveMarkAnalytics` writes to the on-device log only (`OSLog`, plus a local history in DEBUG). Nothing is sent anywhere. Android has no analytics. The privacy statement is correct, but will be false the moment a provider is wired into `track()`. Store privacy labels should match.

**C20. Leftovers that could mislead a reviewer. (Low)**

- `aps-environment` entitlement and `remote-notification` background mode are declared, but no push code exists.
- `supabase-swift` remains linked, used as a generic client against Neon. Supabase isn't a processor now.
- A gitignored local `Config/Secrets.xcconfig` holds old Facebook identifiers, which no code uses. Values aren't reproduced here; rotate or remove them.
- The Node `movemark-api` and Railway `movemark-exports` bucket appear in project notes. Confirm they're retired and hold no user data.

**C21. Links that work for anyone who has them. (Low)**

Signed download URLs are bearer links: photos for 1 hour, reports for 15 minutes. The report link is cached in Redis for up to 14 minutes. Password-reset tokens appear in the URL requested from Vercel before the page removes them, so they may reach Vercel's request logs, though they're single-use and short-lived.

**C22. Report Pack refunds aren't handled. (Low)**

Webhook code grants credits on purchase, and ignores other Report Pack events. A refunded pack keeps its credit. The draft doesn't say otherwise.

**C23. Possible late report after deletion. (Low, inferred, untested)**

A report job already running when an account is deleted could upload its PDF after storage cleanup (`export_job_processor.py`). The file would stay in live storage with no row or owner, and be mirrored to B2.

---

## D. Third parties: what the code proves

### Confirmed processing user data

| Provider | Proof |
|---|---|
| Neon Postgres + Data API | `MoveMarkApp.xcconfig`; `movemark-android/app/build.gradle.kts` (prod URLs, aws us-east-2); `neon/migrations` |
| Neon Auth | `movemork/Data/Backend/NeonAuthClient.swift`; `movemark-api-py/app/auth.py` |
| Neon Object Storage | `movemark-api-py/app/object_store.py`; default region us-east-2 |
| Railway (API, worker, backup cron) | `build.gradle.kts` (`up.railway.app`); `movemark-api-py/railway.toml`; `scripts/dr/railway.toml` |
| Redis | `movemark-api-py/app/redis_client.py`, `cache.py`, `middleware/rate_limit.py`. That it runs on Railway comes from project notes only. |
| RevenueCat | `movemork/Stores/SubscriptionManager.swift`; Android `RevenueCatSubscriptionBilling.kt`; `app/routers/webhooks.py`; `app/services/revenuecat_refresh.py` |
| Apple App Store and Google Play billing | Via RevenueCat above; `docs/app-review.md`; `PlaySubscriptionIntents.kt` |
| Sentry | `movemork/movemorkApp.swift` (US ingest host); Android `core/CrashReporting.kt`; `movemark-api-py/worker.py` + `app/observability.py` |
| Backblaze B2 | `scripts/dr/offsite.py`, `run_scheduled.sh`, `docs/disaster-recovery.md` |
| Vercel (account.movemark.ca) | `account-site/vercel.json`, `account-site/.vercel/project.json` |

### Present but not live for customers

| Provider | Proof | State |
|---|---|---|
| Sign in with Apple, Google | `movemork/Features/Auth/SocialSignIn.swift`; Android `features/auth/social/SocialSignIn.kt` | TestFlight only on iOS. Debug only on Android. |

### Not confirmed, or not a processor

| Service | Finding |
|---|---|
| Postmark | **Not confirmed.** A single doc line says it isn't configured yet. No code. |
| Analytics vendors | **None.** `MoveMarkAnalytics` is on-device only. No analytics or advertising SDK in either app's dependencies. |
| AI or image analysis | **None.** The API's only outbound calls are to Neon, Redis and RevenueCat. |
| Titan | Project notes only. Listed in the policy with a flag (U25). |
| Supabase | Deleted. SDK is only a client library pointed at Neon. |
| Facebook | Stale local config only. Not used. |
| Nuke, Coil | Local image libraries. No data leaves the device through them. |

### Hosting regions the code shows

- Neon: AWS us-east-2 (United States).
- Sentry iOS: US ingest.
- B2: us-east-005 per the recovery doc (U9).
- Railway, Redis, RevenueCat, Vercel, Titan: not shown.
