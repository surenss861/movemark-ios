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

    // Proportions measured from design-refs/proof.jpg (560px screen ↔ 393pt).
    private enum M {
        static let inset = MoveMarkTheme.Light.Space.inset
        static let sheetRadius = MoveMarkTheme.Light.Radius.sheet
        /// The sheet starts at 31% of the screen height and rises this far over the photo.
        static let sheetTopFraction: CGFloat = 0.29
        static let overlap: CGFloat = 28
    }

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let sheetTop = max(fullHeight * M.sheetTopFraction, 250)
            ScrollView {
                VStack(spacing: 0) {
                    hero(height: sheetTop + M.overlap, topInset: geo.safeAreaInsets.top, width: geo.size.width)
                    sheet
                        .padding(.top, -M.overlap)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .background(MoveMarkTheme.Light.surface.ignoresSafeArea())
        .task(id: model.recent.map(\.photoPath)) {
            // Opening a room from here shows its photo full-size immediately.
            MMEvidenceImages.prefetch(paths: model.recent.map(\.photoPath), resolve: resolvePhotoURL)
        }
    }

    // MARK: - Hero

    private func hero(height: CGFloat, topInset: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Fixed frame + overlay: a fill-cropped photo can never widen the screen or letterbox.
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

            // Just enough shade for white text: a whisper at the top, a soft floor under the title.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.42), location: 0.92),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    wordmark
                    Spacer()
                    Button(action: onAddRental) {
                        Image(systemName: "plus")
                            .mmFont(15, .semibold)
                            .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                            .frame(width: 36, height: 36)
                            // Solid base: renders the same wherever the material can't sample a backdrop.
                            .background(Color.white.opacity(0.88), in: Circle())
                            .background(.regularMaterial, in: Circle())
                            .environment(\.colorScheme, .light)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Add a rental")
                    .padding(.trailing, -4)
                }
                .padding(.top, topInset - 4)

                Spacer(minLength: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your proof")
                        .mmFont(26, .bold)
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    Text([model.propertyName, model.addressLine].compactMap { $0 }.joined(separator: " · "))
                        .mmFont(15)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .shadow(color: .black.opacity(0.22), radius: 6, y: 1)

                coveragePill
                    .padding(.top, 14)
                    .padding(.bottom, M.overlap + 16)
            }
            .padding(.horizontal, M.inset)
            .frame(width: width, height: height, alignment: .topLeading)
            // The hero is a fixed photo frame: its text grows to AX1, beyond that the sheet carries size.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private var heroPhoto: some View {
        if let path = model.heroPhotoPath {
            MMEvidenceImage(path: path, resolve: resolvePhotoURL, placeholder: Color(red: 0.30, green: 0.33, blue: 0.32))
        } else {
            // No evidence yet: a calm designed field, never stock photography.
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.42, green: 0.45, blue: 0.43), Color(red: 0.24, green: 0.27, blue: 0.26)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "house")
                    .mmFont(56, .ultraLight)
                    .foregroundStyle(.white.opacity(0.18))
                    .offset(y: -24)
            }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.shield")
                .mmFont(17, .semibold)
                .foregroundStyle(MoveMarkTheme.Light.accent)
            Text("MOVEMARK")
                .mmFont(14, .semibold)
                .tracking(2.0)
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MoveMark")
    }

    /// Compact secondary overlay: small house, slim segments, one line of text, small chevron.
    private var coveragePill: some View {
        Button(action: onOpenRental) {
            HStack(spacing: 10) {
                Image(systemName: "house")
                    .mmFont(15, .semibold)
                    .foregroundStyle(MoveMarkTheme.Light.accent)
                VStack(alignment: .leading, spacing: 5) {
                    if model.totalRooms > 0 { segments }
                    Text(model.totalRooms == 0
                         ? "Add rooms to start"
                         : "\(model.documented) of \(model.totalRooms) rooms documented")
                        .mmFont(13, .medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right")
                    .mmFont(11, .bold)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .frame(minHeight: 44)
            .background(Color.black.opacity(0.42), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.documented) of \(model.totalRooms) rooms documented. Open rental.")
    }

    /// Five slim segments regardless of room count, filled in proportion (reference treatment).
    private var segments: some View {
        let filled = model.totalRooms == 0 ? 0
            : Int((Double(model.documented) / Double(model.totalRooms) * 5).rounded(.down))
        return HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i < filled ? MoveMarkTheme.Light.accent : Color.white.opacity(0.3))
                    .frame(width: 22, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = model.errorMessage {
                errorRow(error).padding(.bottom, 14)
            }

            nextRoomRow
            primaryButton.padding(.top, 8)
            metrics.padding(.top, 12)

            if !model.recent.isEmpty {
                sectionHeader("Recent evidence", trailing: "View all", action: onOpenRental)
                    .padding(.top, 16)
                recentStrip.padding(.top, 10)
            }

            if !model.actions.isEmpty {
                sectionHeader("Next actions").padding(.top, 18)
                actionGrid.padding(.top, 10)
            }

            if !model.otherRentals.isEmpty {
                sectionHeader("Other rentals").padding(.top, 22)
                otherRentals.padding(.top, 12)
            }

            MMSignedInScrollTailSpacer(kind: .rootTab)
        }
        .padding(.horizontal, M.inset)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: M.sheetRadius, topTrailingRadius: M.sheetRadius, style: .continuous)
                .fill(MoveMarkTheme.Light.surface)
        )
    }

    @ViewBuilder
    private var nextRoomRow: some View {
        if let name = model.nextRoomName {
            Button(action: onPrimary) {
                HStack(spacing: 14) {
                    MMIconCircle(systemName: RoomGlyph.symbol(for: name))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next room")
                            .mmFont(12)
                            .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                        Text(name)
                            .mmFont(18, .semibold)
                            .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                            .lineLimit(isAX ? 3 : 1)
                            .minimumScaleFactor(isAX ? 1 : 0.8)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .mmFont(14, .semibold)
                        .foregroundStyle(MoveMarkTheme.Light.textTertiary)
                }
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if model.totalRooms > 0 {
            HStack(spacing: 14) {
                MMIconCircle(systemName: "checkmark", tint: MoveMarkTheme.Light.accent, fill: MoveMarkTheme.Light.accentWash)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Move-in proof")
                        .mmFont(13)
                        .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                    Text("Every room documented")
                        .mmFont(18, .semibold)
                        .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(minHeight: 72)
        }
    }

    /// The one green action. Native proportions, no glow.
    private var primaryButton: some View {
        Button(action: onPrimary) {
            Label(model.primaryTitle, systemImage: model.nextRoomName != nil ? "camera.fill" : "doc.text.fill")
                .mmFont(15, .semibold)
                .foregroundStyle(MoveMarkTheme.Light.onAccent)
                .lineLimit(isAX ? 3 : 1)
                .minimumScaleFactor(isAX ? 1 : 0.85)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .padding(.vertical, isAX ? 8 : 0)
                .padding(.horizontal, 12)
                .background(MoveMarkTheme.Light.cta, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .buttonStyle(MMLightPressStyle())
    }

    @ViewBuilder
    private var metrics: some View {
        let align: Alignment = isAX ? .leading : .center
        let photos = MMMetricItem(icon: "camera", value: model.photos, label: model.photos == 1 ? "Photo" : "Photos", alignment: align)
        let records = MMMetricItem(icon: "doc.text", value: model.records, label: model.records == 1 ? "Record" : "Records", alignment: align)
        let issues = MMMetricItem(icon: "exclamationmark.triangle", value: model.issues, label: model.issues == 1 ? "Issue" : "Issues",
                                  tint: model.issues > 0 ? MoveMarkTheme.Light.attention : MoveMarkTheme.Light.textPrimary,
                                  alignment: align)
        if isAX {
            // Three columns can't hold accessibility sizes; stack them.
            VStack(alignment: .leading, spacing: 10) { photos; records; issues }
                .padding(.vertical, 6)
        } else {
            HStack(spacing: 0) { photos; separator; records; separator; issues }
                .frame(minHeight: 42)
        }
    }

    private var separator: some View {
        Rectangle().fill(MoveMarkTheme.Light.hairline).frame(width: 1, height: 28)
    }

    /// Three across, equal width, filling the row (scrolls if there are more).
    private var recentStrip: some View {
        GeometryReader { geo in
            let gap: CGFloat = 8
            let w = (geo.size.width - gap * 2) / 3
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: gap) {
                    ForEach(model.recent) { item in
                        Button { onOpenRoom(item.id) } label: {
                            MMPhotoCard(path: item.photoPath, title: item.roomName, count: item.photoCount,
                                        size: CGSize(width: w, height: w * 0.88), resolve: resolvePhotoURL)
                        }
                        .buttonStyle(MMLightPressStyle())
                    }
                }
            }
            .scrollClipDisabled()
            .scrollDisabled(model.recent.count <= 3)
        }
        .aspectRatio(3 / 0.88 * 0.98, contentMode: .fit)
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: MoveMarkTheme.Light.Space.tight), count: isAX ? 1 : 2),
            spacing: MoveMarkTheme.Light.Space.tight
        ) {
            ForEach(model.actions) { action in
                Button { onAction(action) } label: {
                    MMLightActionTile(icon: action.icon, title: action.title, subtitle: action.subtitle, needed: action.needed)
                }
                    .buttonStyle(MMLightPressStyle())
            }
        }
    }

    private var otherRentals: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.otherRentals.enumerated()), id: \.element.id) { index, rental in
                if index > 0 { Rectangle().fill(MoveMarkTheme.Light.hairline).frame(height: 1).padding(.leading, 14) }
                Button { onOpenOtherRental(rental.id) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rental.name).mmFont(15, .medium).foregroundStyle(MoveMarkTheme.Light.textPrimary)
                            Text(rental.status).mmFont(12).foregroundStyle(MoveMarkTheme.Light.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").mmFont(12, .semibold).foregroundStyle(MoveMarkTheme.Light.textTertiary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .mmLightSurface()
    }

    private func sectionHeader(_ title: String, trailing: String? = nil, action: (() -> Void)? = nil) -> some View {
        MMLightSectionHeader(title: title, trailing: trailing, action: action)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
            Text(message).mmFont(15).foregroundStyle(MoveMarkTheme.Light.textPrimary)
            Spacer(minLength: 8)
            Button(MMCopy.tryAgain, action: onRetry).mmFont(15, .semibold)
                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
        }
        .padding(14)
        .background(MoveMarkTheme.Light.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
