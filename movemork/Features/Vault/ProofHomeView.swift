//
//  ProofHomeView.swift
//  movemork
//
//  @file Proof tab — quiet dark header (rental + proof progress), next room with the one capture
//        action, evidence counts, recent evidence strip, rooms remaining, next actions
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
        var capturedAt: Date? = nil
    }

    /// A room with no proof yet.
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

/// The Proof tab: one rental, its proof state, one next action. A quiet dark header carries the rental
/// and its progress (never a captured photo — evidence lives only inside its own clipped thumbnails);
/// below it, the next room with the one capture action, then the evidence and what's left to do.
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }
    /// Composed at 402pt wide; scale with the screen so proportions hold.
    @State private var k: CGFloat = 1
    private var spec: Spec { Spec(k: k) }

    private struct Spec {
        let k: CGFloat
        var inset: CGFloat { 20 * k }
        var sheetRadius: CGFloat { 22 * k }
        var controlSize: CGFloat { 32 * k }
        var ctaHeight: CGFloat { 44 * k }
        var tile: CGFloat { 104 * k }              // evidence thumbnails in the scrolling strip
        var soloTile: CGFloat { 128 * k }          // the only one: same tile, more presence
        var tileGap: CGFloat { 10 * k }
        var rowHeight: CGFloat { 50 * k }
        var cardRadius: CGFloat { 16 * k }
    }

    fileprivate enum Ink {
        static let hero = Color(red: 0.086, green: 0.094, blue: 0.090)          // #161817
        static let heroSecondary = Color.white.opacity(0.62)
        static let track = Color.white.opacity(0.16)
        static let sheet = Color(red: 0.973, green: 0.973, blue: 0.973)          // #F8F8F8
        static let card = Color.white
        static let cardStroke = Color(red: 0.925, green: 0.925, blue: 0.925)     // #ECECEC
        static let text = Color(red: 0.078, green: 0.078, blue: 0.082)           // #141415
        static let secondary = Color(red: 0.494, green: 0.498, blue: 0.502)      // #7E7F80
        static let separator = Color(red: 0.918, green: 0.918, blue: 0.922)      // #EAEAEB
        static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)           // #CAE36C: signal, not highlighter
        static let limeMark = Color(red: 0.757, green: 0.914, blue: 0.298)       // #C1E94C
        static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)
        static let thumbFill = Color(red: 0.91, green: 0.91, blue: 0.90)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                sheet.padding(.top, -spec.sheetRadius)
            }
        }
        .scrollIndicators(.hidden)
        // The status bar keeps a solid band of the header colour, so scrolled content never runs under
        // the clock (the white status bar text stays legible over it).
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(Ink.hero.ignoresSafeArea(edges: .top))
        }
        // The dark header colour runs up under the status bar; the header's content stays below it.
        .background(alignment: .top) { Ink.hero.frame(height: 420).ignoresSafeArea(edges: .top) }
        .background(Ink.sheet.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            k = min(max(width / 402, 0.92), 1.12)
        }
        .environment(\.mmLayoutScale, k)
        .task(id: model.recent.map(\.photoPath)) {
            MMEvidenceImages.prefetch(paths: model.recent.map(\.photoPath), resolve: resolvePhotoURL)
        }
    }

    // MARK: - Header: the rental and its proof state

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                wordmark
                Spacer()
                heroControl
            }
            .frame(height: 44 * k)

            if !isAX {
                Text("YOUR PROOF")
                    .mmFont(11, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.heroSecondary)
                    .padding(.top, 22 * k)
            }
            Text(model.propertyName)
                .mmFont(27, .semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, isAX ? 14 * k : 6 * k)
            if let address = model.addressLine {
                Text(address)
                    .mmFont(14)
                    .foregroundStyle(Ink.heroSecondary)
                    .lineLimit(isAX ? 3 : 1)
                    .padding(.top, 3 * k)
            }
            progress.padding(.top, 22 * k)
        }
        .padding(.horizontal, spec.inset)
        .padding(.bottom, 26 * k + spec.sheetRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.hero)
        // At accessibility sizes the header compacts (capped type, no eyebrow) so the next room and its
        // capture action stay on the first screen; VoiceOver still reads the full property name.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// Text only: identity without a brand lockup.
    private var wordmark: some View {
        Text("MoveMark")
            .font(.system(size: 17 * k, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
    }

    /// Add a rental, or switch to another one.
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
                .foregroundStyle(.white)
                .frame(width: spec.controlSize, height: spec.controlSize)
                .background(Color.white.opacity(0.12), in: Circle())
                .frame(width: 44 * k, height: 44 * k)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(model.otherRentals.isEmpty ? "Add a rental" : "Rentals")
        .padding(.trailing, -(44 * k - spec.controlSize) / 2)
    }

    /// Evidence completeness, stated plainly: a thin bar and the count it stands for.
    private var progress: some View {
        let fraction = model.totalRooms == 0 ? 0 : Double(model.documented) / Double(model.totalRooms)
        return Button(action: onOpenRental) {
            VStack(alignment: .leading, spacing: 9 * k) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Move-in proof").mmFont(12.5, .medium).foregroundStyle(.white)
                    Spacer()
                    if model.totalRooms > 0 {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .mmFont(12.5, .medium).monospacedDigit().foregroundStyle(Ink.heroSecondary)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Ink.track)
                        Capsule().fill(Ink.limeMark)
                            .frame(width: model.documented == 0 ? 0 : max(geo.size.width * fraction, 4 * k))
                    }
                }
                .frame(height: 4 * k)
                HStack(spacing: 4 * k) {
                    Text(model.totalRooms == 0
                         ? "Add rooms to start"
                         : "\(model.documented) of \(model.totalRooms) rooms documented")
                    Image(systemName: "chevron.right").font(.system(size: 9 * k, weight: .semibold))
                }
                .mmFont(12.5)
                .foregroundStyle(Ink.heroSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.totalRooms == 0 ? "Add rooms to start. Open rental."
                            : "\(model.documented) of \(model.totalRooms) rooms documented. Open rental.")
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = model.errorMessage {
                errorRow(error).padding(.bottom, 14 * k)
            }
            nextRoomCard
            metrics.padding(.top, 16 * k)
            if !model.recent.isEmpty {
                sectionHeader("Recent evidence", trailing: "View all", action: onOpenRental)
                    .padding(.top, 30 * k)
                recentStrip.padding(.top, 12 * k)
            }
            roomsRemaining.padding(.top, 28 * k)
            if !model.actions.isEmpty {
                sectionHeader("Next actions").padding(.top, 30 * k)
                actionList.padding(.top, 12 * k)
            }
            MMSignedInScrollTailSpacer(kind: .rootTab)
        }
        .padding(.horizontal, spec.inset)
        .padding(.top, 20 * k)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: spec.sheetRadius, topTrailingRadius: spec.sheetRadius, style: .continuous)
                .fill(Ink.sheet)
        )
    }

    /// The one primary action: the next room and its capture button, together.
    @ViewBuilder
    private var nextRoomCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = model.nextRoomName {
                Button(action: onPrimary) {
                    VStack(alignment: .leading, spacing: 1 * k) {
                        Text("Next room").mmFont(12).foregroundStyle(Ink.secondary)
                        HStack(spacing: 8 * k) {
                            if !isAX {
                                Image(systemName: RoomGlyph.symbol(for: name))
                                    .font(.system(size: 16 * k, weight: .regular))
                                    .foregroundStyle(Ink.text.opacity(0.7))
                            }
                            Text(name)
                                .mmFont(20, .semibold)
                                .foregroundStyle(Ink.text)
                                .lineLimit(isAX ? 3 : 1)
                                .minimumScaleFactor(isAX ? 1 : 0.8)
                        }
                        if !isAX { Text("No proof yet").mmFont(13).foregroundStyle(Ink.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if model.totalRooms > 0 {
                VStack(alignment: .leading, spacing: 1 * k) {
                    Text("Move-in proof").mmFont(12).foregroundStyle(Ink.secondary)
                    Text("Every room documented")
                        .mmFont(20, .semibold).foregroundStyle(Ink.text)
                        .lineLimit(isAX ? 3 : 1).minimumScaleFactor(isAX ? 1 : 0.8)
                }
            }
            primaryButton.padding(.top, 12 * k)
        }
        .padding(.horizontal, 18 * k)
        .padding(.vertical, 14 * k)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: spec.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: spec.cardRadius, style: .continuous).strokeBorder(Ink.cardStroke, lineWidth: 0.75))
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            HStack(spacing: 8 * k) {
                Image(systemName: model.nextRoomName != nil ? "camera.fill" : "doc.text.fill")
                    .font(.system(size: 14 * k, weight: .semibold))
                Text(model.primaryTitle)
                    .mmFont(14.5, .semibold)
                    .lineLimit(isAX ? 3 : 1)
                    .minimumScaleFactor(isAX ? 1 : 0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Ink.onLime)
            .frame(maxWidth: .infinity)
            .frame(minHeight: spec.ctaHeight)
            .padding(.vertical, isAX ? 8 : 0)
            .background(Ink.lime, in: RoundedRectangle(cornerRadius: spec.ctaHeight / 2, style: .continuous))
        }
        .buttonStyle(MMLightPressStyle())
    }

    /// The counts, subordinate to the proof state: one quiet line.
    private var metrics: some View {
        let items: [(String, Int, String, String)] = [
            ("camera", model.photos, "photo", "photos"),
            ("doc.text", model.records, "record", "records"),
            ("exclamationmark.triangle", model.issues, "issue", "issues"),
        ]
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 18 * k) { ForEach(items, id: \.2) { metric($0) } }
            VStack(alignment: .leading, spacing: 8 * k) { ForEach(items, id: \.2) { metric($0) } }
        }
        .padding(.horizontal, 4 * k)
    }

    private func metric(_ item: (String, Int, String, String)) -> some View {
        HStack(spacing: 6 * k) {
            Image(systemName: item.0).font(.system(size: 12 * k, weight: .regular))
            Text("\(item.1) \(item.1 == 1 ? item.2 : item.3)").mmFont(13).monospacedDigit()
        }
        .foregroundStyle(Ink.secondary)
        .accessibilityElement(children: .combine)
    }

    private var recentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spec.tileGap) {
                ForEach(model.recent) { item in
                    Button { onOpenRoom(item.id) } label: { evidenceTile(item, side: model.recent.count == 1 ? spec.soloTile : spec.tile) }
                        .buttonStyle(MMLightPressStyle())
                }
            }
        }
        .scrollDisabled(CGFloat(model.recent.count) * (spec.tile + spec.tileGap) < 380 * k)
    }

    /// Fixed size and clipped to its own shape: a photo can never draw outside its tile.
    private func evidenceTile(_ item: ProofHomeModel.Recent, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7 * k) {
            MMEvidenceImage(path: item.photoPath, resolve: resolvePhotoURL,
                            size: CGSize(width: side, height: side), placeholder: Ink.thumbFill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 12 * k, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12 * k, style: .continuous))
            VStack(alignment: .leading, spacing: 2 * k) {
                Text(item.roomName).mmFont(12.5, .medium).foregroundStyle(Ink.text).lineLimit(1)
                Text(caption(for: item)).mmFont(11.5).foregroundStyle(Ink.secondary).lineLimit(1)
            }
            .frame(width: side, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.roomName), \(item.photoCount) \(item.photoCount == 1 ? "photo" : "photos")")
    }

    private func caption(for item: ProofHomeModel.Recent) -> String {
        let count = "\(item.photoCount) \(item.photoCount == 1 ? "photo" : "photos")"
        guard let date = item.capturedAt else { return count }
        let day = Calendar.current.isDateInToday(date) ? "Today"
            : Calendar.current.isDateInYesterday(date) ? "Yesterday"
            : date.formatted(.dateTime.month(.abbreviated).day())
        return "\(day) · \(count)"
    }

    /// Every room without proof — the next room included, so it adds up with the header's count. One row
    /// into the rental, not a list of names.
    @ViewBuilder
    private var roomsRemaining: some View {
        let others = model.upcoming
        if others.count > 1 || (others.count == 1 && model.nextRoomName == nil) {
            listContainer {
                listRow(icon: "square.grid.2x2",
                        title: "\(others.count) \(others.count == 1 ? "room still needs" : "rooms still need") proof",
                        action: onOpenRental)
            }
            .accessibilityLabel("\(others.count) rooms still need proof: \(others.map(\.roomName).joined(separator: ", "))")
        }
    }

    private var actionList: some View {
        listContainer {
            ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                if index > 0 { Divider().overlay(Ink.separator).padding(.leading, 50 * k) }
                listRow(icon: action.icon, title: action.title, subtitle: action.subtitle) { onAction(action) }
            }
        }
    }

    private func listContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Ink.card, in: RoundedRectangle(cornerRadius: spec.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: spec.cardRadius, style: .continuous).strokeBorder(Ink.cardStroke, lineWidth: 0.75))
    }

    private func listRow(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14 * k) {
                Image(systemName: icon)
                    .font(.system(size: 16 * k, weight: .regular))
                    .foregroundStyle(Ink.text.opacity(0.75))
                    .frame(width: 22 * k)
                VStack(alignment: .leading, spacing: 2 * k) {
                    Text(title).mmFont(14.5).foregroundStyle(Ink.text).lineLimit(isAX ? 3 : 1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).mmFont(12).foregroundStyle(Ink.secondary).lineLimit(isAX ? 3 : 1)
                    }
                }
                Spacer(minLength: 8 * k)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11 * k, weight: .semibold))
                    .foregroundStyle(Ink.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14 * k)
            .frame(maxWidth: .infinity, minHeight: spec.rowHeight)
            .padding(.vertical, isAX ? 8 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: String, trailing: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .mmFont(16, .semibold)
                .foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    HStack(spacing: 4 * k) {
                        Text(trailing)
                        Image(systemName: "chevron.right").font(.system(size: 10 * k, weight: .semibold))
                    }
                    .mmFont(13)
                    .foregroundStyle(Ink.secondary)
                }
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
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12 * k, style: .continuous))
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

    private typealias Ink = ProofHomeView.Ink

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Same quiet dark field as the Vault header, with the text-only wordmark.
                VStack(alignment: .leading, spacing: 0) {
                    Text("MoveMark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(height: 44)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                .background(Ink.hero)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Prove what was already there.")
                        .mmFont(30, .bold)
                        .foregroundStyle(Ink.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("Add your rental, then photograph each room before you unpack. MoveMark keeps it as a dated record.")
                        .mmFont(17)
                        .foregroundStyle(Ink.secondary)
                    if let errorMessage {
                        HStack {
                            Text(errorMessage).mmFont(15).foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
                            Spacer()
                            Button(MMCopy.tryAgain, action: onRetry).mmFont(15, .semibold)
                        }
                    }
                    Button(action: onStart) {
                        Label("Add your rental", systemImage: "plus")
                            .mmFont(16, .semibold)
                            .foregroundStyle(Ink.onLime)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Ink.lime, in: Capsule())
                    }
                    .buttonStyle(MMLightPressStyle())
                    .padding(.top, 12)
                }
                .padding(20)
                .padding(.top, 8)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                        .fill(Ink.sheet)
                )
                .padding(.top, -22)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(Ink.hero.ignoresSafeArea(edges: .top))
        }
        .background(alignment: .top) { Ink.hero.frame(height: 300).ignoresSafeArea(edges: .top) }
        .background(Ink.sheet.ignoresSafeArea())
    }
}
