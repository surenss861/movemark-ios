# RevenueCat API key (App Store public SDK)

## If logs show `keyPrefix=appl_…` but you want Test Store

`SubscriptionManager` logs **`keyPrefix=`** on refresh. **`appl_`** means the runtime picked the **App Store** key path.

### Preferred: separate Test Store key (keep `appl_…` in git)

1. Xcode → **MoveMark** target → **Build Settings** → **User-Defined** (or search): set **`REVENUECAT_TEST_STORE_PUBLIC_KEY`** to your RevenueCat **`test_…`** public SDK key.  
   - Leave **`REVENUECAT_APP_STORE_PUBLIC_KEY`** as **`appl_…`** for App Store / production.  
2. **Debug** and **Release** both include the setting (repo default is empty `""` → Test key ignored → falls back to **`appl_…`**).  
3. Merged **Info.plist** includes **`RevenueCatTestStorePublicAPIKey`** = `$(REVENUECAT_TEST_STORE_PUBLIC_KEY)`.  
4. When **Test Store is allowed** (Debug, or Release with `REVENUECAT_ALLOW_TEST_STORE_KEY`), the app uses the test key **first** (then env **`REVENUECAT_TEST_STORE_PUBLIC_KEY`** on the run scheme if set).  
5. Clean build, reinstall — logs should show **`keyPrefix=test_…`**.

### Alternate: replace the App Store setting

Set **`REVENUECAT_APP_STORE_PUBLIC_KEY`** to **`test_…`** only if you are fine committing or local-overriding the primary key.

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

## Test Store mirror (aligned with the app)

Use the **same entitlement identifier as production** so `hasPro` works without code forks:

| RevenueCat (Test Store) | Value |
|-------------------------|--------|
| **Entitlement** | **`movemark_pro1`** (not `test` — the app never checks `test`) |
| **Products** | **`testmonthly`**, **`testyearly`** |
| **Offering** | Any identifier (e.g. **`default`** or **`testdefault`**) — see below |
| **Packages** | e.g. **`src_annual`** → **`testyearly`**, **`src_monthly`** → **`testmonthly`** (identifiers are up to you) |

### Mark the Test Store offering as **Current** (required)

The SDK uses **`offerings.current`** only. RevenueCat returns whichever offering you set as the **current** offering in the dashboard — **not** “the one named `default`” by magic.

- If your Test Store offering is named **`testdefault`**, you **must** set **`testdefault` as Current** while testing with the **`test_…`** key. Otherwise the paywall will still load a different offering (or none).
- **Alternative (not implemented in the app):** fetch a specific offering by id, e.g. `offerings["testdefault"]`, and keep production’s current offering separate — more work; prefer making the Test offering **Current** for speed.

Attach **both** products to entitlement **`movemark_pro1`**. Order packages **yearly first, monthly second** in the offering so the paywall matches “best value” ordering (the app also sorts yearly ahead when it can infer plan kind).

**In code:** `SubscriptionManager` uses `movemark_pro1` only. `ProPaywallView` recognizes store product IDs **`monthly_subscription` / `yearly_subscription`** (App Store) and **`testmonthly` / `testyearly`** (Test Store mirror) for labels, default selection, and sorting.

### Optional: force a specific offering id (debug)

If RevenueCat’s **Current** offering is wrong but another id (e.g. a typo like `testdeault`) has the right packages, add to the app target **Info** (custom property) or build setting → merged plist:

- **`RevenueCatOfferingOverride`** = exact offering identifier string  

`SubscriptionManager.refresh()` will use that offering when present in `offerings.all`. Remove when `offerings.current` is correct.

**Simulator:** RevenueCat warns unless a **StoreKit Configuration** file is attached to the scheme with the same product ids the SDK loads; use a **device** for clearer Test Store behavior.

## Before App Store archive

1. Xcode → **MoveMark** target → **Build Settings** → search `REVENUECAT`.
2. Confirm **Release** uses your RevenueCat **App Store** public key **`appl_…`** (not `test_…`).
3. Optional hardening: remove **`REVENUECAT_ALLOW_TEST_STORE_KEY`** from **Release** → **Active Compilation Conditions** so a mistaken `test_…` key fails fast.
4. **Product → Clean Build Folder** → **Archive** → App Store Connect.

## Verify

- Subscriptions / offerings load without “Invalid API Key” or wrong-store warnings.
- In RevenueCat, the app **bundle id** matches the shipped app (`movemark.movemork` or your production id).
