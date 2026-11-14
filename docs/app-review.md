# MoveMark: App Review notes (Consumer iOS 1.4)

Use this for **App Review Information** in App Store Connect and for replies to App Review. Updated 2026-11-08 for build 1.4 (20261108.1). The Notion URLs used before are retired. The only legal URLs are the movemark.ca ones below, which match `Info.plist` (`LegalTermsURL`, `LegalPrivacyPolicyURL`, `LegalSupportURL`, `LegalAccountDeletionURL`).

> **Owner, before submitting:** fill in the placeholders in "Sign-in information", create the demo account by hand on **production**, add one sample rental with a few photos, and sign in once on a device to confirm it works. Nobody else creates accounts or enters credentials. Re-check the UI labels below on the release build; they were taken from the source.

## URLs (App Store Connect fields)

| Field | URL |
|---|---|
| Privacy Policy URL | https://movemark.ca/privacy |
| Terms of Use (EULA), in the description or the EULA field | https://movemark.ca/terms |
| Support URL | https://movemark.ca/support |
| Account deletion (web) | https://movemark.ca/delete-account |
| Password reset (web fallback) | https://account.movemark.ca/reset |

These pages must be live with the final text (`LEGAL_FINAL=true` on Vercel) **before** submitting. Until then `/terms` and `/privacy` show "being finalised", which fails 3.1.2 and 5.1.1(i).

## Sign-in information (paste into App Store Connect)

- **User name:** `[OWNER: demo account email on production]`
- **Password:** `[OWNER: demo account password]`
- Sign-in required: **Yes**.

## Notes for the reviewer (paste into "Notes", edit the bracketed parts)

```
MoveMark helps renters document a rental's condition (photos, notes, documents) and produce move-in, move-out and dispute PDF reports. Canada only. Users must be 13 or older (14 or older in Quebec); the app asks for an age range, self-declared and not verified.

SIGN IN
1. Launch the app. On the Welcome screen tap "I already have a vault" (or "Start move-in proof" to create a new account).
2. Sign in with the email and password in Sign-in Information. The demo account already has a sample rental.
Sign in with Apple and Sign in with Google are also offered in this build. Both open a secure browser sheet (account.movemark.ca) and return to the app. You may use your own Apple ID; the email-and-password demo account is the most reliable path.

AGREEMENT AND AGE RANGE
If the Terms or Privacy Policy have been updated since the account last agreed, a screen titled "One last thing." appears after sign-in. Open the documents if you wish, tick "I agree to the Terms of Service and acknowledge the Privacy Policy.", answer "How old are you?" (Under 13 / 13 / 14 to 17 / 18 or older; "13" also asks "Do you live in Quebec?"), then tap "Continue to my Vault". Nothing is pre-selected. No date of birth is collected and the answer is not verified; it is the user's own declaration. "Under 13", and 13 in Quebec, show "MoveMark isn't available for you yet" and can't continue (parental consent is a later release). For 13 to 17, photos are saved without location or camera details. The demo account is an adult account: choose "18 or older". [OWNER: say whether the documents are published on production at review time; if not, this screen does not appear.]

SUBSCRIPTION (auto-renewable) AND REPORT PACK (consumable)
1. Open the Account tab, tap "Subscription" (shows "Free").
2. The paywall shows the plans with price and period, the auto-renewal terms, and links to the Terms of Use and Privacy Policy.
3. Purchase with the sandbox account; "Restore purchases" is on the same screen.
4. Generate a report: open the sample rental, then the report / export action. Free accounts can generate [OWNER: free allowance]; Pro unlocks the rest.

ACCOUNT DELETION
Account tab, "Delete account" (bottom), then confirm. This deletes the account and its data on our servers. It is also reachable from the "One last thing." screen and at https://movemark.ca/delete-account.

PERMISSIONS
Camera: to photograph the rental's condition. Photo library: to add existing photos or documents. Location permission is not requested; photos keep the location their camera embedded, in private storage, and reports and shared copies remove it.

No ads, no tracking, no third-party analytics. Crash reports go to Sentry without personal data.
Contact: connect@movemark.ca [OWNER: phone number for App Review, if any]
```

## A reliable review path, step by step (for the owner's dry run)

Run this on a TestFlight install of the exact build being submitted, signed in as the demo account, before pressing Submit:

1. Fresh install, Welcome screen: the email path, plus Apple and Google buttons (TestFlight and App Review installs carry a sandbox receipt, so the buttons show; App Store customers do **not** see them, see "Known differences").
2. Sign in with the demo email and password: the Vault loads with the sample rental (or "One last thing." first, if documents are published).
3. Account, then Subscription: plans load. Buy Monthly in the sandbox. Pro shows. Generate a report straight away. If it says Pro is required, the RevenueCat refresh (API `aeba6d6`, needs `REVENUECAT_SECRET_API_KEY` on Railway) isn't deployed; wait for the webhook and note this risk.
4. Restore purchases: restores.
5. Privacy Policy, Terms of Use and Contact support rows open the movemark.ca pages with the final text.
6. Sign out, then "Forgot password?" on sign-in: a reset email arrives (owner check C10).
7. Sign in with Apple, then delete that account (Account, Delete account). Repeat with Google.
8. Delete-account flow on a throwaway email account: signing in afterwards fails.

## Known differences App Review may notice

- **Social sign-in visibility.** Release builds show Apple and Google sign-in only when the install has a sandbox receipt (TestFlight and App Review), not to App Store customers (`SocialSignInConfig`, `movemork/Features/Auth/SocialSignIn.swift`). Owner decision D3 keeps them enabled for review. Either make them live for customers too (needs T5/T5P/T6 recorded and email verification on), or be ready to explain under 2.3.1 that the options are being rolled out. Screenshots must not show buttons customers can't see.
- **iPad.** The app declares iPad support, so 13" iPad screenshots are required.

## Subscription metadata (mirror App Store Connect)

- Terms of Use (EULA): https://movemark.ca/terms
- Privacy Policy: https://movemark.ca/privacy
- Update this document whenever those URLs change.

## Technical notes

- MoveMark uses **RevenueCat** for subscription configuration and **Apple StoreKit** for purchases and restores.
- Production builds use the RevenueCat **App Store** public API key (`appl_…`).
- Pro entitlement identifier in code: **`movemark_pro1`** (must match RevenueCat).
- **TestFlight / device logs:** in Console.app, filter subsystem `movemark.movemork`, category `Subscription`. After each refresh you should see the resolved **offering id**, **package count**, **store product IDs**, and **`proEntitlement=movemark_pro1`**. A package count of `0` almost always means App Store Connect or RevenueCat configuration, not the paywall UI.

## Paid capability checklist (outside the repo)

- **Paid Apps Agreement** is Active.
- Banking and tax (e.g. GST/HST) are complete.
- Subscription products exist in App Store Connect with **price**, **localization** and a **review screenshot**, and are attached to the 1.4 version.
- The Report Pack consumable is attached to the version too.
- Product IDs match RevenueCat packages **exactly**, and the RevenueCat **default offering** includes them.
