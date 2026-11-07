# Legal gate: production rollout and rollback

**Status: not approved for production.** Nothing here has run on production. Migrations 1030 to 1050 are on Neon `dev` with enforcement off.

## The risk

Turning enforcement on before people have an app that can accept locks out existing customers, and it looks like data loss. A blocked read returns HTTP 200 with an empty list, so today's apps would show no rentals. Their writes then fail, and nothing on screen explains why. No customer has accepted anything, and we never mark anyone as accepted on their behalf.

The rule: **enforcement goes on last, and only after measured adoption.**

## How the design makes that safe

All policies and the API check depend on one row, `legal_gate_settings.enforced`, which migrations create as `false`. Holding back the policy migration would not work: the runner applies everything pending and has no "stop at" option, so one wrong checkout would apply it. With the switch, applying 1030 to 1050 changes nothing for any client, and the schema can go out long before enforcement.

Three separate conditions must all hold before anyone is blocked: policies applied, a complete active document pair published, and `enforced = true`.

## Order

Each step needs its own owner approval. Run `check` before every `apply`, and stop on drift.

| # | Step | How | Effect on users |
|---|---|---|---|
| 0 | Lawyer-final Terms and Privacy Notice, with their public URLs | Owner | None |
| 1 | Apply 1030, 1040, 1050 to production | Runner, production flag | None |
| 2 | Deploy the API (`823c787`) | Merge to the deploy branch | None. **Must follow step 1**: the check fails closed, so without the function every protected route returns 503 |
| 3 | Publish final documents | A numbered migration calling `publish_legal_document(..., p_is_final => true)` | `acceptance_required` becomes true; nobody is blocked |
| 4 | Ship iOS and Android that handle the gate | Stores | New apps prompt everyone, while old apps keep working |
| 5 | Soft phase: measure | Read-only query below | People accept while nothing is blocked |
| 6 | Turn on enforcement | A numbered migration (below) | Those who have not accepted are blocked |

Steps 3 and 4 can swap: with no documents, new apps simply don't prompt. That is the better order if store review is the slow part.

### Step 5: when is it safe

Proposed bar, for the owner to set:

- At least 95% of accounts with a session in the last 30 days have a current acceptance.
- Both apps have been in stores for at least 30 days.
- No open defect in the acceptance flow.

```sql
SELECT count(*) AS active,
       count(*) FILTER (WHERE public.legal_user_has_current_acceptance(u.id)) AS accepted
FROM neon_auth."user" u
WHERE EXISTS (SELECT 1 FROM neon_auth.session s WHERE s."userId" = u.id AND s."updatedAt" > now() - interval '30 days');
```

This needs an owner-approved read path on production. The columns match `dev`; production has not been checked.

### Step 6: the enforcement migration

Not written yet. It must not sit in the repository before it is approved, because it would also apply on `dev` and in every test build.

```sql
DO $$ BEGIN
  IF (SELECT count(*) FROM public.legal_documents WHERE active AND is_final) <> 2 THEN
    RAISE EXCEPTION 'refusing to enforce: no final document pair';
  END IF;
END $$;
UPDATE public.legal_gate_settings SET enforced = true, updated_at = now();
```

The migration that publishes documents must come first so a from-zero build passes this check. Test fixtures that assume the gate starts off will need to reset it. Enable it at a low-traffic hour, and have the rollback migration reviewed and ready first.

## Old app versions

No force-update mechanism turned up in either app, so nothing can tell an old build to update. Once enforced, an old build:

- sees empty lists from the Data API and 200 `[]` from updates and deletes;
- gets 403 with code 42501 on inserts, and 403 `LEGAL_ACCEPTANCE_REQUIRED` from the API, which it shows as a generic error;
- has no way to accept;
- keeps the renter's data safe on the server. Nothing is deleted, and it all returns after accepting in a newer build.

Not verified: what each old build does on screen. `PropertyStore+Selection.swift` has an empty-result path, and first-run routing might offer to create a rental, which would then fail. Test the current store builds against `dev` with enforcement on before step 6.

Mitigations:

1. Add a minimum-version check to the apps that ship in step 4, so the next gate has a way to reach old builds.
2. Before step 6, send a notice by email and App Store release notes to accounts that have not accepted.
3. Support needs a script: "update the app and accept; your records are safe".
4. Account deletion stays available from old builds that have it.

## Later document versions

Publishing a new version while enforced blocks every user at once, until they accept. That is correct for a material change but heavy for a typo. Options when that day comes: turn enforcement off, publish, soft phase, turn on; or skip publishing a new version for non-material edits. Apps must re-read status on foreground and on any `LEGAL_ACCEPTANCE_REQUIRED`.

## Rollback

Production changes only move through the runner, so every rollback is a new numbered migration. Never paste SQL. The runner's `check` builds the chain twice, so allow a few minutes.

| Situation | Action | Data effect |
|---|---|---|
| Customers locked out after step 6 | Migration: `UPDATE legal_gate_settings SET enforced = false`. Releases RLS and API together | None; acceptances kept |
| Policies themselves faulty | Migration with the bodies of `neon/rollback/1050_*.down.sql`, then `1040_*.down.sql` | None; acceptances kept. Tested locally and on a Neon child branch: schema returns exactly to the prior fingerprint |
| API check faulty | Turn enforcement off, or redeploy the previous commit | None |
| Abandon the feature before anyone accepted | Above, then `neon/rollback/1030_*.down.sql` | **Destroys acceptance records**; never after customers accept |

Rolling the API back does not release RLS, and dropping the policies does not release the API check. The switch releases both, so use it first.

## Performance

Local PostgreSQL 18.6 on synthetic scale-1 data (20k users, 25k properties, 1.65M evidence rows, 1.03M items, 60k acceptances, one 50k-photo property). Median milliseconds, measured as SQL under role `authenticated`:

| Query | No policies | Gate off | Enforced, accepted | Enforced, blocked |
|---|---|---|---|---|
| Properties list | 0.05 | 0.05 | 0.06 | 0.06 |
| Rooms of property | 0.07 | 0.08 | 0.11 | 0.07 |
| Evidence of property | 0.26 | 0.21 | 0.24 | 0.07 |
| Evidence, 50k property | 31.12 | 30.92 | 30.97 | 3.35 |
| Items of room, 25k items | 15.68 | 21.22 | 15.20 | 1.94 |
| Snapshot v2 | 2.61 | 2.98 | 3.39 | 1.93 |
| Snapshot v2, big | 85.45 | 89.36 | 88.26 | 3.53 |
| Snapshot v1, big | 850.57 | 888.93 | 875.36 | 6.30 |
| Vault summaries | 0.18 | 0.28 | 0.45 | 0.11 |
| `get_legal_status` | 0.08 | 0.09 | 0.10 | 0.11 |

The helper evaluates once per table reference per statement: EXPLAIN shows it as an InitPlan with `loops=1` over 50,057 rows. The worst measured cost is under 1 ms on a typical snapshot and about 3% on the largest. Single runs on a laptop, with the "no policies" column measured last on a warm cache, so read small differences as noise. The API's added check, `legal_gate_open_for_user`, took a median of 0.047 ms (p99 0.208 ms) over a local socket; on Railway add one round trip to Neon per protected request. It is not cached, because acceptance happens through the Data API, which the API can't see.

## Client contract

Base URLs are the Neon Data API (`.../neondb/rest/v1`, Neon Auth JWT) and the MoveMark API (`/api`).

### Read status

`POST {DataAPI}/rpc/get_legal_status` with body `{}`, or `GET {API}/api/legal/status`. The answer is identical:

```json
{
  "enforced": true,
  "acceptance_required": true,
  "blocked": true,
  "documents": {
    "terms": {"version": "…", "content_hash": "…", "url": "https://…", "is_final": true, "published_at": "…"},
    "privacy_notice": {"version": "…", "content_hash": "…", "url": "https://…", "is_final": true, "published_at": "…"}
  },
  "accepted": null
}
```

- **`acceptance_required`** is the field that decides whether to show the screen. Prompt on it even when `enforced` is false.
- `blocked` is `enforced AND acceptance_required`. When true, data calls will not work.
- `documents` is null and `acceptance_required` false when nothing is published. Carry on normally.
- `accepted`, when current, is `{terms_version, privacy_notice_version, accepted_at, acceptance_method}`; otherwise null.
- `url` can be null, and is on `dev`. `is_final: false` means a draft: label it as one.

Check after sign-in, before loading rentals; on return to foreground; and on any `LEGAL_ACCEPTANCE_REQUIRED`.

### Accept

`POST {DataAPI}/rpc/accept_legal_documents`:

```json
{"p_method": "email", "p_terms_version": "<shown>", "p_privacy_notice_version": "<shown>"}
```

- `p_method` is `email`, `apple` or `google`: how the renter signed in.
- Send the versions actually displayed, from `documents`. Never hard-code them.
- Returns 200 with the same object as status. Check `blocked` is false, then load data.
- Safe to retry. The first acceptance stands, with its time and method.
- The server sets time, hashes and identity.

There is no API route for accepting; this RPC is the one write path.

### Errors

| Where | HTTP | Body | Meaning | Client action |
|---|---|---|---|---|
| API, protected route | 403 | `{"error": "…", "code": "LEGAL_ACCEPTANCE_REQUIRED"}` | Must accept | Read status, show the screen |
| API, protected route or status | 503 + `Retry-After: 5` | `code: "LEGAL_STATUS_UNAVAILABLE"` | Could not check | Retry; do not show the screen |
| API | 401 | `{"error": "Unauthorized"}` | Token | Usual sign-in handling |
| Accept RPC | 400 | `code: "22023", message: "LEGAL_VERSION_NOT_ACTIVE"`, `details` names the active versions | Screen is stale | Re-read status, show the new text, ask again |
| Accept RPC | 400 | `code: "22023", message: "LEGAL_INVALID_METHOD"` | Bug | Report it |
| Accept RPC | 400 | `code: "22023", message: "LEGAL_DOCUMENTS_UNAVAILABLE"` | Nothing published | Carry on |
| Accept RPC | 403 | `code: "42501", message: "LEGAL_NOT_AUTHENTICATED"` | No identity in token | Sign in again |
| Accept RPC | 409 expected | `code: "23503"` | Account deleted, token still live | Sign out. The 409 mapping was not observed over HTTP |
| Data API insert while blocked | 403 | `code: "42501"`, message names the row-level security policy | Blocked | Read status |
| Data API read, update or delete while blocked | **200** | `[]` | Blocked, silently | See below |

Match on `code` for the API, and on `message` for the RPC.

### What the apps must get right

1. **Never treat an empty result as "no rentals" until status says `blocked` is false.** Otherwise the renter lands in first-run and thinks their records are gone.
2. **Treat a 200 `[]` from an UPDATE or DELETE as not done.** Durable and offline queues must not mark such work complete and discard it. Pause queues while `blocked` is true. The 42501 from a blocked insert must also keep the item queued.
3. The acceptance screen must offer sign out and delete account (`DELETE /api/account` stays open), and open both documents.
4. Do not pre-tick anything, and do not accept on the renter's behalf after sign-up.

## Decisions for the owner

1. **Retention of acceptance records.** They cascade away with the account (`ON DELETE CASCADE`), so after deletion there is no proof of consent. That favours privacy; a lawyer may want a retained record instead. Keeping them means dropping the foreign key and writing the retention into the Privacy Notice, which doesn't mention these records yet.
2. **`acceptance_method` is client-asserted.** The server validates the value, not that it matches the sign-in provider. It could be cross-checked against `neon_auth.account`.
3. **No IP address or device is stored.** Deliberately minimal; a lawyer may want more.
4. **The enforcement bar in step 5.**
