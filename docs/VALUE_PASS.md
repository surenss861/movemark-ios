# Value Pass — Copy Audit (2026-10-06)

This audit checks the existing copy against [PRODUCT_DOCTRINE.md](PRODUCT_DOCTRINE.md). It changes copy only and adds no features. Change iOS and Android together.

## Already aligned (keep)

- Headline "Prove what was already there." is used on the landing page, in `MoveMarkGrowthCopy` (both platforms) and on the Welcome screen.
- Coverage reads "X of Y rooms documented" in `RoomListView`, `VaultRootView` and Android `RoomsScreen`/`VaultScreen`.
- The rooms list is already titled "Proof Sprint".

## Proposed changes

| # | Surface | Current | Proposed | Files |
|---|---|---|---|---|
| 1 | Pro upsell subtitle | "Unlimited vaults, reports, and dispute tools" | "Keep a complete rental record from move-in to move-out" | iOS `AccountView.swift:158,201`, `SubscriptionManager.swift:209,729`; Android `AccountScreen.kt:68-69,145`, `MoveMarkGrowthCopy.kt:42` |
| 2 | Paywall header | "MoveMark Pro" + "MoveMark Pro includes" list | Value line: "Keep a complete rental record from move-in to move-out." Support line under the list title: "MoveMark Pro keeps your proof organized across the full rental lifecycle." The feature list stays as it was. | iOS `ProPaywallView.swift:170,683`; Android `ProPaywallScreen.kt:114` |
| 3 | Report ready | "Your move-in report is ready to share." | "Your move-in record is ready." with the subline "A dated record of the condition you documented at move-in." | iOS `ExportHistoryView.swift:538`; Android `ReportsViewModel.kt:567` |
| 4 | Move-out ready | "Your move-out report is ready to share." | "Your move-out record is ready." with the subline "A dated record of the condition you documented before returning the keys." | Android `ReportsScreen.kt:246` + iOS equivalent |
| 4b | Dispute ready | "Your dispute packet is ready to share." | "Your evidence packet is ready." with the subline "Your saved rental evidence organized into one shareable record." | Android `ReportsScreen.kt`; iOS `ExportHistoryView.swift` |
| 5 | Remaining rooms | "N rooms still need photos" | "N rooms still need proof" | iOS `RoomListView.swift:281`, `MMProofTimeline.swift:315`; Android equivalent |
| 6 | Proof Sprint CTA | generic continue | Name the next room: "Capture {Room}"; when no room is known, fall back to "Continue move-in proof" | `MMNextBestAction` + Android equivalent. **Run this as the first experiment** (metric: second-room completion within 24 hours). |
| 7 | Landing lead | "Take room photos before you unpack. Turn them into a report when you need it." | "Document your rental before problems happen. MoveMark organizes room photos, maintenance records, documents, and move-out proof into shareable evidence." Stakes line: "Because 'that damage was already there' means more when you can prove it." | `landing/index.html:80-81` |
| 8 | Landing CTA | "Join waitlist" | "Start your proof" (or keep the waitlist label until launch) | `landing/index.html:97` |

## Status (2026-10-06)

Items 1–6 are shipped on iOS and Android as copy-only changes, and both apps build and pass their tests. The strings live in `MoveMarkGrowthCopy` on each platform. The Pro headline is the shared paywall value line; the trigger-specific headlines stay as they were. Item 6 shipped to everyone with no flag, because analytics only writes to the device log on iOS and doesn't exist on Android, so there's nothing to measure an A/B test with. Items 7–8 (landing page) are on the web launch checklist. "Report" is still used for the artifact itself (history, type, filenames). Only the ready-state copy changed.

### Follow-up (2026-10-06)

- On iOS, "Capture {Room}" on the Vault home and property vault now opens that room directly. "Continue move-in proof" still opens the guided Proof Sprint list. Android already worked this way.
- iOS layout QA: each changed surface was rendered at default and AX3 text sizes, with "Primary Bedroom" and "Balcony/Patio" as room names. To fix what turned up, `MMButton` labels now shrink (down to 0.7×) before truncating, the `MMSettingsRow` subtitle limit went from 2 to 4 lines, and the subscriber line was shortened to "Complete rental record, move-in to move-out."
- **Still open, pre-existing (not from this pass):** at AX3, `MMReportExportSection` titles shrink to "…" next to the status pill; settings row titles ("MoveMark Free") and long vault addresses also truncate.
- **Still pending: QA with a signed-in account and Android visual QA.** Nothing in the repo provides a QA account or an Android emulator, so the paywall entry points, the real ready states with data, and the 0/1/nearly-complete rooms scenarios still need a pass on real devices.

## Blockers found during the audit

- The landing form action is still `https://formspree.io/f/xplaceholder`. Signups go nowhere until this points at a real endpoint. Fix this before any paid traffic.

## Analytics

`MoveMarkAnalytics` (iOS) only writes to the on-device log, nothing is sent anywhere, and Android has no analytics at all. Until a real sink exists, none of the metrics below can be measured. iOS already calls analytics from these places: Welcome, FirstRun, EvidenceCapture, Vault, PropertyVault, Paywall and ExportHistory. Before launch, confirm that these events exist with the same names on both platforms:

`rental_created`, `first_photo_captured`, `room_completed` (with `room_index`), `report_generated` (type), `report_shared`, `paywall_viewed`, `subscription_started` (plan), `moveout_started`.

With these events we can compute the activation metric (rooms ≥ 2) and the time to the first documented room.
