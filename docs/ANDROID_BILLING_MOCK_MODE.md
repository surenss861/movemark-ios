# Android billing mock mode

MoveMark Android can run subscription flows locally without a Google Play Developer account or Play Console products. Use this for day-to-day development and QA; switch to RevenueCat when Play Billing is ready.

## Why this exists

Real Android subscriptions need Google Play Console setup, Play products, license testers, and a RevenueCat Google Play integration. Until that is in place, `BILLING_MODE=mock` exercises the same app surfaces (paywall, Account plan, second-vault gate) with a local fake Pro state.

## Configuration

In `movemark-android/local.properties` (copy from `local.properties.example`):

```properties
# Default when REVENUECAT_PUBLIC_KEY is empty: mock (debug builds)
# Force mock even with a key present:
BILLING_MODE=mock

# Real billing later (requires Play Console + key):
# BILLING_MODE=revenuecat
# REVENUECAT_PUBLIC_KEY=goog_...
```

| Build | Default `BILLING_MODE` |
|-------|----------------------|
| Debug, no RC key | `mock` |
| Debug, RC key set | `revenuecat` (unless you set `BILLING_MODE=mock`) |
| Release | always `revenuecat` |

On debug startup, logcat shows: `Billing mode: mock` or `Billing mode: revenuecat`.

## Test flow (mock)

1. Install a **debug** build (mock is not used in release).
2. Sign in as a free user with one vault.
3. Try to add a second property → paywall opens.
4. Note: *"Test billing mode. No real purchase will be made."*
5. Tap **Unlock Pro for testing** → brief loading → *"Pro unlocked for testing."*
6. Account shows **MoveMark Pro** / **Active** / **Test mode**.
7. Second vault creation should succeed.
8. **Reset test subscription** (Account, mock only) clears mock Pro.
9. Sign out clears mock Pro in mock mode (fresh free session on next sign-in).

## Restore (mock)

- No mock Pro: *"No active test subscription found."*
- Mock Pro active: *"MoveMark Pro restored for testing."*

## Switching to real billing

When Play Console and RevenueCat are ready:

```properties
BILLING_MODE=revenuecat
REVENUECAT_PUBLIC_KEY=<your_android_public_sdk_key>
```

Rebuild. RevenueCat + Play Billing path is unchanged; mock code is not used in release builds.

## Safety

- Release builds always use `BILLING_MODE=revenuecat`; mock unlock cannot ship in release via this flag.
- Do not commit `local.properties` or API keys.
