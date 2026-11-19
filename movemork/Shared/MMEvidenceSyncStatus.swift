//
//  MMEvidenceSyncStatus.swift
//  movemork
//
//  MoveMark — one factual line about where a room's new photos are: on this iPhone, uploading, or
//  failed. Existing tokens only (MMInk, mmFont, MMEvidenceNotice colours); no new visual concept.
//

import SwiftUI

/// Where the room's unsaved photos stand.
enum MMEvidenceSyncState: Equatable {
    /// Written to this iPhone; not sent yet.
    case savedLocally
    /// A save is sending this many photos.
    case uploading(count: Int)
    /// The last attempt didn't confirm them.
    case failed

    var message: String {
        switch self {
        case .savedLocally: return "Saved on this iPhone · not uploaded yet"
        case .uploading(let count): return count == 1 ? "Uploading 1 photo…" : "Uploading \(count) photos…"
        case .failed: return "Upload failed —"
        }
    }
}

/// The room screen's status line, under the new entry's header (dark evidence surface).
struct MMEvidenceSyncStatusLine: View {
    let state: MMEvidenceSyncState
    var onRetry: (() -> Void)? = nil
    @Environment(\.mmEvidenceOnLight) private var onLight

    private var quiet: Color { onLight ? MMInk.secondary : MMInk.heroSecondary }
    private var strong: Color { onLight ? MMInk.text : .white }

    private var icon: (String, Color) {
        switch state {
        case .savedLocally: ("iphone", quiet)
        case .uploading: ("arrow.up.circle", quiet)
        case .failed: ("exclamationmark.circle.fill", onLight ? MMEvidenceNotice.dangerOnLight : MMEvidenceNotice.dangerOnDark)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon.0)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(icon.1)
                .accessibilityHidden(true)
            Text(state.message)
                .mmFont(13, .medium)
                .foregroundStyle(state == .failed ? strong : quiet)
                .fixedSize(horizontal: false, vertical: true)
            if state == .failed, let onRetry {
                Button(action: onRetry) {
                    Text("Retry")
                        .mmFont(13, .semibold)
                        .foregroundStyle(strong)
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -14)   // 44pt target without growing the line
                .accessibilityLabel("Retry upload")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("evidence.syncStatus")
        .animation(MMMotion.fastFade, value: state)
    }
}

/// The Proof root's quiet row while any room still has photos only on this iPhone. Sits on the dark header.
struct MMPendingUploadsRow: View {
    let count: Int
    let failed: Bool
    let onOpen: () -> Void

    private var title: String {
        count == 1 ? "1 photo not uploaded yet" : "\(count) photos not uploaded yet"
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Image(systemName: failed ? "exclamationmark.circle.fill" : "iphone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(failed ? MMEvidenceNotice.dangerOnDark : MMInk.heroSecondary)
                    .accessibilityHidden(true)
                Text(title)
                    .mmFont(14, .medium)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MMInk.heroSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MMMetrics.inset)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(MMInk.hero.ignoresSafeArea(edges: .horizontal))
        .accessibilityHint("Opens the room")
        .accessibilityIdentifier("proof.pendingUploads")
    }
}

extension View {
    /// The Proof root's pending row, above the screen's content while `count` > 0.
    func mmPendingUploads(count: Int, failed: Bool, onOpen: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            if count > 0 {
                MMPendingUploadsRow(count: count, failed: failed, onOpen: onOpen)
                    .transition(.opacity)
            }
        }
        .animation(MMMotion.fastFade, value: count)
    }
}
