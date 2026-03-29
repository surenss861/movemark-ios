# RevenueCat API key (App Store public SDK)

## Behavior

- **Debug and Release** both use the same path: merged `Info.plist` key `RevenueCatPublicAPIKey`, populated from the target build setting `REVENUECAT_APP_STORE_PUBLIC_KEY` (see `movemork/Info.plist`).
- **Debug:** `test_…` **Test Store** keys are accepted (`#if DEBUG`).
- **Release (including TestFlight archives):** the MoveMark target sets Swift **`REVENUECAT_ALLOW_TEST_STORE_KEY`**, so **`test_…`** keys work on TestFlight without manual flags. **App Store builds:** remove that compilation condition from **Release** (or keep it only if you always embed `appl_…` and never ship a `test_…` key).
- **`appl_…`:** always accepted in every configuration.

## Optional override

- Scheme / CI: `REVENUECAT_PUBLIC_API_KEY=appl_…` or `test_…` (when Test Store is allowed for that build) is used when the plist value is empty.

## Test Store checklist (unblocks paywall dev)

1. RevenueCat → **Test Store** → products, packages, and a **current** offering (not only App Store products on that offering).
2. Set `REVENUECAT_APP_STORE_PUBLIC_KEY` to your **`test_…`** public key (despite the setting name, it feeds `RevenueCatPublicAPIKey`).
3. **Debug:** run on device/simulator — no extra flags.
4. **TestFlight:** **Release** already includes `REVENUECAT_ALLOW_TEST_STORE_KEY` in the Xcode project; set `REVENUECAT_APP_STORE_PUBLIC_KEY` to **`test_…`** and archive. Before a **production App Store** submission, switch the build setting to **`appl_…`** and remove `REVENUECAT_ALLOW_TEST_STORE_KEY` from the MoveMark target **Release** config if you want Release to reject Test Store keys entirely.
5. Switch back to **`appl_…`** when validating real StoreKit / shipping to the App Store.

## Before App Store archive

1. Xcode → **MoveMark** target → **Build Settings** → search `REVENUECAT`.
2. Confirm **Release** uses your RevenueCat **App Store** public key **`appl_…`** (not `test_…`).
3. Optional hardening: remove **`REVENUECAT_ALLOW_TEST_STORE_KEY`** from **Release** → **Active Compilation Conditions** so a mistaken `test_…` key fails fast.
4. **Product → Clean Build Folder** → **Archive** → App Store Connect.

## Verify

- Subscriptions / offerings load without “Invalid API Key” or wrong-store warnings.
- In RevenueCat, the app **bundle id** matches the shipped app (`movemark.movemork` or your production id).
