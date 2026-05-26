# Android Play Billing + RevenueCat setup

Use this when the **$25 Play Console** account is ready. Keep **mock mode** for day-to-day emulator dev.

## Modes

| Mode | `local.properties` | When |
|------|-------------------|------|
| Mock | `BILLING_MODE=mock` | Local emulator QA |
| Live | `BILLING_MODE=revenuecat` + `REVENUECAT_PUBLIC_KEY` | Internal / closed testing from Play |

Release APK/AAB always sets `BILLING_MODE=revenuecat` in Gradle.

Package name (do not change):

```text
com.surensureshkumar.movemark
```

## 1. Google Play Console

1. Register developer account ($25 one-time).
2. Create app **MoveMark** (Free app).
3. **Monetize → Subscriptions** — create:

| Product ID | Base plan | Period |
|------------|-----------|--------|
| `movemark_pro_monthly` | `monthly` | Monthly |
| `movemark_pro_yearly` | `yearly` | Yearly |

Activate each base plan with pricing. Product IDs cannot be renamed later.

4. **Settings → License testing** — add tester Gmail addresses.
5. **Testing → Internal testing** — upload signed AAB, add testers, share opt-in link.

## 2. RevenueCat

1. **Apps & providers → Add Google Play** — package `com.surensureshkumar.movemark`.
2. Copy **Google public SDK key** → `REVENUECAT_PUBLIC_KEY` in `local.properties`.
3. **Google Play service credentials** — create service account in Google Cloud, invite in Play Console, upload JSON to RevenueCat ([RevenueCat docs](https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials)).
4. **Products** — import `movemark_pro_monthly`, `movemark_pro_yearly`.
5. **Entitlements** — attach both to `movemark_pro1` (same as iOS).
6. **Offerings → Current** — monthly → monthly product, annual → yearly product.

## 3. Android app config

```properties
BILLING_MODE=revenuecat
REVENUECAT_PUBLIC_KEY=goog_xxxxxxxx
```

Build signed release or internal-test bundle, install **from Play test track** (not sideload) for real purchases.

## 4. Internal test QA

| # | Test |
|---|------|
| 1 | Account: MoveMark Free / Current |
| 2 | Paywall loads real monthly + yearly prices |
| 3 | Purchase monthly → Pro / Active |
| 4 | Cancel purchase → no scary error |
| 5 | Restore with subscription → restored message |
| 6 | Restore without subscription → none found |
| 7 | Second vault (Free) → paywall |
| 8 | Pro → second vault works |
| 9 | Manage subscription → Play subscriptions UI |
| 10 | Sign out / in → Pro matches RevenueCat dashboard |

See also [ANDROID_BILLING_QA.md](./ANDROID_BILLING_QA.md) for the full RevenueCat checklist.

## 5. Keep mock for dev

After Play works, developers should keep:

```properties
BILLING_MODE=mock
```

on personal machines so daily work does not require Play installs.
