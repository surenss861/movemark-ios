# MoveMark release checklist

Built to stop scope creep and focus on **App Store readiness**. Pair with `./scripts/validate_release_for_distribution.sh` (Release plist + privacy checks) before archiving.

---

## P0 — must pass before release

### 1) Launch and auth

- [ ] Cold launch from TestFlight succeeds  
- [ ] Sign up works  
- [ ] Sign in works  
- [ ] Forgot password sends reset email and shows confirmation inline  
- [ ] Onboarding name save works  
- [ ] Sign out returns user to Welcome  
- [ ] Sign back in works cleanly after sign out  

### 2) Property creation

- [ ] User can create a property vault  
- [ ] Validation works correctly  
- [ ] Country picker behaves correctly  
- [ ] Free tier blocks second property and shows paywall  
- [ ] New vault appears immediately after creation  

### 3) Move-in walkthrough

- [ ] Open room detail successfully  
- [ ] Photo library import works  
- [ ] Camera button works with permission handling  
- [ ] Denied camera permission shows Settings alert, not black screen  
- [ ] Tags wrap correctly and save correctly  
- [ ] Condition rating saves correctly  
- [ ] First save in an empty room shows vault feedback toast  
- [ ] Saved proof entries reopen with: correct title, notes, tags, photo count, thumbnails  
- [ ] Edit / add photos / delete all work  

### 4) Move-out walkthrough

- [ ] Move-out foundation screen loads  
- [ ] Room cards show move-in vs move-out counts correctly  
- [ ] Move-out evidence save works  
- [ ] **Move-out tags persist after reopen**  
- [ ] First move-out save triggers move-out feedback toast  
- [ ] Checklist toggles save correctly  
- [ ] If checklist save fails, toggle rolls back visually  
- [ ] Back navigation returns to foundation screen with updated room state  

### 5) Supporting records

- [ ] Upload lease works  
- [ ] Upload deposit receipt works  
- [ ] Upload listing screenshot works  
- [ ] Immediate preview works after upload  
- [ ] Leave vault and reopen: preview still works  
- [ ] Replace works  
- [ ] Delete works  
- [ ] Supporting record state contributes correctly to readiness  

### 6) Maintenance

- [ ] Maintenance list loads from store truth  
- [ ] Add maintenance issue works  
- [ ] Evidence/photos work  
- [ ] Edit / follow-up works  
- [ ] Resolve works  
- [ ] Returning to list reflects updated truth immediately  
- [ ] Vault/readiness/open-issue state stays consistent with maintenance list  

### 7) Exports

- [ ] Move-in export button only enables when appropriate  
- [ ] Free tier export limit works per user  
- [ ] Export queue request succeeds  
- [ ] Success message is shown as success styling, not error styling  
- [ ] Exports tab only shows exports for selected vault  
- [ ] No-vault state shows correct empty state  
- [ ] Verify on queued export shows **Processing**, not failed  
- [ ] Completed export can be shared  
- [ ] Download/share path works from current export rows  

### 8) Dispute builder

- [ ] Loads room photos, maintenance, and documents  
- [ ] Evidence labels are meaningful, not UUID junk  
- [ ] Save draft works  
- [ ] Local dispute PDF export works  
- [ ] Long evidence lists do not render off-page  
- [ ] Formal packet generation works  
- [ ] Share sheet opens successfully  
- [ ] New formal packets store storage path correctly, not expiring signed URL  

### 9) Release / production hygiene

- [ ] Release config validation script passes (`./scripts/validate_release_for_distribution.sh`)  
- [ ] TestFlight build launches  
- [ ] Required keys exist in Release (Supabase, API base URL, RevenueCat)  
- [ ] Camera / photo privacy strings exist  
- [ ] No fatal startup config crash  
- [ ] No obvious production debug artifacts in critical flows  

---

## P1 — should be nice before wider rollout

Worth doing; **should not block** a small beta unless they reproduce badly on device.

- Vault card expansion jump polish  
- Secondary vault cards showing `0 open issues` for non-active properties  
- Edge Function CORS consistency cleanup  
- Subscription listener lifecycle cleanup after sign-out *(partially addressed in code; re-verify if you change auth)*  
- Any remaining debug print audit outside `#if DEBUG`  
- Minor formatter/perf micro-cleanups  

---

## Defer unless it reproduces

Do **not** burn time here unless it fails on device.

- Supporting docs bug that cannot be reproduced  
- Maintenance truth bug that cannot be reproduced  
- Export verify bug if 409 → Processing is already confirmed  
- Camera permission regression if current helper path works  
- PDF overflow if current wrapped-layout fix holds  
- Evidence filename fallback bug if labels are now sane  
- Preview URL expiry issue if current refresh/expiry behavior is stable  

---

## Classification rule

For any new issue, pick one: **Ship blocker** · **Post-release** · **Ignore unless repro**.

---

## Device test script — Pass 1 (≈10 min smoke)

_Real device; fresh install if possible._  
_Build: ________ · iOS: ________ · Tester: ________ · Date: ________*

### Auth

- [ ] Launch app  
- [ ] Sign in — no crash  
- [ ] Sign out  
- [ ] Sign back in  

### Vault

- [ ] Open existing vault (or create if needed)  
- [ ] Open walkthrough  

### Move-in

- [ ] Open a room  
- [ ] Add photo from library  
- [ ] Save with title, notes, tags  
- [ ] Reopen saved proof — tags/photos still there  

### Move-out

- [ ] Open move-out → open a room  
- [ ] Add photo, save with tags  
- [ ] Reopen — **tags persist**  

### Supporting docs

- [ ] Upload one document → preview immediately  
- [ ] Back out, reopen vault → preview again  

### Maintenance

- [ ] Add issue → reopen  
- [ ] Mark resolved or add follow-up  
- [ ] Return to list — state updated  

### Export

- [ ] Queue move-in export  
- [ ] Exports tab — Verify on queued item shows **Processing** if not done  

### Account

- [ ] Open Account  
- [ ] Password reset flow / legal link as configured  
- [ ] Sign out  

**Pass 1 result:** ☐ Pass ☐ Fail — notes:  

---

## Device test script — Pass 2 (deeper, pre–wider beta)

### Multi-step truth

- [ ] Create evidence → leave → reopen  
- [ ] Switch tabs → return — truth holds  
- [ ] Kill app → relaunch — truth holds  
- [ ] Sign out → sign in — user-scoped state correct  

### Export / dispute

- [ ] Full export → share  
- [ ] Dispute builder → save draft  
- [ ] Local dispute PDF  
- [ ] Formal packet → share  
- [ ] Confirm new packets use **storage path** in backend (not only signed URL in DB)  

### Permissions

- [ ] Camera denied → Settings path, no black screen  
- [ ] Camera granted  
- [ ] Photo library path  

**Pass 2 result:** ☐ Pass ☐ Fail — notes:  

---

## Release signoff

### Ship blockers

- [ ] No launch crash in TestFlight  
- [ ] No silent data loss in move-in / move-out / docs / maintenance  
- [ ] No broken export/share flow  
- [ ] No broken dispute packet generation  
- [ ] No permission dead-end  
- [ ] No save/reopen truth failures in core flows  

### Known acceptable non-blockers (document only)

- [ ] Vault card animation polish  
- [ ] Secondary vault open-issue summary limitation  
- [ ] Minor listener/CORS cleanup  
- [ ] Cosmetic debug/perf cleanup only  

### Final decision

- [ ] Internal TestFlight only  
- [ ] Ready for broader beta  
- [ ] Ready for App Store submission  

### Rollout rule

- **All P0 pass on-device (TestFlight)** → OK for **broader beta**  
- **1–2 P1 remain** → still OK if P0 is green  
- **Any P0 fails** → do not widen rollout  

| Role | Name | Date | Build # |
|------|------|------|---------|
| Build owner | | | |
| QA | | | |

---

## Related

- [ISSUE_BOARD.md](./ISSUE_BOARD.md) — **P0 / P1 / nice-to-have** only (triage; Railway SIGTERM note)  
- `scripts/validate_release_for_distribution.sh` — Release build + Info.plist validation  
- `Config/Secrets.xcconfig.example` — Supabase URL must use `https:/$()/$(/)…` (xcconfig `//` comment trap)  
