# MoveMark Consumer: Canadian launch checklist

Prepared 2026-11-07. This is an engineering and operations baseline, not a legal opinion. It doesn't say MoveMark meets any law. It says what was checked and what was found. Starting point: `docs/legal/unknown-legal-facts.md` (C#, U#, L# refer to it).

**Read:** `wt-legal-gate` (`feature/legal-gate`, `bfd590b`), `wt-api-legal-gate` (`feature/legal-gate`, `823c787`, written `API:` below), `movemark-web` (`8f17dd3`, written `web:`).

**Not done:** no test suite was run, and no database, dashboard, live site, credential or store console was used. Test claims come from reading tests and recorded results. Passing tests are evidence about the cases they cover, nothing more.

**One thing was run locally:** a synthetic JPEG and PNG carrying GPS EXIF went through the API's own embed functions and reportlab (Pillow 12.3.0, reportlab 5.0.0). See P0-6.

**Status words:** *Verified issue* = seen in code or docs. *Potential risk* = plausible, not proven. *Owner decision* = no defect, a choice is missing. "(excerpt)" = the official page was read through a search excerpt, not in full. Other official pages were fetched through a summarizing tool, so check exact wording before quoting any of them publicly.

## P0: launch blockers

| # | Item | Status | Owner |
|---|---|---|---|
| 1 | Backup copies of files never expire | Verified issue | Owner, Engineering |
| 2 | A restore brings deleted accounts back | Verified issue | Engineering |
| 3 | "Permanently deleted" copy; deletion doesn't reach RevenueCat; Android omits subscription warning | Verified issue | Engineering |
| 4 | Two conflicting policies; stale links and support address | Verified issue | Owner, Engineering |
| 5 | No working acceptance of Terms | Verified issue | Engineering |
| 6 | Image documents keep GPS in the files users open | Verified issue (new) | Engineering |
| 7 | GPS in originals has no decision or notice at import | Verified issue, owner decision | Owner, Lawyer |
| 8 | Printed times don't say what they are; two can be set by the client | Verified issue (partly new) | Engineering, Owner |
| 9 | Android paywall has no renewal or cancellation disclosure | Verified issue (new) | Engineering |
| 10 | No age position; three documents disagree | Verified issue | Owner |
| 11 | No breach process or breach log | Verified issue | Owner |
| 12 | Operator name and privacy officer not set | Owner decision | Owner |
| 13 | Processor contracts and settings unconfirmed | Potential risk | Owner |
| 14 | Store privacy labels and Data safety not reconciled | Potential risk | Owner |
| 15 | Quebec can't be excluded by storefront, and the app is English only | Verified issue, owner decision | Owner, Lawyer |
| 16 | No written process for privacy requests | Verified issue | Owner |
| 17 | Isolation evidence predates the release; some tables untested end to end | Potential risk | Engineering |
| 18 | Social sign-in linking unproven (blocks only if social ships) | Potential risk | Owner, Engineering |

### P0-1. Offsite file backups have no end date

- **What:** `sync-evidence` only adds to B2. A deleted object drops from the next manifest and stays in `objects/` for good, encrypted, including originals with GPS. Monthly DB backups last 365 days, and manifests (user-id paths and hashes) 400.
- **Why:** PIPEDA expects minimum and maximum retention periods and disposal when no longer needed ([OPC Principle 5](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/principles/p_use/)). In March 2026 the OPC said effective anonymization "must include ensuring that information is also removed from back-up systems", and faulted Loblaw for not showing a process ([PIPEDA Findings #2026-001, ¶39](https://www.priv.gc.ca/en/opc-actions-and-decisions/investigations/investigations-into-businesses/2026/pipeda-2026-001/)). That finding concerns anonymization, but its reasoning is the closest OPC statement on backups found. Apple requires the policy to explain retention and deletion ([5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/)).
- **Status:** Verified issue. Whether the B2 lifecycle rules are really set is unverified (U9).
- **Evidence:** `scripts/dr/offsite.py` (`sync_evidence`, no delete path); `docs/disaster-recovery.md` ("objects/ not expired"); `docs/legal/privacy-policy.md` section 10.
- **Fix:** Pick one maximum for all backups (proposal: 90 days; it can't go below the 30-day Object Lock). Add a prune step to `offsite.py`: delete an object once it has been absent from manifests for longer than the oldest retained DB backup, so no kept backup loses its files. Cut `monthly/` and `manifests/` to the same maximum. Confirm on B2 that versions are removed, not just hidden. Then update the policy, the site, and `docs/disaster-recovery.md`.
- **Owner:** Owner picks the period, Engineering builds.

### P0-2. A restore resurrects deleted accounts

- **What:** Nothing records deletions for replay. Restoring any backup, or Neon's 7-day history, brings back rows and Neon Auth identities deleted after that point. `pull` uses only the newest archive and manifest, but old manifests plus unexpired `objects/` can bring files back by hand.
- **Why:** The person was told their account is gone. The same retention principle applies, and a restored account can sign in again.
- **Status:** Verified issue. `restore.py` has no replay step, and `b2_drill.py` never deletes an account between backup and restore.
- **Evidence:** `scripts/dr/restore.py`; `scripts/dr/b2_drill.py`; `docs/disaster-recovery.md`; API: `app/services/delete_account.py`.
- **Fix:** Append user id and time (no email) to a deletion log kept outside Postgres, in its own bucket mirrored to B2. It must not live inside the DB backup. Add a mandatory runbook step: after any restore and before serving traffic, replay the log through `delete_account_for_user`. Add that case to the drill. Rental and single-photo deletions can follow the same log later; say so if they don't at launch.
- **Owner:** Engineering.

### P0-3. Deletion wording and reach

- **What:** Both apps and the site say "permanently" with no mention of backups. `delete_account.py` touches Postgres, Object Storage, Neon Auth and cache only, so the RevenueCat subscriber stays. The Android dialog doesn't warn that a subscription keeps billing, and it doesn't mention credits. iOS does both (`AccountHomeView.swift:322-327`, `DeleteAccountView.swift:48`).
- **Why:** Apple: tell people billing continues and ask them to cancel first, and say what is retained ([account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)). Google: explain extra steps such as cancelling, disclose retention, and ask service providers to delete ([Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111)).
- **Status:** Verified issue (C1, C7, C8).
- **Evidence:** `movemork/Features/Account/DeleteAccountView.swift:48`; `movemark-android/.../features/account/AccountScreen.kt:270,305`; web: `src/components/delete-steps.tsx`; API: `app/services/delete_account.py`.
- **Fix:** One shared text: "deleted from MoveMark now; encrypted backups are removed within X days; deleting doesn't cancel a subscription." Match Android to iOS. Call RevenueCat's delete-subscriber API from `delete_account_for_user`, as C7 proposes (API behaviour not verified here).
- **Owner:** Engineering.

### P0-4. Two policies, stale links

- **What:** `docs/legal/` and the website are separate texts and they disagree. The site says DB backups go "within 13 months", photo backups "[period to be decided]", and users must be of age or have a parent's permission. Apps and `docs/app-review.md` still point to Notion and `support@movemark.app`, and Android still shows a "Request account removal" Notion row.
- **Why:** One public promise per fact. Google needs a working web deletion link that names the app ([Play](https://support.google.com/googleplay/android-developer/answer/13327111)).
- **Status:** Verified issue (C15, extended). U11 is partly answered: the site code ships no analytics by default and its contact form is a `mailto:`. The live environment wasn't checked.
- **Evidence:** web: `src/app/(renters)/privacy/page.tsx:124`, `terms/page.tsx:27`, `src/components/analytics.tsx`; `movemork/Info.plist:29-37`; `.../features/account/AccountViewModel.kt:32-39`.
- **Fix:** Make `docs/legal/` the source and publish it to movemark.ca. Move all URLs and the support address, including App Store Connect and Play Console. Point deletion links at `/delete-account`. Fill the four `[OWNER: ...]` placeholders.
- **Owner:** Owner, Engineering.

### P0-5. No working acceptance

- **What:** Migrations 1030 to 1050 and the API gate exist on `dev` and feature branches only. A search of both clients found no call to the acceptance or status functions. Android sign-up shows no legal links. Terms section 1 relies on "by creating an account".
- **Why:** Weak record of agreement, and Canadian guidance expects consent people can understand ([OPC consent guidelines](https://www.priv.gc.ca/en/privacy-topics/collecting-personal-information/consent/gl_omc_201805/)). The policy itself treats photos, addresses and tenancy documents as sensitive, and the OPC says express consent is generally needed for sensitive information.
- **Status:** Verified issue (C4).
- **Evidence:** `neon/migrations/1030`-`1050`; `docs/legal-gate/rollout-plan.md`; API: `app/middleware/require_legal_acceptance.py`.
- **Fix:** Follow the rollout plan. Ship the acceptance screen on both platforms, including the age step (P0-10). Don't set `is_final` while the DRAFT banner is on. Update step 0 ("Lawyer-final") to match the owner's decision.
- **Owner:** Engineering.

### P0-6. GPS in shared exports and documents

| Output | GPS? | Basis |
|---|---|---|
| PDF reports and dispute packets | **No EXIF or GPS found** | Local run: decoded PDF streams held no EXIF, GPS or date metadata for JPEG or PNG. PDFs use `file_path`, never the source. A JPEG *comment* block did survive; derivatives written by the apps shouldn't have one. |
| Working photo (signed link) | Not on current apps, by code | Both apps drop GPS and keep `DateTimeOriginal` only. Not device-tested. The server doesn't check it, so `finalize` accepts any JPEG. |
| Thumbnails | No, by code | Written without metadata. |
| Original (`_source`) | **Yes, if the file had it** | Never signed for download (`test_downloads_never_sign_the_source`), but stored and mirrored to B2. See P0-7. |
| **Image documents (lease, receipt, screenshot)** | **Yes, if the file had it** | iOS keeps JPEG and PNG bytes on purpose (`keepsBytes`), the iOS file route and Android upload raw bytes, and `/api/storage/downloads` signs that same file. It then opens in Quick Look on iOS, and in another app through `ACTION_VIEW` on Android. |

- **What:** The last row is the leak. A lease photographed at home and later shared from the app can carry coordinates. This contradicts what the site FAQ implies, and Privacy section 4 covers photos only. PDF documents may hold their own metadata (not checked). Separately, reports print the rental address, notes and photos by design, so sharing a report shares those.
- **Why:** Limiting collection, and an accurate policy. The source is a home location.
- **Status:** Verified issue from code, not tested on a device. New finding.
- **Evidence:** `movemork/Features/Property/PropertyVaultView.swift:668-680,790-813`; `.../features/documents/DocumentsScreen.kt:76-84,164`; API: `app/routers/storage.py` (`create_downloads`), `app/services/pdf.py` (`_photo_image_reader`).
- **Fix:** Re-encode image documents without metadata before upload on both platforms (iOS already has `MMEvidenceImport.derivative`). Otherwise disclose it in Privacy section 4. Add an API test that a GPS-bearing JPEG yields no EXIF in the PDF, because today only this one-off run covers it.
- **Owner:** Engineering.

### P0-7. GPS in originals

- **What:** Byte-exact originals keep GPS, and nothing reads or shows it. Neither app requests location permission (Android manifest: `INTERNET`, `CAMERA`; no iOS location key), so GPS should arrive only through library picks. Android doesn't hold `ACCESS_MEDIA_LOCATION`, which may mean the OS redacts it there. That's untested.
- **Why:** Storing coordinates with no product use sits badly with limiting collection. The OPC Children's Privacy Code says location collection "should be off by default" where children are in scope ([Code](https://www.priv.gc.ca/en/privacy-topics/privacy-for-businesses/protection-of-children-for-businesses/childrens-privacy-code/children-code-final-report-2026/)).
- **Status:** Verified issue (C3, L7), disclosed in Privacy section 4. A decision is missing.
- **Evidence:** `movemork/Data/Evidence/MMEvidenceImport.swift:8-15`; `.../data/evidence/EvidenceImport.kt`; API: `tests/test_evidence_provenance.py:271`.
- **Fix:** Smallest honest step: keep originals, detect GPS at import (ImageIO and ExifInterface already read this metadata) and show a one-line notice with a chance to cancel. Stronger step: strip GPS before hashing, so the "original" is defined as location-free and the hash chain still holds. Needed if teens are allowed (see `minors-and-age.md`).
- **Owner:** Owner and lawyer decide, Engineering builds.

### P0-8. Timestamps and evidence claims

| Printed or stored | Where it comes from | Can the client set it? | In the PDF |
|---|---|---|---|
| Photo caption | `captured_at` or, if null, `created_at` | **Yes on insert.** It's EXIF, or the **device clock** when the file has none (`upload.capturedAt ?? Date()`; Android similar) | Unlabelled: "Photo 3 · Move-in · Sep 24, 2026 · 12:34 AM UTC" |
| `evidence_files.created_at` | Server `now()`, forced by trigger, immutable | No | Only if `captured_at` is null, which current apps never leave |
| "Recorded" (room row) | `inspection_items.created_at`, default `now()` | **Yes.** Client holds INSERT and UPDATE, with no trigger or column grant | Printed as a fact |
| "Uploaded" (documents) | `property_documents.uploaded_at`, default `now()` | **Yes on insert**, no trigger | Date only |
| "Generated" | Worker clock | No | Labelled, UTC |
| `source_sha256` | Declared by the client; storage enforces it on upload, immutable | Bytes must match | **Not printed** |
| `capture_source` (camera or library) | **Declared by the client** on the ticket, then immutable | Yes, at ticket time | **Not printed** |
| EXIF with no offset | Read in the device's time zone | n/a | Silent assumption |

- **What:** Migration 0940 keeps file time and receipt time apart, but the PDF merges them. The one server-trusted receipt time rarely reaches the reader. A library photo reads like a camera photo. "Recorded" and "Uploaded" can be written by the account holder through the Data API (found by reading grants and triggers, not executed). Notes and ratings stay editable after a report, photos stay deletable, there's no audit trail, and PDFs aren't signed. Copy still says "timestamped report", "Prove what was already there" and "dispute-ready"; the site says "the time each was recorded".
- **Why:** A report may reach a landlord or tribunal, so a time must mean what it appears to mean. Misleading-claim rules are a likely concern (Ontario CPA, Competition Act): **unverified, no official page read**. The `DISCLAIMER` and Terms sections 3 and 7 help, but they don't correct a misleading caption.
- **Status:** Verified issue (C6 extended; client-settable fields and the device-clock fallback are new).
- **Evidence:** `neon/migrations/0940_evidence_source_provenance.sql`, `0960_role_and_grant_hardening.sql:35`, `0001_reconstructed_base_schema.sql:159`; API: `app/services/pdf.py:833,850,943,1224`; `movemork/Stores/PropertyStore+Mutations.swift:88`; `.../data/property/InspectionRepository.kt:154`; `movemork/Shared/MoveMarkGrowthCopy.swift:42,75`.
- **Fix:** (a) Caption: "File time: X (from the file, not verified) · Received by MoveMark: Y · Camera or Library (as declared by the app)", and print the short SHA-256. (b) One migration: force and freeze `inspection_items.created_at` and `property_documents.uploaded_at`, as 0940 does for evidence. (c) Send null, not device time, when the file has no date. (d) Change "timestamped" to "dated", and have the lawyer review proof wording (L12). Update the golden PDFs.
- **Owner:** Engineering; Owner for copy.

### P0-9. Subscription, cancellation and refund disclosure

- **What:** The Android paywall has plan cards, Start Pro, Restore, Terms and Privacy, but no text saying it auto-renews, how often, or how to cancel. iOS has this text. Final prices and plans are unconfirmed (U18).
- **Why:** Google lists a monthly plan that doesn't say it renews and charges every month as a violation, and requires up-front billing and renewal terms and a clear cancel route ([Play subscriptions](https://support.google.com/googleplay/android-developer/answer/9900533)). Apple: describe what the user gets, and meet Schedule 2 ([3.1.2(c)](https://developer.apple.com/app-store/review/guidelines/)). Ontario's rules cover online transactions over $50: disclosure, a chance to accept, decline or correct, and a copy within 15 days ([Ontario](https://www.ontario.ca/page/safe-online-shopping)). Whether a store purchase makes MoveMark the supplier, and whether store receipts satisfy this, are open (L9). The seven-day cancellation remedy appeared only in an excerpt.
- **Status:** Verified issue (new for Android paywall). iOS wording was read, not tested against Schedule 2. Terms sections 10 and 11 read accurate against the code, except that refunded packs aren't handled (P1).
- **Evidence:** `.../features/paywall/ProPaywallScreen.kt:150-235`; `movemork/Features/Paywall/ProPaywallView.swift:345,385`.
- **Fix:** Add one localized block to Android: "Auto-renews every month/year at the price shown until cancelled. Cancel in Google Play > Payments & subscriptions." Confirm yearly plans lead with the yearly price. Confirm U18.
- **Owner:** Engineering; Owner for plans.

### P0-10. Age eligibility

- **What:** No age step in either app or the schema. Terms: "able to form a binding contract". Site: age of majority or parent's permission, with no mechanism behind it. Privacy: "not directed at children".
- **Why:** See `minors-and-age.md`.
- **Status:** Verified issue (C5, L5).
- **Evidence:** `docs/legal/terms-of-service.md` section 4; `docs/legal/privacy-policy.md` section 15; web: `src/app/(renters)/terms/page.tsx:27`.
- **Fix:** Adopt the launch position in `minors-and-age.md`, and align all three texts and both store declarations.
- **Owner:** Owner.

### P0-11. Incident response

- **What:** No breach process, decision-maker or log exists. `docs/security/` is technical only.
- **Why:** PIPEDA requires a record of every breach for 24 months, plus OPC reports and individual notices where there's a real risk of significant harm ([SOR/2018-64](https://laws-lois.justice.gc.ca/eng/regulations/SOR-2018-64/FullText.html)).
- **Status:** Verified issue (U20). The 2026-10-22 out-of-band production SQL still has no identified source (`docs/production-access-audit.md`) and no written conclusion on whether it was a breach.
- **Evidence:** `docs/security/`; `docs/production-access-audit.md`.
- **Fix:** Adopt `breach-response-outline.md`, name the people, create the log, and record a conclusion on the October event as its first entry.
- **Owner:** Owner.

### P0-12. Who is accountable

- **What:** Legal name, address and privacy officer are unset (U1, U2, U3).
- **Why:** PIPEDA's first principle is accountability ([OPC](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/pipeda_brief/)), and the name must match the store seller. Quebec requires the title and contact details of the person in charge on the website ([CAI](https://www.cai.gouv.qc.ca/protection-renseignements-personnels/sujets-et-domaines-dinteret/principaux-changements-loi-25)).
- **Status:** Owner decision. **Evidence:** `docs/legal/unknown-legal-facts.md`.
- **Fix:** Decide them and publish a title and contact. A role mailbox works.
- **Owner:** Owner.

### P0-13. Processors

Code proves these handle user data (section D of `unknown-legal-facts.md`). None of the settings below was checked in a dashboard.

| Provider | Role | Region known from repo | Confirm before launch |
|---|---|---|---|
| Neon (DB, Auth, Object Storage) | Core store | AWS us-east-2 | DPA, 7-day history, IP/user-agent on sessions (U12) |
| Railway (API, worker, backup, Redis per notes) | Compute | Unknown | DPA, region, log retention (U8) |
| Backblaze B2 | Offsite backups | us-east-005 per doc, `offsite.py` default differs | DPA, endpoint, lifecycle rules (U9) |
| RevenueCat | Subscriptions | Unknown | DPA, retention, deletion |
| Sentry | Crash reports | iOS US ingest | DPA, retention, account holder (org named for another product) |
| Vercel | account.movemark.ca, movemark.ca | Unknown | DPA, request logs (reset tokens, C21) |
| Titan | Support mail, per notes only | Unknown | Confirm it's used (U25) |
| Apple, Google | Store billing | n/a | Independent terms apply |
| Postmark | **Not confirmed in use** | n/a | Remove or add (U10) |

- **Why:** A transfer for processing stays the organization's responsibility, contracts are the main tool for comparable protection, and people must be told their data may be processed abroad ([OPC transfer guidelines](https://www.priv.gc.ca/en/privacy-topics/airports-and-borders/gl_dab_090127/)). Privacy section 8 does the notice. Apple's 5.1.1(i) also requires the policy to **confirm third parties provide the same or equal protection**, and the sentence on comparable protection was removed from the draft because no contracts were confirmed. So this gap shows up in App Review too.
- **Status:** Potential risk (U14).
- **Evidence:** `docs/legal/unknown-legal-facts.md` section D; `docs/legal/privacy-policy.md` sections 7 and 8.
- **Fix:** Accept or download each DPA, fill the table, restore a truthful sentence to the policy, and require breach notice to MoveMark in each contract.
- **Owner:** Owner.

### P0-14. App Store privacy labels and Play Data safety

Both forms must reflect SDK data too ([Apple](https://developer.apple.com/app-store/app-privacy-details/), [Google](https://support.google.com/googleplay/android-developer/answer/10787469)). Draft from code; the console entries were not seen:

| Data | Apple | Play |
|---|---|---|
| Email, name | Contact Info | Personal info |
| Rental address, landlord contact | Physical Address, Other User Content | Address, other |
| Photos | Photos or Videos | Photos |
| Notes, leases, receipts | Other User Content | Files and docs |
| GPS in originals and image documents | **Precise Location** | **Precise location** |
| Rent, deposit amounts | Other Financial Info | Other financial info |
| Purchases (RevenueCat) | Purchase History | Purchase history |
| Account id | User ID | User IDs |
| Crash data (Sentry) | Crash Data | Crash logs |
| SDK device identifiers | Check SDK docs | Check SDK docs |

- **Why:** Mismatched answers can block updates or remove the app on Play. GPS is the easy miss: "we never ask for location" is true, but coordinates can still be transmitted and stored, and Apple defines collection by transmission and retention. If P0-6 and P0-7 strip GPS, drop that row.
- **Status:** Potential risk. No analytics or advertising SDK was found, so "no tracking" looks right from code. Play also asks about deletion and encryption in transit; state them only as true after P0-1 and P0-3.
- **Evidence:** section D of `unknown-legal-facts.md`; `movemark-android/app/build.gradle.kts`; `docs/app-review.md`.
- **Fix:** Fill both from this table, and review on every SDK or provider change.
- **Owner:** Owner.

### P0-15. Quebec

- **What:** Both stores offer availability by country or region ([Apple](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/), [Play](https://support.google.com/googleplay/android-developer/answer/7550024?hl=en), excerpt). No province option was found, so enabling Canada reaches Quebec. The apps are English only (iOS `knownRegions` is `en`; Android has only `values/`). Terms and Privacy have no French version.
- **Why:** See `jurisdiction-matrix.md`.
- **Status:** Verified issue on language; owner decision on approach (L10).
- **Evidence:** `movemork.xcodeproj/project.pbxproj:241`; `movemark-android/app/src/main/res/`.
- **Fix:** Option A (recommended target): finish the Quebec minimum set in the matrix. Option B (fallback if French isn't ready): say Quebec isn't served yet, stop Quebec rentals at setup (`properties.province_state` exists), and don't market there. Whether B limits exposure is a lawyer question.
- **Owner:** Owner, Lawyer.

### P0-16. Privacy requests

- **What:** The site promises deletion by email "from the address on your account", but emails aren't verified (C14). There's no procedure, no account export, and originals can't be retrieved (C13).
- **Why:** Access requests must be answered within 30 days, and an acknowledgment doesn't count ([OPC](https://www.priv.gc.ca/en/privacy-topics/accessing-personal-information/obligations-for-organizations/02_05_d_54_ati_02/), excerpt).
- **Status:** Verified issue (U21).
- **Evidence:** web: `src/components/delete-steps.tsx`; API: `app/routers/storage.py`.
- **Fix:** A one-page procedure: named handler, request log, identity check (sign-in or a confirmation link, never the From address alone), 30-day clock, how to pull rows and originals by user id, what to do about third parties in photos (L8). Self-serve export is P1.
- **Owner:** Owner.

### P0-17. User isolation: what is actually tested

No isolation defect was found in the code read. This item is about the limits of the evidence.

| Surface | Tested | Where | Not covered |
|---|---|---|---|
| Data API, real HTTP and JWT | A vs B: SELECT and UPDATE on 5 tables, delete evidence and property, cross-reference writes, snapshot, forged token, anonymous reads, forbidden RPCs | `neon/tests/data_api_e2e.py` | Direct reads of `maintenance_issues`, `property_documents`, `disputes`, `move_out_checklists`, tags, links over HTTP |
| Postgres RLS, real roles | Cross-reference attacks, stranger on v2 snapshot and vault summary, every command on every client table | `neon/tests/test_reconstruction.py`, `test_legal_gate.py` | Simulated JWT claims, not the HTTP path |
| Object keys | Foreign key refused on insert (0910), `key_in_user_folder` at signing | API: `tests/test_storage.py:208` | Unit storage is in memory. `test_legal_gate.py` enumerates routes for the *gate*, not ownership, so new routes aren't auto-covered for ownership |
| Signed URLs | B can't get A's links; tampered upload URLs fail; unsigned GET denied (one bucket); deleted object returns 404 | API: `scripts/neon_dev_storage_gate.py`, `prod_qa_lifecycle.py` | Links are bearer: **anyone holding one can use it** until expiry (evidence 1 h, reports 15 min, upload 10 min), and links can't be revoked. Expiry itself isn't tested live. Unsigned denial isn't checked on production or on other buckets |
| Exports | B gets 404 on list and download and can't enqueue; job queued before a new legal version can't be collected | API: `tests/test_idor_and_input.py`, `tests/test_legal_gate.py`, `prod_qa_lifecycle.py` | No test that a report contains only the owner's photos. The worker's fetch doesn't re-check the key folder, relying on 0910 |
| Railway API and worker | Separate roles, no BYPASSRLS, but their policies are `USING (true)` on each table, so **per-user isolation there is application code** | `neon/migrations/0970`; `docs/production-cutover.md` | Log content, dashboard access |
| Redis cache | Another user never reads a cached entry | API: `tests/cache/test_cache_integration.py:75` | Redis holds signed report URLs in plain text for up to 14 minutes |

- **Why:** The last recorded production run is 41/41 on 2026-10-23, on `5efbe13`, before the legal gate. It's a recorded result, not one reproduced here.
- **Status:** Potential risk. **Evidence:** table above.
- **Fix:** On the exact release candidate, run `data_api_e2e.py`, `legal_gate_data_api_e2e.py`, `neon_dev_storage_gate.py`, `prod_qa_lifecycle.py`. Add the missing tables, a per-bucket unsigned check, and a route-enumerating ownership test. Add `key_in_user_folder` to the worker's fetch.
- **Owner:** Engineering.

### P0-18. Account linking (blocks only if social sign-in ships)

- **What:** Social is off in App Store and Android release builds. Managed Neon exposes no linking setting, so behaviour has to be tested. Production email verification is off (finding 8). If a provider sign-in links to an unverified password account and the old password keeps working, whoever registered that email keeps access. One `account_not_linked` refusal is noted in project memory, but no T5/T6 result was found (the default results file `_scratch/social-probe-results.json` is absent). Nothing revokes Apple tokens at deletion; Apple says apps "should use the Sign in with Apple REST API to revoke user tokens" ([Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app/)).
- **Why:** An account takeover here exposes home photos and leases, and would be a reportable-breach candidate.
- **Status:** Potential risk.
- **Evidence:** `docs/social-signin-probe-runbook.md`; `movemork/Features/Auth/SocialSignIn.swift`; `docs/production-security-gate.md:17`.
- **Fix:** Keep social off in customer builds until T5, T5P and T6 are recorded and pass, verification is on, the policy matches, and Apple revocation is settled with Neon. If social ships, Apple's 4.8 needs an equivalent private login, which Sign in with Apple appears to cover.
- **Owner:** Owner, Engineering.

## P1: improvements (soon after launch; do the first two before the first real customer)

| # | What and why | Status | Evidence | Smallest fix | Owner |
|---|---|---|---|---|---|
| 1 | Forensic Neon branches and local archives hold data outside any deletion flow; access is unwritten (C16) | Verified in docs, current state unknown | `docs/production-access-audit.md` | Delete branches once the event is closed; write down who has access | Owner |
| 2 | Email verification off: wrong-person resets, weak identity for requests (C14) | Verified in docs | `docs/production-security-gate.md:17` | Turn on with the production sender. Promote to P0 if social ships | Owner |
| 3 | No retention schedule; inactive accounts live forever (C12, U7) | Verified, disclosed | API: `worker.py`; Privacy section 10 | Set a period with notice before deletion | Owner, Eng |
| 4 | Reports can't be deleted alone; deleted photos live on in PDFs (C10) | Verified, disclosed | API: `app/routers/exports.py` | Add report delete | Eng |
| 5 | Delete rental unshipped; storage failures logged, not retried (C11) | Verified | API: `app/services/delete_property.py` | Ship UI with a retry; update Privacy section 11 | Eng |
| 6 | Self-serve export; originals unobtainable; fingerprint unusable (C13, C24) | Verified | API: `app/routers/storage.py` | Account export, including originals on request | Eng |
| 7 | Image caches survive sign-out and deletion on shared phones (C9) | Verified by prior read | `movemork/Shared/Light/MMEvidenceImage.swift`, `movemork/Shared/MMCachedAsyncImage.swift` | Purge on sign-out and delete | Eng |
| 8 | Android backup rules may include Room cache and DataStore (C17) | Potential risk | `movemark-android/app/src/main/res/xml/backup_rules.xml` | Exclude them | Eng |
| 9 | Report running at deletion could leave an ownerless PDF, mirrored to B2 (C23) | Potential risk | API: `app/services/export_job_processor.py` | Re-check user after upload, delete on miss | Eng |
| 10 | Refunded Report Pack keeps its credit (C22) | Verified | API: `app/routers/webhooks.py` | Handle refund event, or state it | Eng |
| 11 | Sentry: API never calls `init_sentry()`; local-variable capture and iOS HTTP breadcrumbs (could hold signed URLs) unverified (C18) | Part verified, part potential | API: `app/observability.py`, `worker.py` | Decide, scrub, verify against SDK docs | Eng |
| 12 | No first-party `PrivacyInfo.xcprivacy`, while 10 files use UserDefaults or similar. Apple's doc pages returned no text; [forum excerpts](https://developer.apple.com/forums/thread/750777) show a May 2024 upload rule and mixed enforcement. TestFlight uploads happened | Potential risk | no `*.xcprivacy` in `wt-legal-gate` | Check App Store Connect mail; add the manifest | Eng |
| 13 | CASL: **no marketing email found** in code. Account and reset mail isn't promotional. `landing/index.html` has a placeholder Formspree waitlist | No issue found | `landing/index.html:93-101`; web: `src/lib/contact.ts` | See rule below; delete or fix the form | Owner |
| 14 | Third-party data: landlords, roommates, tradespeople (L8) | Owner decision | `neon/migrations/0001` | Add handling to the P0-16 procedure | Owner, Lawyer |
| 15 | Short-stay guests: Terms, policy and product copy address renters only; "tenancy" wording may not fit | Verified gap vs brief | Terms sections 2 and 4 | Decide scope, adjust Terms section 4 | Owner, Lawyer |
| 16 | No way to notify users of policy changes (U23) | Verified | `docs/legal/` | Use the re-acceptance flow from 1030 | Eng |
| 17 | Lawyer review: liability, indemnity, "deposit" wording, EULA (L2, L4, L11, L12) | Owner decision | section B | One review pass | Lawyer |

**CASL rule before any marketing email** ([ISED](https://ised-isde.canada.ca/site/canada-anti-spam-legislation/en/getting-consent-send-email), [Act s. 6](https://laws-lois.justice.gc.ca/eng/acts/E-1.6/page-1.html)): get express consent separately from Terms acceptance, keep a record, include business name, mailing address and a contact method valid for 60 days, include a free unsubscribe honoured within 10 business days. Section 6(6) exempts from consent only messages that *solely* do things like confirm a transaction or give factual account or subscription updates, and they still need identification and unsubscribe. So a renewal notice with a promotion in it no longer qualifies. Business outreach is outside this document, but CASL applies to it too.

## Future international tasks (only when a market is chosen)

| Market | Task |
|---|---|
| US | Decide on Texas SB 2420 handling (Declared Age Range, Play Age Signals), COPPA actual-knowledge process, state-law review, renewal and cancel flows |
| EU/EEA | Trader status, Art. 27 representative, lawful basis, transfer mechanism, Art. 8 ages, 14-day withdrawal, translations |
| UK | UK representative, Children's code assessment, UK GDPR basis and transfers |
| Elsewhere | Apple flagged age obligations for Brazil, Australia and Singapore ([Feb 2026](https://developer.apple.com/news/?id=100002398)). Check before enabling those stores |
| Canada | Watch Bill C-36 (first reading only) and Ontario's CPA 2023. See the matrix |

## Unverified or not checked

- Competition Act and Ontario CPA false-representation rules; Ontario age of majority and minors' contracts; the seven-day CPA cancellation remedy.
- Live settings of any provider, including B2 lifecycle rules, Neon retention and bucket public access.
- Store listings, age ratings and labels. Device behaviour of EXIF stripping, including Android picker redaction.
- RevenueCat deletion API, B2 version deletion, Sentry SDK defaults.
- Apple's privacy manifest documentation (pages returned no text).
