# RevenueCat API key (App Store public SDK)

## Behavior

- **Debug and Release** both use the same path: merged `Info.plist` key `RevenueCatPublicAPIKey`, populated from the target build setting `REVENUECAT_APP_STORE_PUBLIC_KEY` (see `movemork/Info.plist`).
- **Default Release:** `SubscriptionManager` accepts only RevenueCat **App Store** public SDK keys (`appl_…`).
- **Debug:** `test_…` **Test Store** keys are also accepted so you can load offerings and exercise the paywall without App Store subscription review.
- **Release + Test Store (internal TestFlight only):** add Swift compilation flag `REVENUECAT_ALLOW_TEST_STORE_KEY` on the **MoveMark** target **Release** configuration (see below). Remove the flag before shipping to the App Store.

## Optional override

- Scheme / CI: `REVENUECAT_PUBLIC_API_KEY=appl_…` or `test_…` (when Test Store is allowed for that build) is used when the plist value is empty.

## Test Store checklist (unblocks paywall dev)

1. RevenueCat → **Test Store** → products, packages, and a **current** offering (not only App Store products on that offering).
2. Set `REVENUECAT_APP_STORE_PUBLIC_KEY` to your **`test_…`** public key (despite the setting name, it feeds `RevenueCatPublicAPIKey`).
3. **Debug:** run on device/simulator — no extra flags.
4. **Internal TestFlight (Release):** Xcode → **MoveMark** target → **Build Settings** → **Swift Compiler - Custom Flags** → **Active Compilation Conditions** → add `REVENUECAT_ALLOW_TEST_STORE_KEY` for **Release** only while testing; archive and upload; **remove** the flag before a production App Store build.
5. Switch the same setting back to **`appl_…`** when validating real StoreKit.

## Before App Store archive

1. Xcode → **MoveMark** target → **Build Settings** → search `REVENUECAT`.
2. Confirm **Release** has **`appl_…`** only and **does not** define `REVENUECAT_ALLOW_TEST_STORE_KEY`.
3. **Product → Clean Build Folder** → **Archive** → TestFlight / App Store.

## Verify

- Subscriptions / offerings load without “Invalid API Key” or wrong-store warnings.
- In RevenueCat, the app **bundle id** matches the shipped app (`movemark.movemork` or your production id).
