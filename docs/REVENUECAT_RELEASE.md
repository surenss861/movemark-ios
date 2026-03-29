# RevenueCat API key (App Store public SDK)

## Behavior

- **Debug and Release** both use the same path: merged `Info.plist` key `RevenueCatPublicAPIKey`, populated from the target build setting `REVENUECAT_APP_STORE_PUBLIC_KEY` (see `movemork/Info.plist`).
- `SubscriptionManager` **only** accepts RevenueCat **App Store public SDK** keys (`appl_…`). **Test Store** keys (`test_…`) are rejected in every configuration.

## Optional override

- Scheme / CI: `REVENUECAT_PUBLIC_API_KEY=appl_…` is used when the plist value is empty.

## Before archiving

1. Xcode → **MoveMark** target → **Build Settings** → search `REVENUECAT`.
2. Confirm **Debug** and **Release** both set `REVENUECAT_APP_STORE_PUBLIC_KEY` to your RevenueCat **App Store** public key ([RevenueCat → API keys → App Store](https://app.revenuecat.com/)).
3. **Product → Clean Build Folder** → **Archive** → TestFlight.

## Verify

- Subscriptions / offerings load without “Invalid API Key” or Test Store warnings.
- In RevenueCat, the app **bundle id** matches the shipped app (`movemark.movemork` or your production id).
