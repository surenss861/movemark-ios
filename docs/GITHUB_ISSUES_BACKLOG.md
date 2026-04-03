# MoveMark — GitHub issue backlog (from audit)

Use these as four separate GitHub issues. Execution order: **Security + exports** first, then data integrity, then UX/perf.

**Status (in-repo):** Sprint 1 (security, exports, PDF) and most Sprint 2/3 items from this file are implemented in the app/API; open GitHub issues if you still want tracking there.

---

## 1) [Security] Remove hard-coded Supabase config from iOS source and tighten backend auth surface

**Problem**  
The iOS app previously embedded Supabase URL and anon key in Swift. The backend used loose CORS and non–timing-safe webhook secret comparison.

**Why it matters**  
Trust and shipping: config belongs in build settings / plist; webhook and CORS should follow production norms.

**Scope**  
`SupabaseConfig.swift`, `Info.plist`, Xcode build settings, `movemark-api/src/routes/webhooks.ts`, `movemark-api/src/index.ts`, `movemark-api/src/lib/webhookAuth.ts`, `supabase/functions/generate-dispute-packet/index.ts` (auth model comment).

**Acceptance criteria**  
- No Supabase URL/anon literals in Swift source; values come from plist via `SUPABASE_URL` / `SUPABASE_ANON_KEY`.  
- Webhook bearer validation uses constant-time comparison.  
- CORS is origin-allowlist driven (`CORS_ALLOWED_ORIGINS`).  
- Edge Function auth model documented in-function.

**Test plan**  
- Build app; sign-in and property load.  
- Valid/invalid webhook `Authorization` behavior.  
- Browser request with disallowed `Origin` rejected for CORS.

---

## 2) [Exports] Real move-in PDFs and correct export verification / filtering

**Problem**  
Move-in export was a text buffer; verify treated in-progress as failure; export list could include other properties without an active vault.

**Why it matters**  
Exports are a core trust surface.

**Scope**  
`movemark-api/src/lib/pdf.ts` (pdf-lib), `ExportHistoryView.swift`, `ExportAPIClient.swift`, `movemark-api/src/routes/exports.ts`, `ExportVerificationStatus.swift`.

**Acceptance criteria**  
- Move-in artifact is a valid PDF.  
- 409 / not-ready maps to “processing”, not generic failure.  
- Export history requires active property; API supports `?propertyId=`.  
- Success paths use success styling where applicable.

---

## 3) [Data Integrity] Save-flow correctness (room, maintenance, docs, move-out)

**Problem**  
False-negative saves, swallowed tag errors, condition rating gaps, stale maintenance after failed reload.

**Scope**  
`PropertyStore+Mutations`, `PropertyStore+Hydration`, `DocumentRepository`, move-out checklist (rollback TBD).

**Acceptance criteria**  
- Tag insert failures surface to the user.  
- `conditionRating == 2` mapped intentionally.  
- Failed maintenance reload clears stale log.  
- Distinguish save vs refresh failures where possible.

---

## 4) [UX/Perf] Hydration, previews, polish

**Problem**  
Duplicate fetches, serial hydration, signed URL expiry, dispute picker labels, free export counter scope, debug noise.

**Scope**  
`PropertyStore+Hydration`, `MaintenanceLogView`, `DisputeBuilderView`, `SubscriptionManager`, etc.

**Acceptance criteria**  
- Single maintenance load on first appear.  
- Parallelized hydration where safe.  
- Per-user export counters; clearer picker copy.
