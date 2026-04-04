# MoveMark — final issue board (3 columns only)

Use this for **triage**, not scope creep. Detailed steps live in [RELEASE_CHECKLIST.md](./RELEASE_CHECKLIST.md).

**Railway note:** `npm error signal SIGTERM` after `listening on 0.0.0.0:8080` is usually **container stop / redeploy**, not proof the Node app threw. Chase it only with healthcheck config, uncaught exceptions **before** SIGTERM, or correlated 5xx / failed requests.

---

## P0 — ship blocker

Only: **crash**, **silent data loss**, **broken save/reopen truth**, **broken export/share**, **broken dispute packet path for new rows**, **permission dead-end**.

| Item | Status |
|------|--------|
| Cold launch (Release / TestFlight) — no `fatalError` from missing Supabase/API keys | Verify on device after xcconfig `https:/$()/$(/)` fix |
| Auth, onboarding, sign-out / sign-in (incl. other user) | Verify |
| Move-in / move-out save → reopen — title, notes, tags, photos, thumbnails | Verify |
| Move-out tags persist | Fixed in code — confirm on device |
| Supporting docs — upload, immediate preview, reopen vault, preview again | Verify |
| Maintenance — list matches store; add / follow-up / resolve; list updates | Fixed store path — verify |
| Export — queue, verify shows Processing when appropriate, share/download | Verify |
| Dispute — draft, local PDF, formal packet; **new** rows store **storage path** not signed URL only | Fixed for new packets — verify + deploy edge fn |
| Camera / library — denied → Settings path, not black screen | Fixed helper — verify |

---

## P1 — before broader beta (not ship-blocker unless horrible on device)

| Item | Notes |
|------|--------|
| Secondary vault cards show `0` open issues | Documented limitation — improve copy or hydrate if product requires |
| Vault cover card expansion jump | Polish |
| Edge Function CORS `*` vs API tightening | Consistency / security cleanup |
| Subscription `customerInfoStream` lifecycle | Improved — re-verify after auth changes |
| Debug `print` outside `#if DEBUG` | Audit when convenient |
| Legacy **dispute** rows with bad `file_path` (full URL) | Migrate or regenerate; new packets OK |

---

## Nice-to-have — after release

- Micro spacing / typography polish  
- Small animation tweaks  
- Formatter / tiny perf wins  
- Extra empty-state copy  

---

## How to use

1. **Nothing moves to P0** without a **device repro** or **data proof**.  
2. **Railway SIGTERM-only** logs → not a board item until tied to a failing route or 5xx.  
3. Before each upload: `./scripts/validate_release_for_distribution.sh` + **Pass 1** in [RELEASE_CHECKLIST.md](./RELEASE_CHECKLIST.md).
