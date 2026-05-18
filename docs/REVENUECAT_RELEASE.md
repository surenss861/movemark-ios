# RevenueCat API key (App Store public SDK)

## Release / TestFlight / App Store (hardened defaults)

The **MoveMark** target is set up so **Release** builds:

- Use **only** the App Store public SDK key **`appl_…`** (`RevenueCatPublicAPIKey` ← `REVENUECAT_APP_STORE_PUBLIC_KEY`).
- Do **not** set Swift **`REVENUECAT_ALLOW_TEST_STORE_KEY`** (Test Store keys and the `test` entitlement bridge are **Debug-only** in code).
- Do **not** embed a per-arch **`test_…`** override in Release (Debug may still set `REVENUECAT_TEST_STORE_PUBLIC_KEY` for local Test Store).

If you need **Test Store on a Release-like configuration** (e.g. internal CI), add **`REVENUECAT_ALLOW_TEST_STORE_KEY`** only to that configuration’s **Active Compilation Conditions** — not to App Store submission archives.

## If logs show `keyPrefix=appl_…` but you want Test Store (Debug)

`SubscriptionManager` logs **`keyPrefix=`** on refresh. **`appl_`** means the runtime picked the **App Store** key path.

### Preferred: separate Test Store key (keep `appl_…` in git)

1. Select the **MoveMark app target** → **Build Settings** → **`REVENUECAT_TEST_STORE_PUBLIC_KEY`** → set your RevenueCat **`test_…`** key for **Debug** (Release column should stay empty for hardened archives).
2. Leave **`REVENUECAT_APP_STORE_PUBLIC_KEY`** as **`appl_…`** for production.
3. Merged **Info.plist** includes **`RevenueCatTestStorePublicAPIKey`** = `$(REVENUECAT_TEST_STORE_PUBLIC_KEY)`.
4. In **Debug**, `SubscriptionManager` prefers the test key when present (then env **`REVENUECAT_TEST_STORE_PUBLIC_KEY`** on the scheme if set).
5. Clean build, reinstall — logs should show **`keyPrefix=test_…`**.

### Alternate: replace the App Store setting (Debug only)

Set **`REVENUECAT_APP_STORE_PUBLIC_KEY`** to **`test_…`** only for local experiments if you accept overriding the primary key in that configuration.

## Behavior

- **Debug:** `test_…` keys are accepted; entitlement **`test`** may count as Pro if **`movemark_pro1`** is not active (dashboard bridge).
- **Release:** only **`appl_…`**; only **`movemark_pro1`** unlocks Pro.
- **Scheme / CI:** `REVENUECAT_PUBLIC_API_KEY=appl_…` is used when the plist value is empty (still validated — `test_…` is rejected in Release).

## Test Store checklist (paywall dev)

1. RevenueCat → **Test Store** → products, packages, and a **current** offering.
2. Run a **Debug** build with **`test_…`** available per above.
3. **TestFlight / App Store:** archive **Release** with **`appl_…`** only; do not rely on Test Store SDK keys in shipped builds.

## Test Store mirror (aligned with the app)

Use the **same entitlement identifier as production** so `hasPro` works without dashboard hacks:

| RevenueCat (Test Store) | Value |
|-------------------------|--------|
| **Entitlement** | **`movemark_pro1`** |
| **Products** | **`testmonthly`**, **`testyearly`** |
| **Offering** | Any identifier — set it as **Current** in the dashboard |
| **Packages** | Map to your product ids |

### If purchases work but Pro never unlocks (entitlement mismatch)

The app treats **`movemark_pro1`** as Pro. In **Debug** only, entitlement **`test`** is also honored when Test Store mode is active.

**Fix in RevenueCat:** attach products **only** to **`movemark_pro1`**.

### Mark the Test Store offering as **Current** (required)

The SDK uses **`offerings.current`** in **Release**. RevenueCat returns whichever offering is **Current** — not “the one named `default`” by name alone.

- If your Test Store offering is **`testdefault`**, set **`testdefault` as Current** while testing with the **`test_…`** key in Debug.

**In code:** `ProPaywallView` recognizes **`monthly_subscription` / `yearly_subscription`** (App Store) and **`testmonthly` / `testyearly`** (Test Store mirror).

### Optional: force a specific offering id (**Debug builds only**)

If **Current** is wrong but another offering has the right packages, add to **Debug** Info.plist:

- **`RevenueCatOfferingOverride`** = exact offering identifier (e.g. `default`)

Leave this key **unset** in normal development so the SDK uses RevenueCat’s **Current** offering. **Release ignores this key** — always `offerings.current`.

Delete or fix any offering with **zero packages** in the dashboard; RevenueCat will warn even if the app resolves a different offering.

**Simulator:** attach a **StoreKit Configuration** to the scheme with matching product ids, or use a **device** for Test Store.

## Before App Store archive

1. **Build Settings** → **`REVENUECAT_APP_STORE_PUBLIC_KEY`** = **`appl_…`** for **Release**.
2. **Release** must **not** include **`REVENUECAT_ALLOW_TEST_STORE_KEY`** (repo default).
3. **Product → Clean Build Folder** → **Archive**.

## Verify

- Offerings load without “Invalid API Key” or wrong-store warnings.
- RevenueCat **bundle id** matches the shipped app.
