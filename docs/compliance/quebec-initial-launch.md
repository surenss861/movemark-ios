# Quebec at the initial Consumer launch (temporary restriction)

Owner decision, 2026-11-09: MoveMark Consumer isn't offered to Quebec residents until French Terms, Privacy Policy and
purchase text exist. This is temporary. It is not legal advice, and a self-declared answer doesn't guarantee compliance.

## What the app and the server do

- **The question.** The agreement screen asks everyone "Do you live in Quebec?" (Yes / No), before the age question.
  Nothing else about location is asked or derived: no GPS, no IP geolocation, no province or postal code.
- **"Yes"** (any age): "MoveMark isn't available in Quebec yet. We're preparing French-language support. Your account
  hasn't been set up. You can delete it below, or we'll remove it." The age question isn't shown, Continue is gone, the
  main action is "Delete my account" (it opens the usual confirmation in `DeleteAccountView`), and Sign out stays.
  Nothing is sent to the server. There's no automatic deletion: a mis-tap must not erase an existing renter's evidence.
- **"No"**: the age range as before. 13 outside Quebec is the teen range; under 13 stops as before. The Quebec 14+
  rule is moot while Quebec is closed.
- **Server, migration 1057** (`neon/migrations/1057_quebec_residence.sql`): requirement code `bands_v2`. Only the
  six-argument `accept_legal_documents(..., p_age_band, p_lives_in_quebec)` can accept. `true` gives
  `LEGAL_REGION_NOT_AVAILABLE` and writes nothing (not even a counter: the exception rolls the call back). `null` gives
  `LEGAL_REGION_REQUIRED`. `false` stores `residence = 'outside_quebec'` with the acceptance. The older 3-, 4- and
  5-argument calls can't accept under `bands_v2`; the 3-argument call is refused even while enforcement is off.
- **Enforcement** (`legal_gate_settings.enforced`): unchanged mechanism. Once on, only a `bands_v2` acceptance (which
  can't exist without a recorded "No") opens the Data API policies and the API. Until then nothing is gated server-side.

## Existing accounts

No account has a recorded residence. Under `bands_v2`, `get_legal_status.acceptance_required` stays true until the
account accepts with the Quebec answer, so every existing account sees the agreement screen at its next launch or
foreground (1.4 builds with this change), including accounts that accepted on RC3 without the question.

- Answers "No": accepted as usual; the earlier acceptance row keeps its time and method and gains the answer.
- Answers "Yes": nothing recorded. The renter can delete the account from the screen. Their data stays until they do,
  or until the owner-approved clean-up below. With enforcement off, a modified client could still read it; with
  enforcement on, the Data API and API refuse it (account deletion stays open).
- **Clean-up (owner decision, not implemented):** the screen's "or we'll remove it" needs a process. Because a "Yes" is
  never stored, the only safe selector is "no current acceptance". Proposal: after enforcement, email accounts with no
  current acceptance for 60 days, offer an export, and delete at 90 days through the existing deletion path. If the
  owner doesn't approve a clean-up before launch, change the copy to end at "You can delete it below."

## When French ships

Add a new requirement code (for example `bands_v3`) whose accept function takes a Quebec "Yes" (with French documents
offered first), move the switch to it in a migration, and drop the Quebec stop in the apps.

See `_scratch/compliance-gaps.md` section E for the reasoning and the remaining legal and store risks.
