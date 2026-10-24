//
//  ProofSavedReceiptView.swift
//  movemork
//
//  The receipt after every room save: proof recorded, preserved, official. States only what the backend
//  confirmed — confirmed photos, issues, the time it was saved — and what still needs a retry.
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
    var imageURL: URL?
    var imageName: String?
    var primaryActionLabel: String
    var secondaryActionLabel: String = "View evidence"
}

struct ProofSavedReceiptView: View {
    let model: ProofSavedReceiptModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    var onAddMorePhotos: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }
    private var isPartial: Bool { model.pendingCount > 0 }

    private enum Ink {
        static let field = Color(red: 0.067, green: 0.075, blue: 0.071)          // #111312, the room screen's dark
        static let text = Color.white
        static let secondary = Color.white.opacity(0.62)
        static let rule = Color.white.opacity(0.12)
        static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)           // #CAE36C, as the Vault
        static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)
        static let warning = Color(red: 0.949, green: 0.737, blue: 0.341)
        static let photoFill = Color.white.opacity(0.06)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                photo.padding(.top, 24)
                assurances.padding(.top, 20)
                actions.padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 32)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .background(Ink.field.ignoresSafeArea())
    }

    // MARK: - What was recorded

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isPartial ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isPartial ? Ink.warning : Ink.lime)
                Text(isPartial ? "PROOF PARTLY SAVED" : "PROOF SAVED")
                    .mmFont(12, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.secondary)
            }
            .accessibilityElement(children: .combine)
            Text(model.roomName)
                .mmFont(32, .semibold)
                .foregroundStyle(Ink.text)
                .lineLimit(isAX ? 3 : 2)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Self.count(model.photoCount, "photo")) saved")
                if isPartial {
                    Text("\(Self.count(model.pendingCount, "photo")) \(model.pendingCount == 1 ? "needs" : "need") a retry")
                        .foregroundStyle(Ink.warning)
                }
                if model.issueCount > 0 {
                    Text("\(Self.count(model.issueCount, "issue")) recorded")
                }
            }
            .mmFont(16, .medium)
            .foregroundStyle(Ink.text)
            .padding(.top, 10)
            Text("\(model.phaseLabel) · \(model.savedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                .mmFont(14)
                .foregroundStyle(Ink.secondary)
                .padding(.top, 8)
        }
    }

    /// One saved photo, by itself: no text over it.
    private var photo: some View {
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
        .frame(maxWidth: .infinity)
        .frame(height: isAX ? 160 : 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }

    private var imageName: String? { model.imageName }

    private var assurances: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Ink.rule).frame(height: 1)
            assurance("lock.shield", "Source files preserved")
            assurance("archivebox", "Added to your proof vault")
            Rectangle().fill(Ink.rule).frame(height: 1)
        }
    }

    private func assurance(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .regular)).frame(width: 20)
            Text(text).mmFont(14.5)
        }
        .foregroundStyle(Ink.text.opacity(0.85))
        .accessibilityElement(children: .combine)
    }

    // MARK: - What next

    private var actions: some View {
        VStack(spacing: 4) {
            Button(action: onPrimary) {
                Text(model.primaryActionLabel)
                    .mmFont(16, .semibold)
                    .foregroundStyle(Ink.onLime)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .padding(.vertical, isAX ? 8 : 0)
                    .background(Ink.lime, in: Capsule())
            }
            .buttonStyle(MMLightPressStyle())
            quietButton(model.secondaryActionLabel, action: onSecondary).padding(.top, 8)
            if let onAddMorePhotos { quietButton("Add more photos", action: onAddMorePhotos) }
        }
    }

    private func quietButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .mmFont(15, .medium)
                .foregroundStyle(Ink.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(n == 1 ? noun : noun + "s")"
    }
}
