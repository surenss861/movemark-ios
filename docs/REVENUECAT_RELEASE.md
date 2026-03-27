# RevenueCat API key: Debug vs Release / TestFlight

## Why Simulator worked but TestFlight showed “Invalid API Key”

- **Debug** builds use a hardcoded RevenueCat **Test Store** key (`test_…`) in `SubscriptionManager` — fine for Simulator and local dev.
- **Release** (archives, TestFlight, App Store) must use your RevenueCat **App Store public SDK** key (`appl_…`). It is **not** the same as the test key.

## What we did in the project

- **Release** injects `RevenueCatPublicAPIKey` into the merged Info.plist from an Xcode build setting:
  - `REVENUECAT_APP_STORE_PUBLIC_KEY`
- `SubscriptionManager` reads that value in Release and **rejects** `test_` keys so TestFlight cannot accidentally ship with the wrong key type.

## What you must do before archiving

1. Open **Xcode** → select the **MoveMark** app **target** (not the project only).
2. **Build Settings** → **All** → search for `REVENUECAT`.
3. You should already see **`REVENUECAT_APP_STORE_PUBLIC_KEY`** on the target (declared in the project; default **empty** for Release). **Do not** add a duplicate User-Defined setting with the same name.
4. For the **Release** column, paste your **App Store** public SDK key from [RevenueCat → Project → API keys → App Store](https://app.revenuecat.com/) (starts with `appl_`).

   The repo ships **Release** with this value **empty** on purpose so the real key is not committed. Set it locally (or inject via CI as the same build setting).

**Note:** Debug simulator builds still use the hardcoded RevenueCat **test** key in code; TestFlight/App Store builds use this **Release** value via the merged Info.plist.

5. **Product → Clean Build Folder** → **Archive** → upload to TestFlight.

### Optional: environment variable (CI)

For Release archives built in CI, you can set:

`REVENUECAT_PUBLIC_API_KEY=appl_your_key`

in the scheme environment or the CI job; `SubscriptionManager` reads it when Info.plist is empty.

## Verify

After installing a TestFlight build, subscriptions / offerings should load without “Invalid API Key”. If you still see errors, confirm in RevenueCat that the **bundle id** matches `movemark.movemork` (or your production id) for that project.
