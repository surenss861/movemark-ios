//
//  MMProofListRow.swift
//  movemork
//

import SwiftUI

struct MMProofListRow: View {
    enum Style {
        case standard
        case settings
    }

    let title: String
    let subtitle: String
    var meta: String? = nil
    var style: Style = .standard
    let onTap: () -> Void

    var body: some View {
        CompactProofRow(
            title: title,
            subtitle: subtitle,
            meta: meta,
            style: style == .settings ? .settings : .standard,
            onTap: onTap
        )
    }
}
