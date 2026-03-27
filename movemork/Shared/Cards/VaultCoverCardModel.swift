//
//  VaultCoverCardModel.swift
//  movemork
//
//  Model for image-led editorial vault cover card. Keeps view logic clean.
//

import SwiftUI

struct VaultCoverCardModel: Identifiable, Equatable {
    let id: UUID
    let title: String
    let city: String
    let statusLine: String
    /// Active workspace: main proof-state line (e.g. walkthrough in progress).
    var workflowHeadline: String? = nil
    /// Active workspace: compact metrics under headline.
    var proofMetricsLine: String? = nil
    let nextAction: String?
    /// When set (featured), band shows this instead of generic "View" for a product-specific CTA.
    let ctaTitle: String?
    let chipText: String?
    let previewImageURL: URL?
    let fallbackStyle: VaultFallbackStyle
    let isRecent: Bool
    /// When true, subtle edge emphasis and stronger CTA for the recommended vault.
    let isEmphasized: Bool
}

enum VaultFallbackStyle: Equatable {
    case empty
    case started
    case ready
}
