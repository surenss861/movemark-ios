//
//  MMReportPreviewCard.swift
//  movemork
//
//  Thin wrapper — prefer MMReportHeroCard for new screens.
//

import SwiftUI

struct MMReportPreviewCard: View {
    typealias Status = MMReportCardStatus

    let title: String
    let metrics: String?
    var statusDetail: String? = nil
    let status: Status
    let primaryTitle: String
    let onPrimary: () -> Void
    var unlockPulse: Bool = false

    var body: some View {
        MMReportHeroCard(
            title: title,
            metrics: metrics,
            statusDetail: statusDetail,
            status: status,
            primaryTitle: primaryTitle,
            onPrimary: onPrimary,
            unlockPulse: unlockPulse
        )
    }
}
