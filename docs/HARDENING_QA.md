# MoveMark — Hardening & QA

## Formal packet field parity (done)

- Edge function **generate-dispute-packet** reads and renders **move_out_date**, **received_itemized**, **charge_date** in the formal packet HTML so output matches the simple PDF.
- Deploy: `supabase functions deploy generate-dispute-packet`.

---

## End-to-end QA checklist

Run as one full app pass before treating the app as production-ready.

- [ ] Sign in
- [ ] Add property
- [ ] Confirm default rooms
- [ ] Save move-in evidence in at least 2 rooms
- [ ] Upload lease + deposit receipt + listing screenshot
- [ ] Create maintenance issue with photos
- [ ] Add follow-up and resolve it
- [ ] Complete some move-out checklist items
- [ ] Save move-out proof in at least 1 room
- [ ] Save dispute draft with all 3 fields (move-out date, itemized, charge date)
- [ ] Reopen dispute draft and verify restore
- [ ] Export simple PDF
- [ ] Generate formal packet
- [ ] Confirm export rows appear
- [ ] Share each export
- [ ] Sign out
- [ ] Relaunch and confirm signed-out state

---

## Hardening slices (by area)

### Auth / session

- Signed in → force quit → relaunch → still signed in
- Signed out → force quit → relaunch → signed out
- Onboarding only when needed; no stale property after sign out

### Property

- Add Property sheet opens; required fields; create inserts; default rooms; Vault loads after creation

### Room evidence

- Photos, tags, notes, condition; save and reload; Walkthrough/Vault counts update; move-out mode saves to move-out evidence

### Supporting documents

- Lease, deposit, listing upload; status missing → uploaded; replace; share from history where applicable

### Maintenance

- Create issue; category; detail load; follow-up; mark resolved; evidence in detail

### Move-out

- Checklist load/save; readiness summary; move-out room capture; move-out report export

### Dispute Builder

- Case fields save; draft restore; evidence/maintenance/document selections persist; simple PDF; formal packet; move-out date, itemized, charge date in both exports

### Export History

- Rows appear; share for storage path (signed URL); share for direct URL (formal); missing path shows error

### Multi-account

- User A cannot see User B property/evidence/documents/exports; sign out + sign in as another clears state

### UX

- Loading/error/success styles consistent; no silent failures; retry where appropriate
