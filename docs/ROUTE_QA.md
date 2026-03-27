# MoveMark — Route & flow QA checklist

Use this after nav foundation changes. Stop at the first failure and fix before continuing.

## Auth
- [ ] Signed out launch
- [ ] Welcome → Auth
- [ ] Sign in works
- [ ] Onboarding gate works
- [ ] Signed in lands in Vault root

## Empty state
- [ ] Vault empty state renders
- [ ] Add property opens sheet
- [ ] Close dismisses sheet
- [ ] Create property succeeds
- [ ] Sheet dismisses after success
- [ ] Vault reloads with property

## Vault routes
- [ ] Vault → Account
- [ ] Vault → Walkthrough
- [ ] Vault → Maintenance
- [ ] Vault → Move-out
- [ ] Vault → Dispute Builder
- [ ] Vault → Exports

## Deep routes
- [ ] Walkthrough → Room Detail
- [ ] Maintenance → Issue Detail
- [ ] Back button works everywhere

## UI consistency
- [ ] Vault large title
- [ ] Push screens inline titles
- [ ] Sheet has Close, no back
- [ ] No duplicate nav bars
- [ ] No dead buttons

---

**Next product priorities (after QA is green):**
1. Add Property submit path
2. Room evidence save
3. Maintenance create/update
4. Dispute/export reliability
5. Visual/nav polish
