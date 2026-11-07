DRAFT — NOT LEGALLY REVIEWED

# MoveMark Privacy Policy

**Applies to:** the MoveMark consumer apps for iPhone and Android, the services behind them, and account.movemark.ca.
**Does not apply to:** MoveMark Business, which is a separate product with its own terms and privacy notice.
**Effective date:** [OWNER: effective date]

---

## 1. Who we are

MoveMark helps renters photograph a rental before move-in and move-out, keep photos, dates and documents together, and create reports and dispute packets.

In this policy, "MoveMark", "we" and "us" mean [OWNER: legal name of the operator].

Send privacy questions, requests and complaints to **connect@movemark.ca**.

## 2. The short version

- Your rental records are personal and often sensitive. Photos show the inside of your home. We treat them that way.
- We collect what you put into MoveMark, plus basic account, purchase and diagnostic data.
- We use it to run MoveMark for you. There are no advertising or third-party analytics tools in the apps, and we do not sell your personal information.
- Your data is stored and processed by service providers, and at least some of it is held in the **United States**, not Canada.
- Original photos are kept exactly as your device produced them. They keep their embedded metadata, including location where the photo has it. See section 4.
- You can delete your account in the app. Deletion removes your live data, but **encrypted backups last longer, and backup copies of your photos, documents and reports have no fixed expiry at this time**. See section 11.
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
| **Acceptance records** | If we ask you to accept the Terms and this policy in the app, which versions you accepted, when, and how you signed in. |
| **Diagnostics** | Crash and error reports containing device and operating system details, app version and technical error data. They may include fragments of whatever data the failed process was handling. |
| **Server logs** | Request ID, route, status and timing for failed requests. Your account ID on some events (for example purchases and failures). Your IP address or account ID when a rate limit is hit. Our hosting and sign-in providers may also record IP addresses and browser or device details as part of providing their services. |

### What we don't collect

- **Device location.** The apps do not ask for location permission. The only location data we may receive is what is already inside a photo file (section 4).
- **Contacts, microphone, or your whole photo library.** Only the photos you choose are read.
- **Push notification tokens.** The current apps don't register for push notifications.
- **Advertising identifiers.** There are no advertising tools in the apps.

The apps record simple usage events such as "report generated" in logs on your own device. These are not sent to us or to anyone else.

We don't send your photos to any AI or image-analysis service.

## 4. Photos of your home are sensitive

A photo of a home can show where you live, how you live, what you own, your health or religion, and who lives with you. Combined with an address, it could be misused. We treat photos, addresses and tenancy documents as sensitive personal information. By adding them to MoveMark, you consent to us handling them as this policy describes.

**Each photo added through the current apps is stored in three versions:**

| Version | What it is | Metadata |
|---|---|---|
| **Original** | The file exactly as your device produced it, never resized or altered. We keep it so the record stays intact. | **All of it**, including location (GPS coordinates) where the photo has it, plus device details and capture time. |
| **Working copy** | A JPEG used in the app, for viewing and in PDF reports. | Capture date only. GPS and other metadata are removed. |
| **Thumbnail** | A small JPEG for grids. | None. |

What this means for you:

- **Photos from your library may carry location data.** The apps don't ask for location permission, so we would not expect photos taken with the in-app camera to contain GPS coordinates. A photo chosen from your library may have them, if your phone recorded them when you took it.
- **We store that location but don't use it.** MoveMark has no feature that reads it, and you can't view it or strip it from a stored original. The only way to remove it from live storage is to delete the photo.
- **Originals are private.** The app and normal service functions show you the working copy, not the original. Reports you generate use working copies, so reports do not contain the GPS data held in originals.
- **Originals are included in our backups**, with their metadata, and are removed from live storage when you delete the photo or your account. Backup copies last longer. See section 11.
- If you don't want location data stored, turn off location for your camera app before taking library photos, remove it before choosing them, or use the in-app camera.

**Other people.** Photos and documents can include other people, such as roommates, landlords, tradespeople or visitors. Please avoid capturing people where you can, and only upload information you are entitled to use for your tenancy records.

## 5. Why we use your information

| Purpose | Information used |
|---|---|
| Create your account, sign you in, and reset your password | Account |
| Store your rental record and sync it across your devices | Rental, room, photo, document and maintenance information |
| Show when a photo says it was taken and when we received it, and keep a fingerprint of the original | Photo metadata |
| Create the reports and dispute packets you ask for | Rental address and name, rooms, notes, tags, working-copy photos, document names and dates, maintenance and dispute information |
| Apply plan limits and give you what you've paid for | Purchase status, credits, and counts of rentals and reports |
| Keep the service secure, stop abuse, and fix faults | Diagnostics, server logs, IP address, account ID |
| Recover from data loss | All stored data, through encrypted backups |
| Respond to you | Support messages, account |
| Meet legal obligations | Whatever the obligation requires |

We don't use your photos, documents or records for advertising, and we don't sell them.

**Consent.** We rely on your consent to handle your personal information. You can withdraw it at any time by deleting the relevant records or your account, subject to legal limits and to what section 11 says about backups. Without certain information, some or all of MoveMark won't work.

## 6. How and where your information is processed

1. **On your device.** Photos are prepared on your phone. Originals wait in app storage until the upload is confirmed.
2. **Direct to storage and database.** Your phone uploads photos and documents directly to Neon Object Storage using temporary links that our API issues after checking you own the rental. Most of your rental records are written directly to the Neon database, where database rules limit each account to its own rows.
3. **MoveMark API and worker.** Our servers check sign-ins, control storage, process purchases, delete accounts and create PDF reports. To create a PDF, the worker reads your records and working-copy photos, then saves the report to private storage.
4. **Backups.** A scheduled job makes an encrypted copy of the database and stored files several times a day and sends it to separate storage.

## 7. Service providers

We use these companies to run MoveMark. We may add or change providers over time, including for sending account emails.

| Provider | What they do | What they handle |
|---|---|---|
| **Neon** | Database, sign-in (Neon Auth) and file storage (Object Storage) | All account data, rental records, photos, documents and reports. Password-reset emails are sent through Neon Auth. |
| **Railway** | Hosts our API, report worker and scheduled backup job, and our Redis cache | Data passing through the API and worker, including report contents. Server logs. Redis holds short-lived cached account and rental summaries, temporary report links, and rate-limit counters. |
| **Backblaze B2** | Encrypted off-site backups | Encrypted copies of the whole database (including sign-in records) and all stored files. Backblaze does not hold the key. |
| **RevenueCat** | Manages subscriptions and purchases | Your account ID, purchase and subscription records, the purchase receipts Apple or Google provide, and basic device and app information its SDK collects. We do not send it your name or email. |
| **Apple** and **Google** | App stores and payment, and sign-in if you use it | Your payment and store account details, under their own privacy terms. They do not get your MoveMark records from us. |
| **Sentry** | Crash and error reporting | Device, operating system, app version, technical error data, and possibly fragments of data held by the failed process. |
| **Vercel** | Hosts our websites, including account.movemark.ca (password-reset and sign-in return pages) | Website request data such as IP address, browser details and the page requested. The address of a password-reset page contains a one-time token. |
| **Titan** | Hosts the connect@movemark.ca mailbox | Your support emails |

**Sign in with Apple or Google.** If you use one of these, that provider tells us your account identity (such as your email and name), and we link it to your MoveMark account. Its own privacy terms apply to what it holds.

## 8. Information leaving Canada

Your information is stored and processed outside Canada. Our database, sign-in records, stored files and encrypted backups are held in the United States. Other providers may process information in the United States or in other countries where they operate. While it is there, it is subject to the laws of those countries, and courts, law enforcement and national security authorities there may be able to obtain access to it.

## 9. When your information is shared

- **When you share it.** Reports and documents leave MoveMark when you send them, for example to a landlord, a tribunal, a lawyer or a family member. A report includes your rental's name and address, photos, dates, notes and other details you added. After you share a report, the recipient controls it, and deleting your account won't get it back.
- **Service providers**, as described in section 7.
- **Legal reasons.** If the law requires it, such as a valid court order, or if it's needed to protect someone's safety or to protect our rights.
- **Business changes.** If MoveMark's business is sold or reorganized, your information may transfer to the new owner, under this policy and the law.

We don't share your information with landlords, property managers or other MoveMark users unless you choose to. MoveMark Consumer data is not shared with MoveMark Business.

## 10. How long we keep information

We keep your records until you delete them or your account. **Inactive accounts are not deleted automatically, and we have not set a maximum retention period.**

| Information | How long it is kept |
|---|---|
| Your account, rental records, photos, documents and reports | Until you delete them or your account |
| Password-reset links | A short time. They expire, and a new one can be requested. |
| Sign-in on your device | Until you sign out or your session expires. The short-lived access token lasts about 15 minutes. |
| Temporary file links | Up to about 1 hour. Anyone who has a link can use it until then. |
| Unfinished uploads | Removed by an automatic clean-up after about 25 hours, if no record uses them |
| Redis cached data | Seconds to about 14 minutes |
| Database point-in-time history at Neon | 7 days |
| Database backups | About 36 days. The first backup of each month is kept for 365 days. |
| Backup file list (encrypted) | 400 days |
| Backup copies of photos, documents and reports | **No fixed expiry at this time.** These copies are not removed when you delete the live version. |
| Server logs on Railway, and crash reports in Sentry | As long as that provider's retention settings keep them |
| Purchase records at RevenueCat | As long as RevenueCat keeps them. We don't currently delete these when you delete your account. |
| Support emails | In our mailbox until we delete them |

We may keep information longer where the law requires it, or to resolve a dispute or security incident.

## 11. Deleting your information

**Deleting removes your information from our live systems. It doesn't remove it from encrypted backups straight away, and backup copies of your photos, documents and reports have no fixed expiry at this time.**

**Delete a photo entry or document.** You can delete these in the app. The working copy, thumbnail, original and the database record are removed from live storage. A photo already included in a generated report **stays in that PDF**. You can't currently delete a single report on its own.

**Delete your account.** In the app, go to **Account → Delete account**. This:

1. Deletes your rentals, rooms, entries, photo and document records, maintenance logs, disputes, report records, profile, plan status and Report Pack credits from the database.
2. Deletes your stored files from live storage: originals, working copies, thumbnails, documents and reports.
3. Deletes your sign-in identity, so you can no longer sign in. An access token already issued can remain valid for up to about 15 minutes, though there's no data left behind it.
4. Clears unsent photos and downloaded reports from that device. Cached copies of photos you've viewed, and on Android any saved dispute drafts, may stay on the device until the system clears them or you remove the app.

You can also ask us by email at connect@movemark.ca. We may need to confirm it's you first.

**What deleting your account doesn't do:**

- **It doesn't cancel your subscription.** Cancel it with Apple or Google, or you may keep being charged.
- **Unused Report Pack credits are lost.**
- **It doesn't reach reports you've already shared** or files you've saved elsewhere.
- **It doesn't remove backups.** Deleted information remains in the 7-day database history and in encrypted backups, kept as set out in section 10. Backups can't be changed or removed for at least 30 days, by design. They exist for recovery, not for everyday use.
- **A restore could bring data back.** If we ever had to restore from a backup, information deleted after that backup was made, including a deleted account, could return. We don't yet have an automatic step that deletes it again.
- **It doesn't reach some provider records**, including purchase records at RevenueCat, crash reports in Sentry, and logs.
- **It doesn't remove what Apple or Google hold** about your purchases.

## 12. Information on your device

- Photos that haven't finished uploading are kept in the app's private storage until they are confirmed saved. They're cleared when you sign out (after a warning) or delete your account.
- On iPhone, those unsent photos are included in your device backup (for example iCloud Backup, if you use it). On Android they're excluded from cloud backup, but other cached rental details may be included in your Google device backup.
- The apps keep a local copy of your rental summary so they can open quickly, and cached images so photos load faster. The rental summary is cleared on sign-out. Cached images may stay until the system clears them.
- Your sign-in session is stored in the iPhone Keychain or in Keystore-encrypted storage on Android, on that device only.
- Anyone who can unlock your phone may be able to see what's in the app. Use a passcode and sign out on shared devices.

## 13. Security

We use safeguards to protect your information. They include:

- encrypted connections between the apps and our services;
- rules in the database that limit each account to its own records;
- private storage, with short-lived links issued only after ownership is checked;
- separate, limited database roles for the API, the report worker and the backup job;
- rate limits on our API, with sign-in attempts throttled by our authentication provider;
- backups encrypted with AES-256-GCM before they are sent to Backblaze, with the key kept separately from the backups.

**Your data is not end-to-end encrypted.** Our systems, our providers and the people who run MoveMark can technically read it, for example to create a report.

**No system is completely secure, and we can't guarantee that your information will never be accessed, lost or disclosed without permission.** You help protect your account by using a strong, unique password. Passwords must be at least 8 characters.

If a breach creates a real risk of significant harm to you, we will notify you and the Privacy Commissioner as the law requires.

## 14. Your rights

Canadian privacy law, including the *Personal Information Protection and Electronic Documents Act* (PIPEDA), gives you the right to:

- **Ask what personal information we hold** about you, how it has been used, and who it has been shared with.
- **Get access** to that information.
- **Correct** information that's wrong. You can edit most details yourself in the app.
- **Withdraw consent**, subject to legal or contractual limits.
- **Ask us to delete** your information. Section 11 explains how, and what deletion doesn't reach.
- **Complain** to us, and if you're not satisfied, to the Office of the Privacy Commissioner of Canada at [priv.gc.ca](https://www.priv.gc.ca).

To make a request, email **connect@movemark.ca**. There's no self-serve export of all your data, so we handle these requests by email. We may need to confirm your identity first, and we will respond within the time the law allows.

If you live in a province with its own privacy law, such as Quebec, Alberta or British Columbia, you may have further rights.

## 15. Children

MoveMark is meant for renters and is not directed at children. The apps don't ask for your age. If you believe a child has given us personal information, contact us and we'll take appropriate steps.

## 16. Changes to this policy

We'll post any update here and change the effective date. If a change is significant, we'll take reasonable steps to tell you before it takes effect, for example by email or in the app, and ask for your consent again where the law requires it.

## 17. Contact

**Email:** connect@movemark.ca
**Mail:** [OWNER: mailing address, if needed]
