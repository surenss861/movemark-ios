# MoveMark — App Review notes

Use this when pasting **App Review Information** in App Store Connect or replying to a review. Keep URLs in sync with **Info.plist** (`LegalTermsURL`, `LegalPrivacyPolicyURL`) and with **App Description / EULA** fields.

## Subscription review path (in-app)

1. Open the app.
2. Sign in or create an account.
3. Go to **Account**.
4. Tap **Upgrade to Pro** (subscription card).
5. Subscription plans should load with **price** and **duration** (Monthly / Yearly). Legal links **Terms of Use** and **Privacy Policy** appear on the paywall.
6. If plans do not load, the paywall shows **Plans unavailable** with **Try again** and **Continue on Free** (the app must not look blank or stuck).
7. Tap **Restore purchases** (on the paywall or under **Account → Privacy, terms & subscriptions**).
8. Confirm restore messaging (active Pro vs no subscription found).
9. Open **Account → Privacy, terms & subscriptions → Terms of Use** (same URL as App Store metadata where applicable).
10. **Privacy Policy** is in the same section; **Subscriptions in App Store** opens Apple’s subscription management page.

## Subscription metadata (mirror App Store Connect)

**Terms of Use (EULA)** — must match the functional URL in App Store Connect (and the in-app `LegalTermsURL` key):

https://silver-peripheral-2ef.notion.site/MoveMark-Terms-of-Service-32f382757209804aa569e43311b492b1

**Privacy Policy** — must match `LegalPrivacyPolicyURL`:

https://silver-peripheral-2ef.notion.site/MoveMark-Privacy-Policy-32f38275720980658acbe9aafa4e331b

Update this document whenever those URLs change.

## Technical notes

- MoveMark uses **RevenueCat** for subscription configuration and **Apple StoreKit** for purchases and restores.
- Production builds use the RevenueCat **App Store** public API key (`appl_…`) from the app target’s build settings / Info.plist substitution.
- Pro entitlement identifier in code: **`movemark_pro1`** (must match RevenueCat).
- **TestFlight / device logs:** In Console.app, filter subsystem `movemark.movemork`, category `Subscription`. After each refresh you should see the resolved **offering id**, **package count**, **store product IDs**, and **`proEntitlement=movemark_pro1`**. If **package count** is `0`, the issue is almost always App Store Connect / RevenueCat configuration, not the paywall UI.

## Paid capability checklist (outside the repo)

Before expecting IAPs to load in review:

- **Paid Apps Agreement** is Active.
- Banking and tax (e.g. GST/HST) are complete.
- Subscription products exist in App Store Connect with **price** and **localization**.
- Product IDs match RevenueCat packages **exactly**.
- RevenueCat **default offering** includes those packages.
