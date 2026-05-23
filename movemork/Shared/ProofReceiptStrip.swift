//
//  ProofReceiptStrip.swift
//  movemork
//

import SwiftUI

enum ProofReceiptStripLayout {
    case caseFile
    case stacked
    case horizontal
}

struct ProofReceiptStripModel {
    var savedTitle: String = "Saved to your vault"
    var detailTitle: String?
    var detailSubtitle: String?
    var timestampLabel: String?
    var metricsLine: String?
    var statusBadge: String?
    var statusTone: ProofStatusTone = .success
    var cardTitle: String?
    var cardMeta: String?
}

struct ProofReceiptStrip<Leading: View>: View {
    let model: ProofReceiptStripModel
    var layout: ProofReceiptStripLayout = .caseFile
    var leading: Leading

    init(
        model: ProofReceiptStripModel,
        layout: ProofReceiptStripLayout = .caseFile,
        @ViewBuilder leading: () -> Leading = { EmptyView() }
    ) {
        self.model = model
        self.layout = layout
        self.leading = leading()
    }

    var body: some View {
        switch layout {
        case .caseFile: caseFileBody
        case .stacked: stackedBody
        case .horizontal: horizontalBody
        }
    }

    private var caseFileBody: some View {
        VStack(spacing: 0) {
            if model.detailTitle != nil || model.detailSubtitle != nil {
                ProofCaseDetailSection(
                    title: model.detailTitle ?? "",
                    subtitle: model.detailSubtitle ?? model.metricsLine
                )
                ProofCaseDivider()
            }
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.savedTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    if let timestamp = model.timestampLabel {
                        Text(timestamp)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }
                }
                Spacer(minLength: 4)
                if let badge = model.statusBadge {
                    ProofStatusBadge(text: badge, tone: model.statusTone)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProofCaseDivider()
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                Text(model.savedTitle)
                    .font(.system(size: 15, weight: .bold))
                Spacer(minLength: 4)
                if let badge = model.statusBadge {
                    ProofStatusBadge(text: badge, tone: model.statusTone)
                }
            }
            .padding(.top, 10)
            if let timestamp = model.timestampLabel {
                Text(timestamp)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 9)
    }

    private var horizontalBody: some View {
        HStack(alignment: .center, spacing: 14) {
            leading
            VStack(alignment: .leading, spacing: 8) {
                if let title = model.cardTitle {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
                if let meta = model.cardMeta {
                    Text(meta)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

extension ProofReceiptStrip where Leading == EmptyView {
    init(model: ProofReceiptStripModel, layout: ProofReceiptStripLayout = .caseFile) {
        self.init(model: model, layout: layout) { EmptyView() }
    }
}
