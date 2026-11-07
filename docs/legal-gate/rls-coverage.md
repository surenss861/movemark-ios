# Legal gate: RLS coverage matrix

State of Neon `dev` at migration 1050, read from the catalog on 2026-11-07. "Gated" means a RESTRICTIVE policy `<table>_legal_gate` (1040, 1050), `TO authenticated`, evaluating `(SELECT public.legal_gate_passes())`. The policies do nothing until `legal_gate_settings.enforced` is true and an active document pair exists.

Client grants: S select, I insert, U update, D delete, for role `authenticated`. There are 101 live policies, 13 of them gate policies. The "about 153" figure counts `CREATE POLICY` statements across all migrations, many of which were later replaced.

## Tables

| Table | Client grants | Gated | Wave | Why |
|---|---|---|---|---|
| properties | SIU | Yes | 1040 | Rental address and root of all ownership checks |
| rooms | SI | Yes | 1040 | Rental data |
| inspections | SI | Yes | 1040 | Rental data |
| inspection_items | SIUD | Yes | 1040 | Notes, condition ratings |
| evidence_files | SID | Yes | 1040 | Storage keys, the path to the photos |
| property_documents | SID | Yes | 1040 | Leases and receipts |
| exports | S | Yes | 1040 | Report rows; clients cannot write them (0930) |
| maintenance_issues | SIUD | Yes | 1050 | Free text; was also returned by both snapshot RPCs |
| inspection_item_tags | SID | Yes | 1050 | Already hidden through inspection_items; now direct |
| move_out_checklists | SIU | Yes | 1050 | Rental data, policy checks user_id only |
| move_out_checklist_state | none | Yes | 1050 | API-only today; closed in case a grant returns |
| disputes | S | Yes | 1050 | Rental data, policy checks user_id only |
| dispute_evidence_links | S | Yes | 1050 | Rental data |
| profiles | SIU | **No** | n/a | Own row only. Sign-in upserts it before any acceptance can happen, and the renter must see their own identity on the gate screen |
| issue_tags | S | **No** | n/a | Shared reference list, no user data |
| legal_documents | S | **No** | n/a | Must be readable to be accepted |
| legal_acceptances | S (own rows) | **No** | n/a | The renter's own consent record; no client write |
| legal_gate_settings | none | n/a | n/a | No client or runtime role holds anything |
| report_credit_events | none | n/a | n/a | API-only |
| user_report_credits | none | n/a | n/a | API-only; `GET /api/account/report-credits` is open (below) |
| user_entitlements | none | n/a | n/a | API-only, written by the RevenueCat webhook |
| storage_upload_tickets | none | n/a | n/a | API-only; the routes that use it are gated |

`test_every_client_data_table_carries_the_gate_and_the_open_ones_are_named` fails if a new client-readable table takes neither side.

Runtime roles: `movemark_api` and `movemark_worker` have their own `TO <role>` policies, so the gate does not apply to them. The API enforces it in code. `movemark_backup` has BYPASSRLS and reads everything, as it must.

## Functions

### SECURITY DEFINER

No SECURITY DEFINER function that existed before 1030 can be called by a client, so none of them lets data around the gate.

| Function | Callable by | Bypasses RLS? | Assessment |
|---|---|---|---|
| accept_legal_documents | authenticated | Yes, writes one row | New. Identity from the token; open by design |
| get_legal_status | authenticated | Yes, legal rows only | New. Caller's own status; open by design |
| has_current_legal_acceptance | authenticated | Yes, legal rows only | New. Caller only |
| legal_gate_passes | authenticated | Yes, legal rows only | New. The policies need EXECUTE; reveals only the caller's state |
| legal_gate_open_for_user | movemark_api | Yes, legal rows only | New. Takes any user id, so never granted to clients |
| legal_status_for_user | movemark_api | Yes, legal rows only | New. Same |
| legal_user_has_current_acceptance | owner only | Yes, legal rows only | New. Internal |
| delete_user_owned_data | movemark_api | Yes | Must stay ungated: account deletion |
| delete_auth_user | movemark_api | Yes | Must stay ungated: account deletion. Cascades acceptances |
| delete_property_owned_data | movemark_api | Yes | Reachable only through `DELETE /api/properties/{id}`, gated in the API |
| consume_report_credit | movemark_api | Yes | Called inside enqueue, which is gated |
| grant_report_credit | movemark_api | Yes | RevenueCat webhook; open by design, no rental data |
| claim_next_export_job | movemark_worker | Yes | See "Queued exports" |
| reap_stuck_export_jobs | movemark_worker | Yes | Housekeeping |
| evidence_files_before_insert, evidence_files_before_update | trigger only | Yes | Cannot be called; fire only on a write RLS already allowed |

### SECURITY INVOKER, callable by clients

These run as the caller, so the gate reaches them through RLS. Tested on real Neon: a blocked caller gets empty results.

| Function | Blocked caller gets |
|---|---|
| get_property_snapshot | `property: null`, all arrays empty |
| get_property_snapshot_v2 | `property: null`, all arrays empty, counts 0 |
| get_room_entries_page, get_entry_photos_page, _entry_payload | Empty pages |
| get_vault_summaries | `[]` |

`publish_legal_document` and `legal_documents_append_only` are owner-only or trigger-only.

## Gaps found

Closed:

1. **Snapshot RPCs returned maintenance issues to a blocked caller.** Both RPCs select `maintenance_issues` by property id, and that table's policy checks only user_id, so with wave one alone a blocked renter got issue text back. Closed by 1050, with direct reads of checklists, disputes and dispute links.
2. **Policy recursion.** Postgres refuses to re-enter a table whose policies contain a subquery, and the gate adds a subquery. `UPDATE inspections` and `UPDATE disputes` would have returned 42P17 (HTTP 500) instead of 42501. Both came from dead policies (`inspections_update_own`, `disputes_update_own`; `authenticated` has had no UPDATE on either since 0960), so 1040 and 1050 drop them. A test now expands every command on every client table.
3. **`neon_owner_gate.sql` was already failing.** Its "only get_property_snapshot is client-callable" check had been stale since 0990. It now lists the allowed functions.

Open, accepted or needing a decision:

1. **Signed URLs outlive the gate.** A presigned link issued before a block keeps working until it expires: evidence and documents 1 hour, exports 15 minutes, uploads 10 minutes. They cannot be revoked. A renter who had accepted the previous version already had access to that object, so this only delays the block.
2. **`profiles` stays readable and writable while blocked.** It holds name and email, which are the renter's own. Deliberate.
3. **`GET /api/account/report-credits` stays open.** A balance only, needed by restore-purchases flows. Deliberate; easy to change.
4. **Reads fail silently.** A blocked SELECT is HTTP 200 `[]`, and UPDATE and DELETE match nothing, also 200 `[]`. Only INSERT errors. Clients must read status first and must not treat an empty list as "no rentals" (see the rollout plan).

## Queued exports

A client cannot create an export row (0930), and the API's enqueue routes are gated, so nobody blocked can queue one. A job queued before a new version was published still builds, deliberately: the renter may have spent a credit on it, and failed exports are not refunded. The worker holds no legal function grant. The PDF reaches nobody until they accept, because `GET /api/exports/{id}/download`, `GET /api/exports` and the `exports` table are all gated. `test_a_job_queued_before_a_new_version_builds_but_cannot_be_collected_until_accepted` covers this.

## API routes

`tests/test_legal_gate.py` in the API repo takes the route list from the app itself, so a new route is refused for a blocked user or fails the test until it is listed as open.

| Open to a signed-in, unaccepted renter | Reason |
|---|---|
| `DELETE /api/account` | Deletion never depends on acceptance |
| `GET /api/account/report-credits` | Balance only |
| `GET /api/legal/status` | The gate's own status |

No token involved: `/`, `/api/health`, `/api/ready`, `/api/webhooks/revenuecat`, `/reset`, `/.well-known/apple-app-site-association`. The password-reset links stay open because a locked-out renter must still be able to reset a password.

Everything else under `/api/exports`, `/api/vaults`, `/api/disputes`, `/api/properties` (capabilities and rental delete) and `/api/storage` returns 403 `LEGAL_ACCEPTANCE_REQUIRED`.
