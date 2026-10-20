//
//  ProofHomeView.swift
//  movemork
//
//  @file Proof tab, light redesign — rental photo hero, coverage pill, white sheet with next room,
//        one capture action, evidence counts, recent evidence, next actions
//  @domain vault
//  @status wip
//  @see [[VISUAL_STANDARD]] — canonical reference design-refs/proof.jpg
//  @see [[VaultRootView.swift]] — feeds this view live data and owns navigation
//

import SwiftUI

/// Everything Proof shows, already computed. Presentational only: no store access here.
struct ProofHomeModel {
    struct Recent: Identifiable {
        let id: UUID            // room id
        let roomName: String
        let photoCount: Int
        let photoPath: String
    }

    /// A room with no proof yet. Fills the evidence row honestly when fewer than three rooms
    /// have photos (never fake evidence).
    struct Upcoming: Identifiable {
        let id: UUID            // room id
        let roomName: String
    }

    struct Action: Identifiable {
        enum Kind { case document(VaultDocumentType), maintenance, report, nudge }
        let id: String
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        var needed: Bool = false
    }

    struct OtherRental: Identifiable {
        let id: UUID
        let name: String
        let status: String
    }

    var propertyName: String
    var addressLine: String?
    var documented: Int
    var totalRooms: Int
    /// Full-size path of the newest evidence photo — the rental's own photo is the hero.
    var heroPhotoPath: String?
    var nextRoomName: String?
    var primaryTitle: String
    var photos: Int
    var records: Int
    var issues: Int
    var recent: [Recent]
    /// Undocumented rooms, next room first.
    var upcoming: [Upcoming] = []
    var actions: [Action]
    var otherRentals: [OtherRental]
    var errorMessage: String?
}

struct ProofHomeView: View {
    let model: ProofHomeModel
    let resolvePhotoURL: (String) async -> URL?
    var onAddRental: () -> Void = {}
    var onOpenRental: () -> Void = {}
    var onPrimary: () -> Void = {}
    var onOpenRoom: (UUID) -> Void = { _ in }
    var onAction: (ProofHomeModel.Action) -> Void = { _ in }
    var onOpenOtherRental: (UUID) -> Void = { _ in }
    var onRetry: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }
    /// Reference was composed at 402pt wide; scale with the screen so proportions hold.
    @State private var k: CGFloat = 1
    private var spec: Spec { Spec(k: k) }

    /// Geometry measured from design-refs/proof.jpg (phone screen 563px ↔ 402pt, 1.40 px/pt).
    /// This screen reproduces that reference; change these only against an overlay comparison.
    private struct Spec {
        let k: CGFloat
        var inset: CGFloat { 18 * k }
        var sheetTop: CGFloat { 251 * k }          // from the top of the screen
        var sheetRadius: CGFloat { 22 * k }
        var wordmarkCenterY: CGFloat { 58 * k }
        var controlSize: CGFloat { 31 * k }
        var titleTop: CGFloat { 112 * k }
        var pillHeight: CGFloat { 49 * k }
        var pillBottomGap: CGFloat { 23 * k }      // pill bottom → sheet top
        var thumb: CGFloat { 60 * k }
        var ctaHeight: CGFloat { 40 * k }
        var tileHeight: CGFloat { 113 * k }
        var tileGap: CGFloat { 7 * k }
        var actionHeight: CGFloat { 51 * k }
        var actionGapH: CGFloat { 11 * k }
        var actionGapV: CGFloat { 9 * k }
    }

    private enum Ink {
        static let sheet = Color(red: 0.973, green: 0.973, blue: 0.973)          // #F8F8F8
        static let tile = Color(red: 0.988, green: 0.988, blue: 0.988)           // #FCFCFC
        static let tileStroke = Color(red: 0.925, green: 0.925, blue: 0.925)     // #ECECEC
        static let text = Color(red: 0.078, green: 0.078, blue: 0.082)           // #141415
        static let secondary = Color(red: 0.588, green: 0.592, blue: 0.596)      // #969798
        static let metricLabel = Color(red: 0.369, green: 0.373, blue: 0.373)    // #5E5F5F
        static let separator = Color(red: 0.933, green: 0.933, blue: 0.937)      // #EEEEEF
        static let lime = Color(red: 0.843, green: 0.949, blue: 0.420)           // #D7F26B (reference CTA)
        static let limeMark = Color(red: 0.757, green: 0.914, blue: 0.298)       // #C1E94C (wordmark, segments)
        static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)
        static let pill = Color(red: 0.137, green: 0.141, blue: 0.141)           // #232424
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0 * k) {
                    hero(width: geo.size.width, topInset: geo.safeAreaInsets.top)
                    sheet
                        .padding(.top, -spec.sheetRadius)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .background(Ink.sheet.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            k = min(max(width / 402, 0.92), 1.12)
        }
        .environment(\.mmLayoutScale, k)
        .task(id: model.recent.map(\.photoPath)) {
            MMEvidenceImages.prefetch(paths: model.recent.map(\.photoPath), resolve: resolvePhotoURL)
        }
    }

    // MARK: - Hero (the photograph is the header)

    private func hero(width: CGFloat, topInset: CGFloat) -> some View {
        let height = spec.sheetTop + spec.sheetRadius
        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: width, height: height)
                .overlay { heroPhoto }
                .visualEffect { content, proxy in
                    let y = proxy.frame(in: .scrollView).minY
                    guard !reduceMotion else { return content.scaleEffect(1).offset(y: 0) }
                    return content
                        .scaleEffect(y > 0 ? 1 + y / max(proxy.size.height, 1) : 1, anchor: .bottom)
                        .offset(y: y < 0 ? -y * 0.35 : 0)
                }
                .clipped()

            // Only where text sits: a light veil at the very top and behind the title block.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.22), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .black.opacity(0.10), location: 0.45),
                    .init(color: .black.opacity(0.30), location: 0.75),
                    .init(color: .black.opacity(0.18), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Wordmark + control, centred on y = 58.
            HStack(spacing: 0 * k) {
                wordmark
                Spacer()
                heroControl
            }
            .frame(height: 44 * k)
            .padding(.horizontal, spec.inset)
            .offset(y: spec.wordmarkCenterY - 22)

            VStack(alignment: .leading, spacing: 3 * k) {
                Text("Your proof")
                    .mmFont(25, .semibold)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text([model.propertyName, model.addressLine].compactMap { $0 }.joined(separator: " · "))
                    .mmFont(13.8)
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                coveragePill
                    .padding(.top, 15 * k)
            }
            .shadow(color: .black.opacity(0.18), radius: 6, y: 1)
            .padding(.horizontal, spec.inset)
            .frame(width: width, height: spec.sheetTop - spec.pillBottomGap, alignment: .bottomLeading)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private var heroPhoto: some View {
        if let path = model.heroPhotoPath {
            MMEvidenceImage(path: path, resolve: resolvePhotoURL, placeholder: Color(red: 0.70, green: 0.72, blue: 0.73))
        } else {
            // No evidence yet: a calm designed field, never stock photography.
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.62, green: 0.65, blue: 0.66), Color(red: 0.40, green: 0.43, blue: 0.44)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "house")
                    .font(.system(size: 56 * k, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.22))
                    .offset(y: -30)
            }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 6 * k) {
            ZStack {
                Image(systemName: "hexagon")
                    .font(.system(size: 21 * k, weight: .semibold))
                Image(systemName: "checkmark")
                    .font(.system(size: 9 * k, weight: .heavy))
            }
            .frame(width: 20 * k)
            .foregroundStyle(Ink.limeMark)
            Text("MOVEMARK")
                .font(.system(size: 14.6 * k, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MoveMark")
    }

    /// The reference's round control. Here it holds the rental actions: add a rental, or switch
    /// to another one (so the screen needs no separate "Other rentals" section).
    private var heroControl: some View {
        Menu {
            Button(action: onAddRental) { Label("Add a rental", systemImage: "plus") }
            if !model.otherRentals.isEmpty {
                Section("Your rentals") {
                    ForEach(model.otherRentals) { rental in
                        Button { onOpenOtherRental(rental.id) } label: { Text(rental.name); Text(rental.status) }
                    }
                }
            }
        } label: {
            Image(systemName: model.otherRentals.isEmpty ? "plus" : "ellipsis")
                .font(.system(size: 14 * k, weight: .semibold))
                .foregroundStyle(Ink.text)
                .frame(width: spec.controlSize, height: spec.controlSize)
                .background(Color(red: 0.965, green: 0.961, blue: 0.961).opacity(0.94), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                .frame(width: 44 * k, height: 44 * k)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(model.otherRentals.isEmpty ? "Add a rental" : "Rentals")
        // The 44pt hit area overhangs; the visible circle's edge sits exactly on the screen inset.
        .padding(.trailing, -(44 * k - spec.controlSize) / 2)
    }

    private var coveragePill: some View {
        Button(action: onOpenRental) {
            HStack(spacing: 0 * k) {
                Image(systemName: "house")
                    .font(.system(size: 17.5 * k, weight: .regular))
                    .foregroundStyle(Ink.limeMark)
                    .frame(width: 20 * k)
                    .padding(.leading, 16 * k)
                VStack(alignment: .leading, spacing: 9 * k) {
                    if model.totalRooms > 0 { segments }
                    Text(model.totalRooms == 0
                         ? "Add rooms to start"
                         : "\(model.documented) of \(model.totalRooms) rooms documented")
                        .mmFont(11, .medium)
                        .foregroundStyle(.white)
                        .lineLimit(isAX ? 2 : 1)
                }
                .padding(.leading, 7 * k)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10 * k, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.leading, 11 * k)
                    .padding(.trailing, 16 * k)
            }
            .frame(minHeight: spec.pillHeight)
            .background(Ink.pill.opacity(0.88), in: Capsule())
            .fixedSize(horizontal: !isAX, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.documented) of \(model.totalRooms) rooms documented. Open rental.")
    }

    /// Five slim segments filled in proportion to rooms documented.
    private var segments: some View {
        // Any progress lights at least one segment (1 of 10 used to show none).
        let filled = model.totalRooms == 0 || model.documented == 0 ? 0
            : max(1, Int((Double(model.documented) / Double(model.totalRooms) * 5).rounded(.down)))
        return HStack(spacing: 3 * k) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i < filled ? Ink.limeMark : Color.white.opacity(0.32))
                    .frame(width: 25 * k, height: 3.5 * k)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0 * k) {
            if let error = model.errorMessage {
                errorRow(error).padding(.bottom, 12 * k)
            }
            nextRoomRow
            primaryButton.padding(.top, 7 * k)
            metrics.padding(.top, 30 * k)
            if !model.recent.isEmpty {
                sectionHeader("Recent evidence", trailing: "View all", action: onOpenRental)
                    .padding(.top, 31 * k)
                recentStrip.padding(.top, 11 * k)
            }
            roomsToCapture.padding(.top, 20 * k)
            if !model.actions.isEmpty {
                sectionHeader("Next actions").padding(.top, 24 * k)
                actionGrid.padding(.top, 10 * k)
            }
            MMSignedInScrollTailSpacer(kind: .rootTab)
        }
        .padding(.horizontal, spec.inset)
        .padding(.top, 15 * k)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: spec.sheetRadius, topTrailingRadius: spec.sheetRadius, style: .continuous)
                .fill(Ink.sheet)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        )
    }

    @ViewBuilder
    private var nextRoomRow: some View {
        if let name = model.nextRoomName {
            Button(action: onPrimary) {
                HStack(spacing: 13 * k) {
                    MMIconCircle(systemName: RoomGlyph.symbol(for: name), size: spec.thumb,
                                 tint: Ink.text.opacity(0.65), fill: Color(red: 0.91, green: 0.91, blue: 0.90))
                    VStack(alignment: .leading, spacing: 4 * k) {
                        Text("Next room")
                            .mmFont(10.5)
                            .foregroundStyle(Ink.secondary)
                        Text(name)
                            .mmFont(15.6, .semibold)
                            .foregroundStyle(Ink.text)
                            .lineLimit(isAX ? 3 : 1)
                            .minimumScaleFactor(isAX ? 1 : 0.8)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13 * k, weight: .semibold))
                        .foregroundStyle(Ink.text.opacity(0.75))
                        .padding(.trailing, 12 * k)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if model.totalRooms > 0 {
            HStack(spacing: 13 * k) {
                MMIconCircle(systemName: "checkmark", size: spec.thumb, tint: Ink.onLime, fill: Ink.lime.opacity(0.55))
                VStack(alignment: .leading, spacing: 4 * k) {
                    Text("Move-in proof").mmFont(10.5).foregroundStyle(Ink.secondary)
                    Text("Every room documented").mmFont(15.6, .semibold).foregroundStyle(Ink.text)
                        .lineLimit(isAX ? 3 : 1).minimumScaleFactor(isAX ? 1 : 0.8)
                }
            }
        }
    }

    /// The one primary action, in the reference lime (brand tuning after the match is approved).
    private var primaryButton: some View {
        Button(action: onPrimary) {
            HStack(spacing: 8 * k) {
                Image(systemName: model.nextRoomName != nil ? "camera.fill" : "doc.text.fill")
                    .font(.system(size: 13 * k, weight: .semibold))
                Text(model.primaryTitle)
                    .mmFont(12.5, .semibold)
                    .lineLimit(isAX ? 3 : 1)
                    .minimumScaleFactor(isAX ? 1 : 0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Ink.onLime)
            .frame(maxWidth: .infinity)
            .frame(minHeight: spec.ctaHeight)
            .padding(.vertical, isAX ? 8 : 0)
            .background(Ink.lime, in: RoundedRectangle(cornerRadius: spec.ctaHeight / 2, style: .continuous))
            .shadow(color: Ink.lime.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(MMLightPressStyle())
    }

    @ViewBuilder
    private var metrics: some View {
        let items: [(String, Int, String)] = [
            ("camera", model.photos, "Photos"),
            ("doc.text", model.records, "Records"),
            ("exclamationmark.triangle", model.issues, "Issues"),
        ]
        if isAX {
            VStack(alignment: .leading, spacing: 10 * k) {
                ForEach(items, id: \.2) { metric($0.0, $0.1, $0.2) }
            }
        } else {
            // Positions measured from the reference (fractions of the content width): its three
            // columns are not equal thirds, so a plain HStack drifts.
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        metric(item.0, item.1, item.2)
                            .offset(x: w * [0.074, 0.426, 0.780][i])
                    }
                    ForEach([0.333, 0.677], id: \.self) { f in
                        Rectangle().fill(Ink.separator).frame(width: 1 * k, height: 32 * k)
                            .offset(x: w * f)
                    }
                }
                .frame(width: w, height: geo.size.height, alignment: .leading)
            }
            .frame(height: 34 * k)
        }
    }

    private func metric(_ icon: String, _ value: Int, _ label: String) -> some View {
        HStack(alignment: .center, spacing: 8 * k) {
            Image(systemName: icon)
                .font(.system(size: 18 * k, weight: .regular))
                .foregroundStyle(Ink.text)
            VStack(alignment: .leading, spacing: 2 * k) {
                Text("\(value)")
                    .mmFont(16, .medium)
                    .foregroundStyle(Ink.text)
                    .monospacedDigit()
                Text(label)
                    .mmFont(8.2)
                    .foregroundStyle(Ink.metricLabel)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var recentStrip: some View {
        GeometryReader { geo in
            let w = (geo.size.width - spec.tileGap * 2) / 3
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spec.tileGap) {
                    ForEach(model.recent) { item in
                        Button { onOpenRoom(item.id) } label: { evidenceTile(item, width: w) }
                            .buttonStyle(MMLightPressStyle())
                    }
                }
            }
            .scrollClipDisabled()
            .scrollDisabled(model.recent.count <= 3)
        }
        .frame(height: spec.tileHeight)
    }

    private func evidenceTile(_ item: ProofHomeModel.Recent, width: CGFloat) -> some View {
        MMEvidenceImage(path: item.photoPath, resolve: resolvePhotoURL, size: CGSize(width: width, height: spec.tileHeight))
            .frame(width: width, height: spec.tileHeight)
            .overlay(alignment: .bottom) {
                HStack(spacing: 3 * k) {
                    Image(systemName: "camera").font(.system(size: 7.5 * k, weight: .medium))
                    Text(item.roomName).mmFont(8, .medium).lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: "camera").font(.system(size: 7.5 * k, weight: .medium))
                    Text("\(item.photoCount)").mmFont(8, .medium).monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9 * k)
                .frame(height: 21 * k)
                .background(Color.black.opacity(0.55))
            }
            .clipShape(RoundedRectangle(cornerRadius: 11 * k, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.roomName), \(item.photoCount) photos")
    }

    /// Rooms with no proof besides the next room: a quiet line, never placed among evidence.
    @ViewBuilder
    private var roomsToCapture: some View {
        let others = model.upcoming.filter { $0.roomName != model.nextRoomName }
        if !others.isEmpty {
            Button(action: onOpenRental) {
                HStack(spacing: 8 * k) {
                    VStack(alignment: .leading, spacing: 3 * k) {
                        Text("Rooms still to capture")
                            .mmFont(10.5)
                            .foregroundStyle(Ink.secondary)
                        Text(others.prefix(3).map(\.roomName).joined(separator: " · ")
                             + (others.count > 3 ? " +\(others.count - 3)" : ""))
                            .mmFont(12.5, .medium)
                            .foregroundStyle(Ink.text)
                            .lineLimit(isAX ? 3 : 1)
                    }
                    Spacer(minLength: 4 * k)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10 * k, weight: .semibold))
                        .foregroundStyle(Ink.secondary)
                        .padding(.trailing, 12 * k)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(others.count) rooms still to capture: \(others.map(\.roomName).joined(separator: ", "))")
        }
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spec.actionGapH), count: isAX ? 1 : 2),
            spacing: spec.actionGapV
        ) {
            ForEach(model.actions) { action in
                Button { onAction(action) } label: { actionTile(action) }
                    .buttonStyle(MMLightPressStyle())
            }
        }
    }

    private func actionTile(_ action: ProofHomeModel.Action) -> some View {
        HStack(spacing: 0 * k) {
            Image(systemName: action.icon)
                .font(.system(size: 16 * k, weight: .regular))
                .foregroundStyle(Ink.text)
                .frame(width: 20 * k)
                .padding(.leading, 10 * k)
            VStack(alignment: .leading, spacing: 4 * k) {
                Text(action.title)
                    .mmFont(10.8, .medium)
                    .foregroundStyle(Ink.text)
                    .lineLimit(isAX ? 3 : 1)
                Text(action.subtitle)
                    .mmFont(8.3)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(isAX ? 3 : 1)
            }
            .padding(.leading, 9 * k)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 10 * k, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .padding(.trailing, 12 * k)
        }
        .frame(maxWidth: .infinity, minHeight: spec.actionHeight)
        .padding(.vertical, isAX ? 8 : 0)
        .background(Ink.tile, in: RoundedRectangle(cornerRadius: 11 * k, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11 * k, style: .continuous).strokeBorder(Ink.tileStroke, lineWidth: 0.75))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: String, trailing: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .mmFont(14.4, .semibold)
                .foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    HStack(spacing: 6 * k) {
                        Text(trailing)
                        Image(systemName: "chevron.right").font(.system(size: 10 * k, weight: .semibold))
                    }
                    .mmFont(11.6)
                    .foregroundStyle(Ink.secondary)
                }
                .padding(.trailing, 12 * k)
            }
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10 * k) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
            Text(message).mmFont(14).foregroundStyle(Ink.text)
            Spacer(minLength: 8)
            Button(MMCopy.tryAgain, action: onRetry).mmFont(14, .semibold).foregroundStyle(Ink.text)
        }
        .padding(12)
        .background(Ink.tile, in: RoundedRectangle(cornerRadius: 11 * k, style: .continuous))
    }
}

// MARK: - Pieces

/// Next room has no photo yet (that's why it's next), so it gets a quiet glyph for its kind.
enum RoomGlyph {
    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("bed") { return "bed.double" }
        if n.contains("kitchen") || n.contains("dining") { return "fork.knife" }
        if n.contains("bath") || n.contains("ensuite") || n.contains("washroom") { return "shower" }
        if n.contains("living") || n.contains("family") || n.contains("lounge") { return "sofa" }
        if n.contains("balcony") || n.contains("patio") || n.contains("terrace") { return "sun.max" }
        if n.contains("laundry") { return "washer" }
        if n.contains("office") || n.contains("study") { return "desktopcomputer" }
        return "door.left.hand.open"
    }
}

/// No rental yet: same light language, a designed field instead of a photo, one green action.
struct ProofHomeEmptyView: View {
    var errorMessage: String?
    var onStart: () -> Void
    var onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color(red: 0.36, green: 0.40, blue: 0.38), Color(red: 0.20, green: 0.23, blue: 0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "house")
                        .mmFont(72, .ultraLight)
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield").mmFont(18, .semibold)
                            .foregroundStyle(MoveMarkTheme.Light.accent)
                        Text("MOVEMARK").mmFont(15, .semibold).tracking(2.2).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 70)
                }
                .frame(height: 340)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Prove what was already there.")
                        .mmFont(30, .bold)
                        .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Add your rental, then photograph each room before you unpack. MoveMark keeps it as a dated record.")
                        .mmFont(17)
                        .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                    if let errorMessage {
                        HStack {
                            Text(errorMessage).mmFont(15).foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
                            Spacer()
                            Button(MMCopy.tryAgain, action: onRetry).mmFont(15, .semibold)
                        }
                    }
                    Button(action: onStart) {
                        Label("Add your rental", systemImage: "plus")
                            .mmFont(17, .semibold)
                            .foregroundStyle(MoveMarkTheme.Light.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                            .background(MoveMarkTheme.Light.accent, in: Capsule())
                    }
                    .padding(.top, 12)
                }
                .padding(22)
                .padding(.top, 6)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: MoveMarkTheme.Light.sheetRadius, topTrailingRadius: MoveMarkTheme.Light.sheetRadius, style: .continuous)
                        .fill(MoveMarkTheme.Light.surface)
                )
                .padding(.top, -MoveMarkTheme.Light.sheetRadius)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(MoveMarkTheme.Light.surface.ignoresSafeArea())
    }
}
