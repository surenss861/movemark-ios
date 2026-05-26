# Android mock billing QA

Use **`BILLING_MODE=mock`** in `movemark-android/local.properties` (default when `REVENUECAT_PUBLIC_KEY` is empty).

No Google Play Console or license tester required.

## Prerequisites

```properties
BILLING_MODE=mock
REVENUECAT_PUBLIC_KEY=
```

Rebuild and install debug build after changing `local.properties`.

## Checklist

| # | Test | Expected | Pass |
|---|------|----------|------|
| 1 | Account → Plan | **MoveMark Free** / pill **Current** | |
| 2 | Account → About | **Billing mode: Mock (local QA)** | |
| 3 | Vault → Add (with 1 vault already) | Paywall: “Free includes 1 proof vault.” | |
| 4 | Vault → Move-out proof (Free) | Paywall: “Move-out proof needs Pro.” | |
| 5 | Reports → Move-out CTA (Free) | Paywall: “Move-out reports need Pro.” | |
| 6 | Reports → Dispute CTA (Free) | Paywall: “Dispute tools need Pro.” | |
| 7 | Paywall → **Unlock Pro for testing** | Banner: “Test billing mode…”; mock prices load | |
| 8 | After unlock | Account: **MoveMark Pro** / **Active**; footer mentions test mode | |
| 9 | Pro gates | Second vault, move-out proof, move-out/dispute reports unlock | |
| 10 | Account → **Reset test subscription** | Back to **MoveMark Free**; gates lock again | |
| 11 | Paywall / restore errors | No raw RevenueCat, BillingClient, or HTTP text | |
| 12 | `./gradlew :app:assembleRelease` | Compiles with `BILLING_MODE=revenuecat` (release type) | |

## Quick paths

- **Unlock Pro:** Account → “Unlock Pro for testing” → paywall → **Unlock Pro for testing**
- **Reset:** Account → **Reset test subscription** (only visible when mock + Pro)

## Notes

- Move-in report export is **not** Pro-gated on Android today; move-out report and dispute packet are Pro-gated.
- Release builds use `BILLING_MODE=revenuecat` from Gradle; set `REVENUECAT_PUBLIC_KEY` before Play internal testing.
