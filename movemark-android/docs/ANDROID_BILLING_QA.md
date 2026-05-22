# Android billing QA (RevenueCat + Google Play)

Run on an **internal testing** build installed from Play Console with a **license tester** Gmail.

## Prerequisites

- `REVENUECAT_PUBLIC_KEY` set in `movemark-android/local.properties` (Google public key from RevenueCat).
- Play products: `movemark_pro_monthly`, `movemark_pro_yearly` with active base plans.
- RevenueCat: entitlement `movemark_pro1`, offering maps `$rc_monthly` / `$rc_annual`.
- License tester added in Play Console → Settings → License testing.

## Checklist

| # | Test | Pass |
|---|------|------|
| 1 | Account shows **MoveMark Free / Current** when not subscribed | |
| 2 | Paywall loads monthly + yearly prices (no infinite spinner) | |
| 3 | Purchase monthly → **Pro unlocked** → Account **MoveMark Pro / Active** | |
| 4 | Purchase yearly (fresh tester account) → Pro active | |
| 5 | Cancel purchase sheet → no scary error, buttons re-enabled | |
| 6 | Restore with active subscription → “MoveMark Pro restored.” | |
| 7 | Restore with no subscription → “No active subscription found…” | |
| 8 | Vault → **Add another rental** (Free, 1 vault) → paywall “Free includes 1 proof vault.” | |
| 9 | Pro user → **Add another rental** opens create-property flow | |
| 10 | **Manage subscription** opens Play subscriptions page | |
| 11 | Sign out → sign in → Pro state matches RevenueCat dashboard | |

## Notes

- Raw RevenueCat / Play errors must not appear in UI.
- Reports / move-out / dispute limits are TODO for a later gate pass.
