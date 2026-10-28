//
//  EvidenceNewEntryHeader.swift
//  movemork
//
//  The new entry's label and photo count, with the one status line about where its photos are
//  (on this iPhone · uploading · failed).
//

import SwiftUI

struct EvidenceNewEntryHeader: View {
    let moveOutMode: Bool
    let photoCount: Int
    let syncState: MMEvidenceSyncState?
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(moveOutMode ? "New move-out entry" : "New entry")
                    .font(MoveMarkTheme.Typography.kicker)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                Spacer()
                if photoCount > 0 {
                    Text(photoCount == 1 ? "1 photo" : "\(photoCount) photos")
                        .font(MoveMarkTheme.Typography.monoMeta)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
            if let syncState {
                MMEvidenceSyncStatusLine(state: syncState, onRetry: onRetry)
            }
        }
    }
}
