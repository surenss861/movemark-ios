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

    var body: some View {
        GeometryReader { geo in
            let heroHeight = max(geo.size.height * 0.40, 300) + geo.safeAreaInsets.top
            ScrollView {
                VStack(spacing: 0) {
                    hero(height: heroHeight, topInset: geo.safeAreaInsets.top, width: geo.size.width)
                    sheet
                        // The sheet rises over the bottom of the photo.
                        .padding(.top, -MoveMarkTheme.Light.sheetRadius)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .background(MoveMarkTheme.Light.surface.ignoresSafeArea())
    }

    // MARK: - Hero

    private func hero(height: CGFloat, topInset: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
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

            // Only as much shade as legibility needs: top for the wordmark, bottom for the title.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.38), location: 0),
                    .init(color: .clear, location: 0.28),
                    .init(color: .clear, location: 0.45),
                    .init(color: .black.opacity(0.55), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    wordmark
                    Spacer()
                    Button(action: onAddRental) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(.regularMaterial, in: Circle())
                            .environment(\.colorScheme, .light)
                    }
                    .accessibilityLabel("Add a rental")
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your proof")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    Text([model.propertyName, model.addressLine].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .shadow(color: .black.opacity(0.25), radius: 8, y: 1)

                coveragePill
                    .padding(.top, 16)
                    .padding(.bottom, MoveMarkTheme.Light.sheetRadius + 18)
            }
            .padding(.horizontal, 22)
            .frame(height: height, alignment: .top)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var heroPhoto: some View {
        if let path = model.heroPhotoPath {
            HeroPhoto(path: path, resolvePhotoURL: resolvePhotoURL)
        } else {
            // No evidence yet: a calm designed field, never stock photography.
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.36, green: 0.40, blue: 0.38), Color(red: 0.20, green: 0.23, blue: 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "house")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.16))
                    .offset(y: -20)
            }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Light.accent)
            Text("MOVEMARK")
                .font(.system(size: 15, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MoveMark")
    }

    /// Slim, glass, tappable: segments show rooms, the line says it in words.
    private var coveragePill: some View {
        Button(action: onOpenRental) {
            HStack(spacing: 12) {
                Image(systemName: model.totalRooms > 0 && model.documented == model.totalRooms ? "house.fill" : "house")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Light.accent)
                VStack(alignment: .leading, spacing: 6) {
                    if model.totalRooms > 0 {
                        segments
                    }
                    Text(model.totalRooms == 0
                         ? "Add rooms to start documenting"
                         : "\(model.documented) of \(model.totalRooms) rooms documented")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.documented) of \(model.totalRooms) rooms documented. Open rental.")
    }

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(model.totalRooms, 12), id: \.self) { i in
                Capsule()
                    .fill(i < Int((Double(model.documented) / Double(max(model.totalRooms, 1)) * Double(min(model.totalRooms, 12))).rounded())
                          ? MoveMarkTheme.Light.accent
                          : Color.white.opacity(0.28))
                    .frame(width: model.totalRooms > 8 ? 12 : 22, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = model.errorMessage {
                errorRow(error).padding(.bottom, 18)
            }

            nextRoomBlock

            metrics
                .padding(.top, 22)

            if !model.recent.isEmpty {
                recentEvidence
                    .padding(.top, 30)
            }

            if !model.actions.isEmpty {
                nextActions
                    .padding(.top, 30)
            }

            if !model.otherRentals.isEmpty {
                otherRentals
                    .padding(.top, 30)
            }

            MMSignedInScrollTailSpacer(kind: .rootTab)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: MoveMarkTheme.Light.sheetRadius,
                topTrailingRadius: MoveMarkTheme.Light.sheetRadius,
                style: .continuous
            )
            .fill(MoveMarkTheme.Light.surface)
            .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
        )
    }

    private var nextRoomBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let name = model.nextRoomName {
                Button(action: onPrimary) {
                    HStack(spacing: 16) {
                        RoomGlyph(name: name)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next room")
                                .font(.system(size: 14))
                                .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                            Text(name)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Light.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if model.totalRooms > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(MoveMarkTheme.Light.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Every room documented")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                        Text("Your move-in proof is complete.")
                            .font(.system(size: 15))
                            .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                    }
                }
            }

            // The one green action on the screen.
            Button(action: onPrimary) {
                Label(model.primaryTitle, systemImage: model.nextRoomName != nil ? "camera.fill" : "arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Light.onAccent)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .padding(.horizontal, 12)
                    .background(MoveMarkTheme.Light.accent, in: Capsule())
                    .shadow(color: MoveMarkTheme.Light.accent.opacity(0.25), radius: 10, y: 4)
            }
            .buttonStyle(ProofPressStyle())
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric(icon: "camera", value: model.photos, label: model.photos == 1 ? "Photo" : "Photos")
            divider
            metric(icon: "doc.text", value: model.records, label: model.records == 1 ? "Record" : "Records")
            divider
            metric(icon: "exclamationmark.triangle", value: model.issues, label: model.issues == 1 ? "Issue" : "Issues",
                   tint: model.issues > 0 ? MoveMarkTheme.Light.attention : MoveMarkTheme.Light.textPrimary)
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle().fill(MoveMarkTheme.Light.hairline).frame(width: 1, height: 36)
    }

    private func metric(icon: String, value: Int, label: String, tint: Color = MoveMarkTheme.Light.textPrimary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(MoveMarkTheme.Light.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var recentEvidence: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Recent evidence", trailing: "View all", action: onOpenRental)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.recent) { item in
                        Button { onOpenRoom(item.id) } label: {
                            RecentTile(item: item, resolvePhotoURL: resolvePhotoURL)
                        }
                        .buttonStyle(ProofPressStyle())
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var nextActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Next actions")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(model.actions) { action in
                    Button { onAction(action) } label: { ActionTile(action: action) }
                        .buttonStyle(ProofPressStyle())
                }
            }
        }
    }

    private var otherRentals: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Other rentals")
            VStack(spacing: 0) {
                ForEach(Array(model.otherRentals.enumerated()), id: \.element.id) { index, rental in
                    if index > 0 { Rectangle().fill(MoveMarkTheme.Light.hairline).frame(height: 1).padding(.leading, 16) }
                    Button { onOpenOtherRental(rental.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rental.name).font(.system(size: 16, weight: .medium)).foregroundStyle(MoveMarkTheme.Light.textPrimary)
                                Text(rental.status).font(.system(size: 13)).foregroundStyle(MoveMarkTheme.Light.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(MoveMarkTheme.Light.textTertiary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(MoveMarkTheme.Light.background, in: RoundedRectangle(cornerRadius: MoveMarkTheme.Light.tileRadius, style: .continuous))
        }
    }

    private func sectionHeader(_ title: String, trailing: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(trailing)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                }
            }
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
            Text(message).font(.system(size: 15)).foregroundStyle(MoveMarkTheme.Light.textPrimary)
            Spacer(minLength: 8)
            Button(MMCopy.tryAgain, action: onRetry).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
        }
        .padding(14)
        .background(MoveMarkTheme.Light.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Pieces

private struct HeroPhoto: View {
    let path: String
    let resolvePhotoURL: (String) async -> URL?
    @State private var url: URL?

    var body: some View {
        MMCachedAsyncImage(path: path, signedURL: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default: Color(red: 0.30, green: 0.33, blue: 0.32)
            }
        }
        .task(id: path) { url = await resolvePhotoURL(path) }
    }
}

/// Next room has no photo yet (that's why it's next), so it gets a quiet glyph for its kind.
private struct RoomGlyph: View {
    let name: String

    private var symbol: String {
        let n = name.lowercased()
        if n.contains("bed") { return "bed.double" }
        if n.contains("kitchen") { return "fork.knife" }
        if n.contains("bath") || n.contains("ensuite") || n.contains("washroom") { return "shower" }
        if n.contains("living") || n.contains("family") || n.contains("lounge") { return "sofa" }
        if n.contains("balcony") || n.contains("patio") || n.contains("terrace") { return "sun.max" }
        if n.contains("laundry") { return "washer" }
        if n.contains("office") || n.contains("study") { return "desktopcomputer" }
        if n.contains("dining") { return "fork.knife" }
        return "door.left.hand.open"
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .regular))
            .foregroundStyle(MoveMarkTheme.Light.textPrimary.opacity(0.75))
            .frame(width: 72, height: 72)
            .background(MoveMarkTheme.Light.fill, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct RecentTile: View {
    let item: ProofHomeModel.Recent
    let resolvePhotoURL: (String) async -> URL?
    @State private var url: URL?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MMCachedAsyncImage(path: item.photoPath, signedURL: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: MoveMarkTheme.Light.fill
                }
            }
            .frame(width: 156, height: 156)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)

            HStack(spacing: 4) {
                Text(item.roomName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "camera").font(.system(size: 11, weight: .semibold))
                Text("\(item.photoCount)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
        }
        .frame(width: 156, height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: item.photoPath) { url = await resolvePhotoURL(item.photoPath) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.roomName), \(item.photoCount) photos")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ActionTile: View {
    let action: ProofHomeModel.Action

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: action.icon)
                .font(.system(size: 20))
                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(action.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if action.needed {
                        Circle().fill(MoveMarkTheme.Light.attention).frame(width: 6, height: 6)
                            .accessibilityLabel("Needed")
                    }
                }
                Text(action.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(MoveMarkTheme.Light.surface, in: RoundedRectangle(cornerRadius: MoveMarkTheme.Light.tileRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoveMarkTheme.Light.tileRadius, style: .continuous)
                .strokeBorder(MoveMarkTheme.Light.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

private struct ProofPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
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
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Light.accent)
                        Text("MOVEMARK").font(.system(size: 15, weight: .semibold)).tracking(2.2).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 70)
                }
                .frame(height: 340)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Prove what was already there.")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Add your rental, then photograph each room before you unpack. MoveMark keeps it as a dated record.")
                        .font(.system(size: 17))
                        .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                    if let errorMessage {
                        HStack {
                            Text(errorMessage).font(.system(size: 15)).foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
                            Spacer()
                            Button(MMCopy.tryAgain, action: onRetry).font(.system(size: 15, weight: .semibold))
                        }
                    }
                    Button(action: onStart) {
                        Label("Add your rental", systemImage: "plus")
                            .font(.system(size: 17, weight: .semibold))
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
