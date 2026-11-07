DRAFT — NOT LEGALLY REVIEWED

# MoveMark Privacy Policy

**Applies to:** the MoveMark consumer apps for iPhone and Android, the services behind them, and account.movemark.ca.
**Does not apply to:** MoveMark Business, which is a separate product with its own terms and privacy notice.
**Effective date:** [UNKNOWN: effective date]
**Version:** Draft 1, prepared 2026-11-07 from the code on `feature/legal-gate` (client) and `recovery/neon-api` (API).

> **Notes for the reviewing lawyer. Remove before publishing.**
> Every statement of fact below was taken from the code, schema or operations documents.
> `[UNKNOWN: …]` marks a fact nobody has confirmed yet. `[LAWYER DECISION: …]` marks a legal choice. `[CONFLICT C#: …]` marks a place where the current product behaviour falls short of what a policy would normally want to say. The draft describes what the product does today rather than what would read best. All of these are explained in `unknown-legal-facts.md`. This draft must not be published until the `[CONFLICT]` items have been fixed or accepted.

---

## 1. Who we are

MoveMark helps renters photograph a rental before move-in and move-out, keep photos, dates and documents together, and create reports and dispute packets.

In this policy, "MoveMark", "we" and "us" mean [UNKNOWN: legal name of the business operating MoveMark], of [UNKNOWN: mailing address], in Ontario, Canada.

The person responsible for privacy at MoveMark is [UNKNOWN: name or title of the designated privacy officer]. You can reach them at **connect@movemark.ca**.

## 2. The short version

- Your rental records are personal and often sensitive. Photos show the inside of your home. We treat them that way.
- We collect what you put into MoveMark, plus basic account, purchase and diagnostic data.
- We use it to run MoveMark for you. We do not put advertising or third-party analytics tools in the apps, and we do not sell your personal information. [UNKNOWN: owner to confirm this is a permanent business commitment, not only a description of the current code]
- Your data is stored and processed by service providers, and at least some of it is held in the **United States**, not Canada.
- Original photos are kept exactly as your device produced them. If an original contains location or other metadata, that metadata is stored with it. See section 4.
- You can delete your account in the app. Deletion removes your live data, but **encrypted backup copies last longer**. See section 11.
- You choose when a report leaves MoveMark. Once you share one, we cannot control it.
- No system is perfectly secure, and we can't promise otherwise.

## 3. What we collect

### Information you give us

| Type | What it includes |
|---|---|
| **Account** | Email address, name, and password. Your password goes to our authentication provider (Neon Auth), not to the MoveMark API. We also keep your account ID and when you finished onboarding. |
| **Rental details** | Rental name, street address, unit, city, province, postal code and country. Move-in date, lease start and end dates, rent amount and deposit amount. |
| **Landlord details** | Landlord or property manager name, email and phone number, if you enter them. |
| **Room records** | Room names, condition ratings, notes, issue tags, entry titles and move-out checklist items. |
| **Photos** | Photos you take in the app or choose from your library, of rooms and of maintenance issues. |
| **Documents** | Files you upload: leases, deposit receipts, listing screenshots, cleaning receipts, utility records, move-out invoices and anything else you add, with their file names. PDF, JPEG and PNG are accepted. |
| **Maintenance logs** | Issue title, category, description, status, dates discovered and reported, how you reported it, the landlord's response and follow-up date. |
| **Dispute information** | Dispute type and status, amount in question, move-out date, charge date and whether you received an itemized statement. |
| **Support messages** | Whatever you send to connect@movemark.ca. |

Your leases, receipts and notes may contain financial details, signatures, or personal information about other people. Please upload only what you need.

### Information created when you use MoveMark

| Type | What it includes |
|---|---|
| **Photo metadata we record** | Capture time and time-zone offset read from the file, if the file has them. The time MoveMark received the photo. Whether it came from the camera or your library. File type, size, pixel dimensions and a SHA-256 fingerprint of the original. |
| **Metadata inside original files** | The original file keeps everything your device wrote into it. See section 4. |
| **Reports** | The PDF move-in reports, move-out reports and dispute packets you generate, with their type, status and dates. |
| **Purchase status** | Your account ID as used with RevenueCat, the product, your plan status, expiry date, whether the purchase was live or a test, the last billing event, and your Report Pack credit balance and history. **We do not receive your card details.** Apple or Google handles payment. |
| **Diagnostics** | Crash and error reports containing device and operating system details, app version and technical error data. Crash reporting is set not to include personal data by default, not to capture screenshots on Android, and not to measure performance. |
| **Server logs** | Request ID, route, status and timing for failed requests. Your account ID on some events (for example purchases and failures). Your IP address or account ID when a rate limit is hit. [UNKNOWN: whether our hosting providers and Neon Auth keep IP addresses or device details for every request or session] |

### What we don't collect

- **Device location.** The apps do not ask for location permission. The only location data we may receive is what is already inside a photo file (section 4).
- **Contacts, microphone, or your whole photo library.** Only the photos you choose are read.
- **Push notification tokens.** The current apps don't register for push notifications.
- **Advertising identifiers.** There are no advertising tools in the apps.

The apps record simple usage events such as "report generated" in logs on your own device. These are not sent to us or to anyone else. There is no third-party analytics service in the apps. [CONFLICT C19: keep this sentence accurate if analytics is ever added]

Our server code does not send your photos to any AI or image-analysis service.

## 4. Photos of your home are sensitive

A photo of a home can show where you live, how you live, what you own, your health or religion, and who lives with you. Combined with an address, it could be misused. We treat photos, addresses and tenancy documents as sensitive personal information, and we ask for your express consent to handle them. [CONFLICT C4: the apps do not currently collect or record express consent]

**Each photo is stored in three versions:**

| Version | What it is | Metadata |
|---|---|---|
| **Original** | The file exactly as your device produced it, never resized or altered. We keep it so the record stays intact. | **All of it**, including GPS coordinates if the file has them, plus device details and capture time. |
| **Working copy** | A JPEG used in the app, for viewing and in PDF reports. | Capture date only. GPS and other metadata are removed. |
| **Thumbnail** | A small JPEG for grids. | None. |

What this means for you:

- **Photos from your library may carry location data.** The apps don't ask for location permission, so we would not expect photos taken with the in-app camera to contain GPS coordinates. A photo chosen from your library may have them, if your phone recorded them when you took it.
- **Originals are private.** The app and normal service functions show you the working copy, not the original. Reports you generate use working copies, so reports do not contain the GPS data held in originals.
- **Originals are included in our backups** and are removed from live storage when you delete the photo or your account. See section 11.
- If you don't want location data stored, turn off location for your camera app before taking library photos, or remove it before choosing them, or use the in-app camera.

[CONFLICT C3: MoveMark has no product use for GPS data but stores it indefinitely. The lawyer and owner should decide whether this meets PIPEDA's limiting-collection principle.]

**Other people.** Photos and documents can include other people, such as roommates, landlords, tradespeople or visitors. Please avoid capturing people where you can, and only upload information you are entitled to use for your tenancy records.

## 5. Why we use your information

| Purpose | Information used |
|---|---|
| Create your account, sign you in, and reset your password | Account |
| Store your rental record and sync it across your devices | Rental, room, photo, document and maintenance information |
| Show when a photo says it was taken and when we received it, and let you detect changes to the original | Photo metadata |
| Create the reports and dispute packets you ask for | Rental address and name, rooms, notes, tags, working-copy photos, document names and dates, maintenance and dispute information |
| Apply plan limits and give you what you've paid for | Purchase status, credits, and counts of rentals and reports |
| Keep the service secure, stop abuse, and fix faults | Diagnostics, server logs, IP address, account ID |
| Recover from data loss | All stored data, through encrypted backups |
| Respond to you | Support messages, account |
| Meet legal obligations | Whatever the obligation requires |

We don't use your photos, documents or records for advertising, and we don't sell them. [UNKNOWN: owner to confirm MoveMark staff will not view user content except for support with your permission, security or legal reasons, and that user content will not be used to train models]

**Consent.** We rely on your consent to handle your personal information. You can withdraw it at any time by deleting the relevant records or your account, subject to legal limits. Without certain information, some or all of MoveMark won't work. [LAWYER DECISION: whether a separate, express in-app consent for sensitive information and cross-border processing is needed in addition to accepting this policy]

## 6. How and where your information is processed

1. **On your device.** Photos are prepared on your phone. Originals wait in app storage until the upload is confirmed.
2. **Direct to storage and database.** Your phone uploads photos and documents directly to Neon Object Storage using temporary links that our API issues after checking you own the rental. Most of your rental records are written directly to the Neon database, where database rules limit each account to its own rows.
3. **MoveMark API and worker.** Our servers check sign-ins, control storage, process purchases, delete accounts and create PDF reports. To create a PDF, the worker reads your records and working-copy photos, then saves the report to private storage.
4. **Backups.** A scheduled job makes an encrypted copy of the database and stored files about every six hours and sends it to separate storage.

## 7. Service providers

We use these companies to run MoveMark. They process information on our behalf. [UNKNOWN: whether a data processing agreement is in place with each provider]

| Provider | What they do | What they handle | Location shown in our configuration |
|---|---|---|---|
| **Neon** | Database, sign-in (Neon Auth) and file storage (Object Storage) | All account data, rental records, photos, documents and reports. Sends password-reset emails through its default sender. [UNKNOWN: current email sender for production. Postmark is planned but not confirmed.] | United States (AWS us-east-2) |
| **Railway** | Hosts our API, report worker, scheduled backup job and Redis | Data passing through the API and worker, including report contents. Server logs. Redis holds short-lived cached account and rental summaries, temporary report links, and rate-limit counters. | [UNKNOWN: Railway region] |
| **Backblaze B2** | Encrypted off-site backups | Encrypted copies of the whole database (including sign-in records) and all stored files. Backblaze does not hold the key. | United States (us-east-005, per our recovery records) [UNKNOWN: owner to confirm the production endpoint] |
| **RevenueCat** | Manages subscriptions and purchases | Your account ID, purchase and subscription records, the purchase receipts Apple or Google provide, and basic device and app information its SDK collects. We do not send it your name or email. | [UNKNOWN: RevenueCat processing location] |
| **Apple** and **Google** | App stores and payment. Sign in with Apple and Google, where offered. | Your payment and store account details, under their own privacy terms. They do not get your MoveMark records from us. | Their own terms apply |
| **Sentry** | Crash and error reporting | Device, operating system, app version, technical error data, and possibly fragments of data held by the failed process. [CONFLICT C18: confirm report-worker settings] | United States (iOS reporting address is in Sentry's US region) |
| **Vercel** | Hosts account.movemark.ca (password reset and sign-in return pages) and [UNKNOWN: confirm movemark.ca] | Website request data such as IP address, browser details and the page requested. The address of a password-reset page contains a one-time token. | [UNKNOWN: Vercel processing location] |
| **Titan** [UNKNOWN: owner to confirm; known from project notes, not from code] | Hosts the connect@movemark.ca mailbox | Your support emails | [UNKNOWN: Titan mailbox location] |

**Sign in with Apple and Google.** The code for these is present but they are not switched on in App Store or Google Play builds at the time of this draft. If you use one, that provider tells us your account identity (such as your email and name), and we link it to your MoveMark account. [UNKNOWN: whether social sign-in will be live at launch. If not, remove this paragraph.]

## 8. Information leaving Canada

Your information is stored and processed outside Canada, including in the United States, and possibly in other countries where our providers operate. While it is there, it is subject to the laws of those countries, and courts, law enforcement and national security authorities there may be able to obtain access to it.

We use contracts and other means to give your information a comparable level of protection while it is with our providers. [UNKNOWN: confirm these contracts exist]

[LAWYER DECISION: wording of the transfer notice, including anything required for Quebec residents if MoveMark is offered there.]

## 9. When your information is shared

- **When you share it.** Reports and documents leave MoveMark when you send them, for example to a landlord, a tribunal, a lawyer or a family member. A report includes your rental's name and address, photos, dates, notes and other details you added. After you share a report, the recipient controls it, and deleting your account won't get it back.
- **Service providers**, as described in section 7.
- **Legal reasons.** If the law requires it, such as a valid court order, or if it's needed to protect someone's safety or to protect our rights. [LAWYER DECISION: scope and whether we notify users of requests]
- **Business changes.** If MoveMark's business is sold or reorganized, your information may transfer to the new owner, under this policy and the law.

We don't share your information with landlords, property managers or other MoveMark users unless you choose to. MoveMark Consumer data is not shared with MoveMark Business. [UNKNOWN: owner to confirm this will stay true]

## 10. How long we keep information

Your records stay in your account until you delete them or your account. **Inactive accounts are not deleted automatically, and we have not yet set a maximum retention period.** [CONFLICT C12: UNKNOWN: retention period for inactive accounts and old reports]

| Information | How long it is kept |
|---|---|
| Your account, rental records, photos, documents and reports | Until you delete them or your account |
| Password-reset links | [UNKNOWN: reset link lifetime] |
| Sign-in on your device | Session 7 days [UNKNOWN: whether the session renews with use]. The short-lived access token lasts about 15 minutes. |
| Temporary file links | Upload 10 minutes. Photo and document download 1 hour. Report download 15 minutes. |
| Unfinished uploads | Removed by an automatic clean-up after about 25 hours, if no record uses them |
| Redis cached data | Seconds to about 14 minutes |
| Database point-in-time history at Neon | 7 days |
| Database backups | About 36 days. The first backup of each month is kept for 365 days. |
| Backup file list (encrypted) | 400 days |
| Backup copies of photos, documents and reports | **No expiry is set at this time.** [CONFLICT C1: these copies are not removed when you delete the live version. UNKNOWN: retention period for deleted-account backups] |
| Server logs on Railway | [UNKNOWN: Railway log retention] |
| Crash reports in Sentry | [UNKNOWN: Sentry retention] |
| Purchase records at RevenueCat | [UNKNOWN: RevenueCat retention; we do not currently delete these when you delete your account] |
| Support emails | [UNKNOWN: support email retention] |

We may keep information longer where the law requires it, or to resolve a dispute or security incident. [UNKNOWN: any tax or accounting records MoveMark must keep]

## 11. Deleting your information

**Delete a photo entry or document.** You can delete these in the app. The working copy, thumbnail, original and the database record are removed from live storage. A photo already included in a generated report **stays in that PDF**. [CONFLICT C10: there is no way to delete a single report.]

**Delete a rental.** [UNKNOWN: Delete rental is built on the server but not yet in the released apps. Add this only once it ships.]

**Delete your account.** In the app, go to **Account → Delete account**. This:

1. Deletes your rentals, rooms, entries, photo and document records, maintenance logs, disputes, report records, profile, plan status and Report Pack credits from the database.
2. Deletes your stored files from live storage: originals, working copies, thumbnails, documents and reports.
3. Deletes your sign-in identity, so you can no longer sign in. An access token already issued can remain valid for up to about 15 minutes, though there's no data left behind it.
4. Clears unsent photos and downloaded reports from that device. [CONFLICT C9: cached copies of viewed photos may remain on the device until the system clears them.]

You can also email connect@movemark.ca. [UNKNOWN: identity check and response process for email deletion requests]

**What deleting your account doesn't do:**

- **It doesn't cancel your subscription.** Cancel it with Apple or Google, or you may keep being charged. [CONFLICT C8: the Android delete screen doesn't currently say this.]
- **Unused Report Pack credits are lost.**
- **It doesn't reach reports you've already shared** or files you've saved elsewhere.
- **It doesn't immediately remove backups.** Deleted information remains in the 7-day database history and in encrypted backups, which are kept as set out in section 10. Backups can't be altered for at least 30 days by design. They're not used for anything except recovery. [CONFLICT C1: backup copies of files currently have no end date, so "permanently deleted" in the app is not accurate for them.] [CONFLICT C2: if we ever had to restore from a backup, recently deleted accounts could return. There is no process yet to delete them again.]
- **It doesn't reach some provider records**, including purchase records at RevenueCat, crash reports in Sentry, and logs. [CONFLICT C7]
- **It doesn't remove what Apple or Google hold** about your purchases.

## 12. Information on your device

- Photos that haven't finished uploading are kept in the app's private storage until they are confirmed saved. They're cleared when you sign out (after a warning) or delete your account.
- On iPhone, those unsent photos are included in your device backup (for example iCloud Backup, if you use it). On Android they're excluded from cloud backup. [CONFLICT C17: other cached rental details on Android may still be included in Google device backup.]
- The apps keep a local copy of your rental summary so they can open quickly, and cached images so photos load faster. The rental summary is cleared on sign-out.
- Your sign-in session is stored in the iPhone Keychain or in Keystore-encrypted storage on Android, on that device only.
- Anyone who can unlock your phone may be able to see what's in the app. Use a passcode and sign out on shared devices.

## 13. Security

We use safeguards appropriate to the sensitivity of your information. They include:

- encrypted connections between the apps and our services;
- rules in the database that limit each account to its own records;
- private storage, with short-lived links issued only after ownership is checked;
- separate, limited database roles for the API, the report worker and the backup job;
- rate limits on our API, with sign-in attempts throttled by our authentication provider;
- backups encrypted with AES-256-GCM before they are sent to Backblaze, with the key kept separately from the backups.

[UNKNOWN: confirm encryption at rest with Neon, Railway and Sentry before saying anything about it.] [CONFLICT C16: confirm who can reach production data before stating that access is limited to authorized people.]

**Your data is not end-to-end encrypted.** Our systems and providers can technically read it in order to provide the service, for example to create a report.

**No system is completely secure, and we can't guarantee that your information will never be accessed, lost or disclosed without permission.** You help protect your account by using a strong, unique password. Passwords must be at least 8 characters.

If a breach creates a real risk of significant harm to you, we will notify you and the Privacy Commissioner as the law requires. [UNKNOWN: breach response owner and process]

## 14. Your rights

Canadian privacy law, including the *Personal Information Protection and Electronic Documents Act* (PIPEDA), gives you the right to:

- **Ask what personal information we hold** about you, how it has been used, and who it has been shared with.
- **Get access** to that information.
- **Correct** information that's wrong. You can edit most details yourself in the app.
- **Withdraw consent**, subject to legal or contractual limits.
- **Ask us to delete** your information. Section 11 explains how.
- **Complain** to us, and if you're not satisfied, to the Office of the Privacy Commissioner of Canada at [priv.gc.ca](https://www.priv.gc.ca).

To make a request, email **connect@movemark.ca**. We may need to confirm your identity first, and we will respond within the time the law allows. [UNKNOWN: process and owner for access requests] [CONFLICT C13: there is no self-serve export of all account data or originals, so access requests have to be handled by hand.]

If you live in a province with its own privacy law, such as Quebec, Alberta or British Columbia, you may have further rights. [LAWYER DECISION: whether to add province-specific sections, and whether Quebec is in scope at launch]

## 15. Children

MoveMark is meant for renters and is not directed at children. [LAWYER DECISION: minimum age. CONFLICT C5: the apps have no age check.] If you believe a child has given us personal information, contact us and we'll take appropriate steps.

## 16. Changes to this policy

We'll post any update here and change the effective date. If a change is significant, we'll tell you in the app or by email before it takes effect, and ask for your consent again where the law requires it. [UNKNOWN: mechanism for notifying users; the apps have no in-app message system dedicated to this]

## 17. Contact

**Email:** connect@movemark.ca
**Privacy officer:** [UNKNOWN: name or title of the designated privacy officer]
**Mail:** [UNKNOWN: mailing address]
