//
//  MMRichQAGallery.swift
//  movemork
//
//  Debug-only runtime check for the three rich screens. Launch with -MMRichQA <case>.
//  Not a product screen.
//
//  @file Debug-only fixture gallery for visual QA (vault-*, sprint-*, reports-*, room-*)
//  @domain design-system
//  @status stable
//  @see [[RichQAActivity.kt]] — Android counterpart (same case names)
//  @see [[ROOM_EVIDENCE_RECORD]] — room-* cases verify this spec
//

#if DEBUG
import SwiftUI
import PhotosUI

struct MMRichQAGallery: View {
    let screen: String

    var body: some View {
        if screen.hasPrefix("room-") {
            RoomQAScreen(screen: screen)
        } else if screen.hasPrefix("proof-") {
            ProofQAScreen(screen: screen)
        } else {
            standardGallery
        }
    }

    private var standardGallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenBody
                Color.clear.frame(height: MoveMarkTheme.Spacing.scrollTailRootTabChrome)
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .mmProofShellBackground(heroFocus: true, ctaBloom: false)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var screenBody: some View {
        switch screen {
        case "vault-0":
            vault(documented: 0, total: 10, photos: 0, records: 0, issues: 0, address: "123 Main St", next: "Kitchen")
        case "vault-1":
            vault(documented: 1, total: 10, photos: 4, records: 1, issues: 0, address: "123 Main St", next: "Living Room", lastProof: "Sep 28 · 6:34 PM")
        case "vault-9":
            vault(documented: 9, total: 10, photos: 24, records: 3, issues: 2, address: "123 Main St", next: "Primary Bedroom", lastProof: "Sep 28 · 6:34 PM")
        case "vault-10":
            vault(documented: 10, total: 10, photos: 31, records: 3, issues: 0, address: "123 Main St", next: nil, lastProof: "Oct 2 · 9:12 AM", primary: "Review your rooms")
        case "vault-long":
            vault(documented: 9, total: 10, photos: 24, records: 3, issues: 2, address: "1234 Westmoreland Avenue Northwest, Apartment 14B", next: "Balcony/Patio", lastProof: "Sep 28 · 6:34 PM")
        case "sprint-first":
            sprint(doneThrough: 0, current: "Kitchen")
        case "sprint-middle":
            sprint(doneThrough: 2, current: "Primary Bedroom")
        case "sprint-final":
            sprint(doneThrough: 9, current: "Office")
        case "reports-empty":
            reports(state: .notReady, title: "Document a room to make your first report.", chips: [])
        case "reports-generating":
            reports(state: .processing, title: "Generating your record.", chips: ["9 rooms", "24 photos"])
        case "reports-ready":
            reports(state: .ready, title: "Your move-in record is ready.", chips: ["9 rooms", "24 photos", "2 issues"], generated: "Generated Sep 28 · 6:34 PM", recordId: "MM-RP-4C82", history: true)
        case "reports-failed":
            reports(state: .failed, title: "The report didn’t finish.", chips: ["9 rooms", "24 photos"])
        case "reports-pro":
            reportsPro
        default:
            Text(screen)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
        }
    }

    private func vault(
        documented: Int,
        total: Int,
        photos: Int,
        records: Int,
        issues: Int,
        address: String,
        next: String?,
        lastProof: String? = nil,
        primary: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MMProofSectionHeader(title: "Your proof", subtitle: "Document now. Prove it later.")
            MMVaultProofHeroCard(
                propertyName: address,
                location: "Toronto, ON",
                coverageLine: "\(documented) of \(total) rooms documented",
                nextRoomName: next,
                progress: total == 0 ? 0 : Double(documented) / Double(total),
                primaryTitle: primary ?? (next.map { "Capture \($0)" } ?? "Review your rooms"),
                onPrimary: {},
                documentedCount: documented,
                totalRooms: total,
                photoCount: photos,
                recordCount: records,
                issueCount: issues,
                lastProofLine: lastProof
            )
        }
    }

    private let sprintRooms = [
        "Kitchen", "Living Room", "Primary Bedroom", "Balcony/Patio", "Bathroom",
        "Hallway", "Laundry", "Storage", "Bedroom 2", "Office",
    ]

    private func sprint(doneThrough: Int, current: String) -> some View {
        let documented = sprintRooms.filter { room in
            guard let index = sprintRooms.firstIndex(of: room) else { return false }
            return index < doneThrough
        }.count
        return VStack(alignment: .leading, spacing: 18) {
            MMRoomProgressCard(
                headline: "\(documented) of \(sprintRooms.count) rooms documented",
                nextLine: "Next: \(current)",
                progress: Double(documented) / Double(sprintRooms.count),
                primaryTitle: "Capture \(current)",
                onPrimary: {},
                documentedCount: documented,
                totalCount: sprintRooms.count
            )
            ForEach(Array(sprintRooms.enumerated()), id: \.offset) { index, name in
                let done = index < doneThrough
                let isNext = name == current
                MMRoomProofRow(
                    index: index + 1,
                    roomName: name,
                    status: done
                        ? .readyToReview(photoCount: 4, issueCount: name == "Kitchen" ? 1 : 0)
                        : (isNext ? .nextUp : .needsPhotos),
                    showsNextBadge: isNext,
                    onTap: {}
                )
            }
        }
    }

    private func reports(
        state: MMReportPreviewHero.State,
        title: String,
        chips: [String],
        generated: String? = nil,
        recordId: String? = nil,
        history: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MMProofSectionHeader(title: "Your reports", subtitle: "Shareable records built from your saved proof.")
            MMReportPreviewHero(
                state: state,
                metricsLine: chips.isEmpty ? nil : chips.joined(separator: " · "),
                headline: title,
                footnote: title,
                proofChips: chips,
                primaryTitle: state == .ready ? "View" : (state == .failed ? "Try again" : "Generate record"),
                generatedLine: generated,
                recordId: recordId,
                onPrimary: {}
            )
            if history {
                historyList
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXPORT HISTORY")
                .font(MoveMarkTheme.Typography.kicker)
                .tracking(1)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ExportHistoryRow(title: "Move-in report", dateLine: "Sep 28 · 6:34 PM", recordId: "MM-RP-4C82", statusLabel: "Ready", statusTone: .success, canShare: true, onShare: {})
                ExportHistoryRow(title: "Move-in report", dateLine: "Sep 12 · 8:02 PM", recordId: "MM-RP-19AA", statusLabel: "Ready", statusTone: .success, canShare: true, onShare: {})
                ExportHistoryRow(title: "Move-out report", dateLine: "Oct 2 · 9:12 AM", recordId: "MM-RP-77B1", statusLabel: "Failed", statusTone: .danger, canRetry: true, onShare: {}, onRetry: {})
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MoveMarkTheme.Surface.raised))
        }
    }

    private var reportsPro: some View {
        VStack(alignment: .leading, spacing: 16) {
            MMProofSectionHeader(title: "Your reports", subtitle: "Shareable records built from your saved proof.")
            MMReportPreviewHero(
                state: .ready,
                metricsLine: "9 rooms · 24 photos",
                headline: "Your move-in record is ready.",
                primaryTitle: "View",
                generatedLine: "Generated Sep 28 · 6:34 PM",
                recordId: "MM-RP-4C82",
                onPrimary: {}
            )
            MMReportExportSection(
                sectionTitle: "Move-out report",
                sectionSubtitle: "Re-capture the same rooms when you leave.",
                statusLabel: "Ready to share",
                statusTone: .success,
                primaryTitle: "Unlock with MoveMark Pro",
                isProLocked: true,
                onPrimary: {}
            )
        }
    }
}

// MARK: - Room QA (full-bleed; mirrors EvidenceCaptureView composition)

private struct RoomQAScreen: View {
    let screen: String
    @State private var picker: [PhotosPickerItem] = []
    @State private var title = ""
    @State private var notes = ""
    @State private var tags: Set<String> = ["Scratch"]
    @State private var condition: RoomRecord.ConditionRating = .fair

    private struct Fixture {
        var name: String
        var moveIn: [EvidenceRecord] = []
        var moveOut: [EvidenceRecord] = []
        var moveOutMode = false
        var pending = 0
    }

    private var fixture: Fixture {
        switch screen {
        case "room-one":
            return Fixture(name: "Primary Bedroom", moveIn: [Self.entry("Primary Bedroom", photos: 1, seed: 0, minutesAgo: 40)])
        case "room-many":
            return Fixture(name: "Kitchen", moveIn: [
                Self.entry("Counters and cabinets", photos: 4, seed: 1, minutesAgo: 20),
                Self.entry("Appliances", photos: 3, seed: 5, minutesAgo: 60),
                Self.entry("Kitchen", photos: 2, seed: 8, minutesAgo: 90),
            ])
        case "room-damage":
            return Fixture(name: "Living Room", moveIn: [
                Self.entry("North wall", photos: 3, seed: 2, minutesAgo: 15, tags: ["Scratch", "Chipped paint"], condition: .fair,
                           notes: "Two scratches beside the window, about 20 cm long. Paint chipped at the baseboard corner."),
                Self.entry("Floor by the balcony door", photos: 2, seed: 6, minutesAgo: 50, tags: ["Water damage"], condition: .belowFair,
                           notes: "Swollen laminate seam, already there at move-in."),
            ])
        case "room-moveout":
            return Fixture(name: "Kitchen",
                           moveIn: [Self.entry("Kitchen", photos: 4, seed: 1, minutesAgo: 60 * 24 * 300)],
                           moveOut: [Self.entry("Kitchen at move-out", photos: 3, seed: 3, minutesAgo: 10)],
                           moveOutMode: true)
        case "room-pending":
            return Fixture(name: "Living Room", pending: 3)
        case "room-dark":
            // Dark evening photo: the gradient and chips must still read and the photo must stay the star.
            return Fixture(name: "Bedroom 2", moveIn: [Self.entry("Bedroom 2 at night", photos: 2, seed: 100, minutesAgo: 25, tags: ["Stain"])])
        case "room-long":
            return Fixture(name: "Primary Bedroom Closet and Ensuite Bathroom",
                           moveIn: [Self.entry("Closet", photos: 2, seed: 4, minutesAgo: 30, tags: ["Stain"])])
        case "room-viewer":
            return Fixture(name: "Kitchen", moveIn: [
                Self.entry("Counters and cabinets", photos: 4, seed: 1, minutesAgo: 20),
            ])
        default: // room-empty
            return Fixture(name: "Balcony/Patio")
        }
    }

    var body: some View {
        if screen == "room-viewer", let first = fixture.moveIn.first {
            RoomPhotoViewer(photos: first.photos, startID: first.photos[1].id, resolvePhotoURL: { Self.fixtureURL(path: $0) }, onClose: {})
        } else {
            roomScreen
        }
    }

    @ViewBuilder
    private var roomScreen: some View {
        let f = fixture
        let entries = f.moveOutMode ? f.moveOut : f.moveIn
        let pendingImages = (0..<f.pending).compactMap { Self.drawnPhoto(seed: $0 + 2) }
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RoomEvidenceHero(
                        roomName: f.name,
                        entries: entries,
                        moveOutMode: f.moveOutMode,
                        topInset: geo.safeAreaInsets.top,
                        containerSize: geo.size,
                        resolvePhotoURL: { Self.fixtureURL(path: $0) },
                        hasPendingPhotos: !pendingImages.isEmpty,
                        pickerSelection: $picker,
                        compareLine: f.moveOutMode && !f.moveIn.isEmpty
                            ? "MOVE-IN \(f.moveIn.reduce(0) { $0 + $1.photoCount }) · MOVE-OUT \(f.moveOut.reduce(0) { $0 + $1.photoCount }) PHOTOS"
                            : nil
                    )
                    VStack(alignment: .leading, spacing: 16) {
                        if !entries.isEmpty {
                            RoomEvidenceBody(
                                entries: entries, moveOutMode: f.moveOutMode, isBusy: false,
                                onEdit: { _ in }, onAddPhotos: { _ in }, onDelete: { _ in }
                            )
                            .padding(.top, 10)
                        }
                        if !pendingImages.isEmpty {
                            Text("New entry")
                                .font(MoveMarkTheme.Typography.kicker).tracking(1.0).textCase(.uppercase)
                                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                                .padding(.top, 18)
                            ProofPhotoGridView(images: pendingImages)
                            EvidenceCaptureForm(
                                title: $title, notes: $notes, selectedTags: $tags, selectedCondition: $condition,
                                selectedItems: $picker, loadedImages: pendingImages, isUploading: false,
                                errorMessage: nil, successMessage: nil, moveOutMode: false,
                                fixedIssueTags: ["Scratch", "Stain", "Water damage", "Chipped paint", "Cracked tile", "Appliance damage"]
                            )
                        }
                    }
                    .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(MoveMarkTheme.Colors.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if !pendingImages.isEmpty {
                EvidenceCaptureBottomSaveBar(
                    photoCount: pendingImages.count, tagCount: tags.count, condition: condition,
                    isUploading: false, didJustSave: false, moveOutMode: false, onSave: {}
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private static func entry(
        _ title: String, photos: Int, seed: Int, minutesAgo: Double,
        tags: [String] = [], condition: RoomRecord.ConditionRating = .good, notes: String = ""
    ) -> EvidenceRecord {
        EvidenceRecord(
            title: title, notes: notes, issueTags: tags, condition: condition,
            createdAt: Date().addingTimeInterval(-minutesAgo * 60),
            photoCount: photos,
            photos: (0..<photos).map { EvidencePhoto(id: UUID(), filePath: "qa-fixture/room-\(seed + $0).jpg") },
            stage: .moveIn
        )
    }

    /// Drawn stand-ins for room photos (wall, floor, window light), varied by seed.
    private static func drawnPhoto(seed: Int) -> UIImage? {
        let palettes: [(UIColor, UIColor)] = [
            (UIColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 1), UIColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1)),
            (UIColor(red: 0.86, green: 0.86, blue: 0.83, alpha: 1), UIColor(red: 0.55, green: 0.50, blue: 0.44, alpha: 1)),
            (UIColor(red: 0.70, green: 0.76, blue: 0.74, alpha: 1), UIColor(red: 0.36, green: 0.30, blue: 0.26, alpha: 1)),
            (UIColor(red: 0.91, green: 0.85, blue: 0.76, alpha: 1), UIColor(red: 0.62, green: 0.47, blue: 0.33, alpha: 1)),
        ]
        let dark = (UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1), UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1))
        let (wall, floor) = seed >= 100 ? dark : palettes[seed % palettes.count]
        let size = CGSize(width: 1200, height: 1400)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            wall.setFill(); c.fill(CGRect(origin: .zero, size: size))
            floor.setFill(); c.fill(CGRect(x: 0, y: 960, width: 1200, height: 440))
            UIColor(white: 0.97, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: 940, width: 1200, height: 22))
            UIColor(red: 0.92, green: 0.95, blue: 0.99, alpha: 1).setFill()
            c.fill(CGRect(x: CGFloat(200 + (seed * 170) % 600), y: 220, width: 320, height: 460))
        }
    }

    private static func fixtureURL(path: String) -> URL? {
        let seed = Int(path.filter(\.isNumber)) ?? 0
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mm-qa-room-\(seed).jpg")
        if !FileManager.default.fileExists(atPath: url.path),
           let data = drawnPhoto(seed: seed)?.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url)
        }
        return url
    }
}


// MARK: - Proof QA (light redesign). Photos: debug-only crops copied into the app's tmp dir by the QA script.

private struct ProofQAScreen: View {
    let screen: String

    private static func fixture(_ name: String) -> String { "qa-fixture/\(name).jpg" }

    private static func resolve(_ path: String) async -> URL? {
        let name = (path as NSString).lastPathComponent
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mm-qa-\(name)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var model: ProofHomeModel {
        let actions: [ProofHomeModel.Action] = [
            .init(id: "lease", kind: .document(.lease), title: "Lease", subtitle: "Add your lease", icon: "doc.text", needed: true),
            .init(id: "deposit", kind: .document(.depositReceipt), title: "Deposit receipt", subtitle: "Proof of deposit", icon: "receipt", needed: true),
            .init(id: "listing", kind: .document(.listingScreenshot), title: "Listing proof", subtitle: "Original listing", icon: "photo", needed: true),
            .init(id: "maintenance", kind: .maintenance, title: "Maintenance", subtitle: "Report an issue", icon: "wrench.adjustable"),
        ]
        var m = ProofHomeModel(
            propertyName: "88 Harbour St",
            addressLine: "Unit 2304",
            documented: 9, totalRooms: 10,
            heroPhotoPath: Self.fixture("proof-hero-v3"),
            nextRoomName: "Primary Bedroom",
            primaryTitle: "Capture Primary Bedroom",
            photos: 12, records: 3, issues: 1,
            recent: [
                .init(id: UUID(), roomName: "Living Room", photoCount: 4, photoPath: Self.fixture("proof-living-v2")),
                .init(id: UUID(), roomName: "Kitchen", photoCount: 3, photoPath: Self.fixture("proof-kitchen-v2")),
                .init(id: UUID(), roomName: "Bedroom", photoCount: 3, photoPath: Self.fixture("proof-bedroom-v2")),
            ],
            actions: actions,
            otherRentals: []
        )
        switch screen {
        case "proof-done":
            m.documented = 10; m.nextRoomName = nil; m.primaryTitle = "View move-in report"
            m.actions = [actions[3], .init(id: "report", kind: .report, title: "Move-in report", subtitle: "Ready to share", icon: "doc.richtext")]
        case "proof-nophoto":
            m.documented = 0; m.heroPhotoPath = nil; m.recent = []; m.photos = 0; m.issues = 0
            m.nextRoomName = "Kitchen"; m.primaryTitle = "Capture Kitchen"
        default: break
        }
        return m
    }

    var body: some View {
        if screen == "proof-empty" {
            ProofHomeEmptyView(onStart: {}, onRetry: {})
        } else {
            // Same mounting as AuthenticatedTabShellView: the bar is a bottom safe-area inset.
            ProofHomeView(model: model, resolvePhotoURL: { await Self.resolve($0) })
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MMProofTabBarV4(selectedTab: .constant(.vaults))
                }
        }
    }
}
#endif
