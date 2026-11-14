//
//  ProofSavedReceiptView.swift
//  movemork
//
//  The receipt after every room save: proof recorded, preserved, official. States only what the backend
//  confirmed — confirmed photos, issues, the time it was saved — and what still needs a retry.
//
//  Composition: one receipt header (state, room, the confirmed facts on one ruled line), the saved photo by
//  itself (it takes the spare height, so the actions sit at the bottom without a dead zone), the preservation
//  lines as a quiet caption under the photo, then the actions: lime primary, an outlined secondary, a text
//  tertiary.
//

import SwiftUI

struct ProofSavedReceiptModel {
    var roomName: String
    var phaseLabel: String = "Move-in"
    /// Photos the backend confirmed saved.
    var photoCount: Int
    /// Photos that did not save and still need a retry.
    var pendingCount: Int = 0
    var issueCount: Int = 0
    var savedAt: Date
    /// True when `savedAt` is the server's `created_at` for the saved photos. False when only the device's clock
    /// at the backend's confirmation is known: the receipt then says "on this device" instead of presenting it
    /// as the server's record.
    var savedAtFromServer: Bool = true
    var imageURL: URL?
    var imageName: String?
    var primaryActionLabel: String
    var secondaryActionLabel: String = "View evidence"
    /// A teen account's photos are saved without location and identifying metadata (Option B); the receipt says so
    /// instead of "Source files preserved".
    var metadataRemovedForPrivacy: Bool = MMPhotoPrivacyPolicy.shared.current == .teen
}

struct ProofSavedReceiptView: View {
    let model: ProofSavedReceiptModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    var onAddMorePhotos: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The preservation glyphs grow with their caption text.
    @ScaledMetric(relativeTo: .footnote) private var assuranceIcon: CGFloat = 11
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }
    /// Large (non-AX) text: the facts stack instead of sharing one line.
    private var stacksFacts: Bool { dynamicTypeSize >= .xxxLarge }
    private var isPartial: Bool { model.pendingCount > 0 }

    private enum Ink {
        static let field = Color(red: 0.067, green: 0.075, blue: 0.071)          // #111312, the room screen's dark
        static let text = Color.white
        static let secondary = Color.white.opacity(0.62)
        static let tertiary = Color.white.opacity(0.5)
        static let rule = Color.white.opacity(0.12)
        static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)           // #CAE36C, as the Vault
        static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)
        static let warning = Color(red: 0.949, green: 0.737, blue: 0.341)
        static let photoFill = Color.white.opacity(0.06)
        static let outline = Color.white.opacity(0.22)
    }

    /// The photo's height range: it never shrinks below the receipt's locked size and grows into spare height.
    private var photoMinHeight: CGFloat { isAX ? 160 : 220 }
    private let photoMaxHeight: CGFloat = 400

    var body: some View {
        // One scroll view whose content is at least the screen tall: the photo takes the spare height (then the gap
        // above the actions), so the actions sit at the bottom with no dead zone. When it doesn't fit (small phone,
        // large text) it scrolls with the photo at its minimum height. One image instance, so it loads once.
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                content.frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .background(Ink.field.ignoresSafeArea())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The text blocks keep their full height; only the photo (then the gap above the actions) flexes.
            header.fixedSize(horizontal: false, vertical: true)
            photo.padding(.top, 22)
            assurances.fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            Spacer(minLength: 24)
            actions.fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: - What was recorded

    private var savedTime: String {
        model.savedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: isPartial ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isPartial ? Ink.warning : Ink.lime)
                Text(isPartial ? "PROOF PARTLY SAVED" : "PROOF SAVED")
                    .mmFont(12, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.secondary)
                Spacer(minLength: 8)
                Text(model.phaseLabel.uppercased())
                    .mmFont(12, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityLabel(model.phaseLabel)
            }
            .accessibilityElement(children: .combine)

            Text(model.roomName)
                .mmFont(32, .semibold)
                .foregroundStyle(Ink.text)
                .lineLimit(isAX ? 3 : 2)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 10)

            facts.padding(.top, 16)

            if isPartial {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("\(Self.count(model.pendingCount, "photo")) \(model.pendingCount == 1 ? "needs" : "need") a retry")
                        .mmFont(14.5, .medium)
                }
                .foregroundStyle(Ink.warning)
                .padding(.top, 10)
            }
        }
    }

    /// The confirmed facts on one ruled line, like a receipt: photos, issues (when any), the time it was saved.
    private var facts: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Ink.rule).frame(height: 0.5)
            Group {
                if stacksFacts {
                    VStack(alignment: .leading, spacing: 10) { factCells }
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 0) { factCells }
                }
            }
            .padding(.vertical, 12)
            Rectangle().fill(Ink.rule).frame(height: 0.5)
        }
    }

    @ViewBuilder private var factCells: some View {
        fact("Photos", "\(model.photoCount) saved", spoken: "\(Self.count(model.photoCount, "photo")) saved")
        if model.issueCount > 0 {
            fact("Issues", "\(model.issueCount) recorded", spoken: "\(Self.count(model.issueCount, "issue")) recorded")
        }
        if model.savedAtFromServer {
            fact("Saved", savedTime, spoken: "Saved \(savedTime)", grows: true)
        } else {
            fact("Confirmed", "\(savedTime) on this device", spoken: "Confirmed \(savedTime) on this device", grows: true)
        }
    }

    private func fact(_ label: String, _ value: String, spoken: String, grows: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .mmFont(11, .semibold)
                .tracking(0.6)
                .foregroundStyle(Ink.tertiary)
            Text(value)
                .mmFont(15.5, .medium)
                .foregroundStyle(Ink.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.trailing, stacksFacts ? 0 : 18)
        .frame(maxWidth: grows && !stacksFacts ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// One saved photo, by itself: no text over it. Display crop only (aspect fill); the viewer shows the original.
    private var photo: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(minHeight: photoMinHeight, maxHeight: photoMaxHeight)
            .overlay {
                Group {
                    if let imageName {
                        Image(imageName).resizable().scaledToFill()
                    } else if let url = model.imageURL {
                        MMCachedAsyncImage(path: nil, signedURL: url) { phase in
                            if case .success(let image) = phase { image.resizable().scaledToFill() } else { Ink.photoFill }
                        }
                    } else {
                        Ink.photoFill.overlay {
                            Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(Ink.secondary)
                        }
                    }
                }
            }
            // The aspect-filled photo overflows its frame; clipping doesn't trim hit testing, so it takes no touches.
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Ink.rule, lineWidth: 0.5))
            .layoutPriority(1)
            .accessibilityHidden(true)
    }

    private var imageName: String? { model.imageName }

    /// How the proof is kept: a quiet caption under the photo, not settings rows.
    private var assurances: some View {
        VStack(alignment: .leading, spacing: 5) {
            if model.metadataRemovedForPrivacy {
                assurance("location.slash", "Location and camera details removed for privacy")
            } else {
                assurance("lock.shield", "Source files preserved")
            }
            assurance("archivebox", "Recorded in your proof vault")
        }
        .padding(.horizontal, 2)
    }

    private func assurance(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: min(assuranceIcon, 22), weight: .medium))
                .frame(width: min(assuranceIcon, 22) + 3)
                .accessibilityHidden(true)
            Text(text).mmFont(13)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Ink.secondary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - What next

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onPrimary) {
                Text(model.primaryActionLabel)
                    .mmFont(16, .semibold)
                    .foregroundStyle(Ink.onLime)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .padding(.vertical, isAX ? 8 : 0)
                    .background(Ink.lime, in: Capsule())
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(MMLightPressStyle())

            // Secondary: outlined, so it reads as a real choice under the primary.
            Button(action: onSecondary) {
                Text(model.secondaryActionLabel)
                    .mmFont(15.5, .semibold)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.vertical, isAX ? 6 : 0)
                    .overlay(Capsule().strokeBorder(Ink.outline, lineWidth: 1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(MMLightPressStyle())

            // Tertiary: text only.
            if let onAddMorePhotos {
                Button(action: onAddMorePhotos) {
                    Text("Add more photos")
                        .mmFont(15, .medium)
                        .foregroundStyle(Ink.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -2)
            }
        }
    }

    static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(n == 1 ? noun : noun + "s")"
    }
}
