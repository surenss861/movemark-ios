# Gate 2 — Production Security & Abuse Resistance (2026-10-23)

API suite with Redis enabled: **265 passed, 0 skipped** (`movemark-api-py`, `recovery/neon-api`); worker suites
as `movemark_worker`: **33 passed**. Neon reconstruction suites: **162 passed**. Production checks were read-only.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | **HIGH** | RevenueCat entitlement upserts were last-write-wins: a delayed retry (or replay) of the previous period's `EXPIRATION` arriving after `RENEWAL` revoked a paying user's Pro | **Fixed** `25af115` — ordered by billing period; test fails on the old code |
| 2 | **HIGH** | No per-user limit on upload tickets: any free account could mint unlimited signed upload URLs (storage cost / abuse) | **Fixed** `2acb2e8` — 120/min and 1000/h per user; refused tickets are never recorded |
| 3 | MEDIUM | Redis limiter set the counter and its expiry in two calls; a crash between them limited that caller forever | **Fixed** `2acb2e8` — one Lua call; a TTL-less key heals |
| 4 | MEDIUM | Redis client pool failed fast under a burst ("Too many connections"), dropping the limiter to per-process memory: the budget overshot by 29 at 500 concurrent requests | **Fixed** `2acb2e8` — blocking pool (32, 2 s wait); burst now allows exactly the budget |
| 5 | MEDIUM | No request-body cap | **Fixed** `2acb2e8` — 256 KiB, 413 by Content-Length or streamed count |
| 6 | MEDIUM | Signed downloads, deletes, account deletion, vault/catalog/capabilities had no limits; no pre-auth limit against bad-token floods | **Fixed** `2acb2e8` — per IP (1200/min, before auth) and per user (600/min) on every authenticated route; downloads 120/min, deletes 60/min, account deletion 5/h |
| 7 | MEDIUM | Malformed export bodies and non-uuid path ids answered 500 (noise in the 5xx alert stream) | **Fixed** `e0e84c1` — 400/404 |
| 8 | MEDIUM | Production Neon Auth does not require email verification (throwaway sign-ups) | **Accepted until Gate 3** — needs the production email sender. Mitigated by Neon Auth's own throttling (below) and findings 2 and 6 |
| 9 | LOW | Move-out/dispute export on another renter's rental answered 402 (entitlement checked before ownership); no data exposed | **Fixed** `e0e84c1` — ownership first |
| 10 | LOW | Neon Auth `organization` plugin enabled; neither app uses it | Post-launch (or disable with the Gate 3 auth changes) |
| 11 | LOW | `_entry_payload` is RPC-callable (the invoker RPCs need EXECUTE) | Accepted: direct-call RLS regression test (`c29563d`); moving it out of the exposed schema is post-launch |
| 12 | LOW | Same-period RevenueCat events (e.g. CANCELLATION/UNCANCELLATION) still apply in arrival order | Accepted: RevenueCat redelivers state on the next event; would need an event-time column (schema frozen) |
| 13 | LOW | `movemark-api-py` has no CI (tests, secret scan); `movemark-ios` scans only `main` and PRs | Final release gate (CI green + branch protection) |

No unresolved HIGH findings.

## Evidence by requirement

- **Distributed rate limiting:** replicas share one budget through Redis (memory cleared between calls); 50
  concurrent consumes of a 10-budget allow exactly 10; a live-app burst of 650 + 500 requests from 5 users
  yields only 200/429, never 5xx, with the 8-connection DB pool queueing (`tests/cache/test_distributed_rate_limit.py`).
- **IP + user + action keys:** `tests/test_abuse_limits.py` (upload tickets per user, account deletion,
  bad-token floods hit the IP limit before auth and are per address).
- **Sign-in / sign-up / reset abuse:** handled by Neon Auth, which throttles per client: on dev, failed
  sign-ins turned 429 from the 5th attempt (constant from the 15th), reset requests from the 10th.
  Production auth: email/password only, localhost off, no OAuth providers.
- **JWTs:** suite covers expired, wrong issuer/audience, other-branch tokens, foreign key, unknown kid,
  tampered payload, `alg: none`, HS256 key confusion, bad headers, banned users. Production Data API
  rejects no token, malformed, `alg: none`, unknown kid and real-kid-wrong-key tokens (Gate 1).
- **IDOR:** every property-scoped route refuses another renter's ids with 404 and leaks no ids; exports
  cannot be queued or spent on another rental (`tests/test_idor_and_input.py`); storage, export
  download, account deletion and ticket cross-account tests already existed.
- **Upload tickets:** finalize is owner-only, idempotent, refuses expired tickets, certifies once; abandon
  is owner-only and never deletes referenced objects; the sweeper is concurrency-safe.
- **Storage paths:** keys are server-built; rows pointing outside the caller's folder are never signed;
  clients cannot choose bucket or key.
- **Export spam / credits:** 3 creates per hour per rental and type, one active job per rental and type,
  concurrent requests spend exactly one credit.
- **Webhooks:** wrong secret 401 (constant-time compare), replay of a grant is idempotent per event,
  delayed/replayed old subscription events are ignored (finding 1), unknown users acknowledged without
  writes, a lost response never double-grants.
- **Malformed/oversized input:** 4xx for every POST with garbage bodies and every GET with garbage path
  ids; 413 over 256 KiB.
- **Runtime roles (production):** no superuser/BYPASSRLS/CREATE/ownership/membership; DDL refused; GRANT
  grants nothing; `neon_auth` schema denied; no owner or migration credential in Railway.
- **Pool exhaustion:** an exhausted pool fails cleanly (PoolTimeout, logged with pool numbers); bursts
  larger than the pool queue; a connection killed mid-enqueue leaves no export and no spent credit.
- **Secret scan:** gitleaks 8.30.1 over all history of both repositories. `movemark-api-py`: 0.
  `movemork`: 2, both benign — a deliberately wrong token in a runbook example (verified by hash to
  differ from the live webhook secret) and a Supabase `anon` key (public by design; project deleted).
- **Telemetry:** one structured `http` line per 4xx/5xx with status and route template (no ids);
  unhandled errors logged as 500 and sent to Sentry; `db.pool_timeout` with pool numbers; worker
  `export.backlog` (queued, processing, oldest age; warn over 5 min); export failures and lease losses
  already logged. Alerts on these lines are configured at Gate 4 with the deployment.
