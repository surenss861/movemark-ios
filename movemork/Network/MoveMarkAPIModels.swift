//
//  MoveMarkAPIModels.swift
//  movemork
//
//  JSON shapes for movemark-api vault, capabilities, and dispute catalog endpoints.
//

import Foundation

// MARK: - Vault summary (`GET /api/vaults/:propertyId/summary`)

struct VaultSummaryResponse: Codable {
    let property: VaultSummaryProperty
    let walkthrough: VaultWalkthrough
    let supportingRecords: VaultSupportingRecords
    let maintenance: VaultMaintenanceSummary
    let readiness: VaultReadinessBlock
    let exports: VaultExportsBlock?
    let dispute: VaultDisputeBlock?
    let updatedAt: String
}

struct VaultSummaryProperty: Codable {
    let id: String
    let nickname: String?
    let addressLine1: String
    let city: String?
    let region: String?
    let country: String?
    let moveInDate: String?
    let isCurrent: Bool
}

struct VaultWalkthrough: Codable {
    let totalRooms: Int
    let documentedRooms: Int
    let nextRoom: VaultNextRoom?
    let hasMoveOutStarted: Bool
    let moveOutDocumentedRooms: Int
}

struct VaultNextRoom: Codable {
    let roomId: String
    let name: String
}

struct VaultSupportingRecords: Codable {
    let requiredTotal: Int
    let uploadedRequired: Int
    let missingRequired: Int
    let uploadedTypes: [String]
    let missingTypes: [String]
}

struct VaultMaintenanceSummary: Codable {
    let openCount: Int
    let followUpCount: Int
    let resolvedCount: Int
}

struct VaultReadinessBlock: Codable {
    let score: Int
    let status: String
    let primaryNextAction: VaultPrimaryNextAction?
}

struct VaultPrimaryNextAction: Codable {
    let type: String
    let label: String
}

struct VaultExportsBlock: Codable {
    let moveInReportCount: Int
    let moveOutReportCount: Int
    let disputePacketCount: Int
    let latest: VaultExportLatest?
}

struct VaultExportLatest: Codable {
    let id: String
    let type: String
    let status: String
    let createdAt: String?
}

struct VaultDisputeBlock: Codable {
    let hasDraft: Bool
    let draftId: String?
    let selectedPhotoCount: Int
    let selectedIssueCount: Int
    let selectedDocumentCount: Int
}

// MARK: - Property capabilities (`GET /api/properties/:propertyId/capabilities`)

struct PropertyCapabilitiesResponse: Codable {
    let propertyId: String
    let subscription: PropertyCapabilitiesSubscription
    let exports: PropertyCapabilitiesExports
    let disputes: PropertyCapabilitiesDisputes
    let properties: PropertyCapabilitiesProperties
    let workflow: PropertyCapabilitiesWorkflow
    let updatedAt: String
}

struct PropertyCapabilitiesSubscription: Codable {
    let plan: String
    let isPro: Bool
}

struct PropertyCapabilitiesExports: Codable {
    let canExportMoveIn: Bool
    let canExportMoveOut: Bool
    let freeMoveInExportsRemaining: Int
    let reasonIfBlocked: String?
}

struct PropertyCapabilitiesDisputes: Codable {
    let canUseDisputeBuilder: Bool
    let canGenerateFormalPacket: Bool
    let reasonIfBlocked: String?
}

struct PropertyCapabilitiesProperties: Codable {
    let canCreateAnotherProperty: Bool
    let reasonIfBlocked: String?
}

struct PropertyCapabilitiesWorkflow: Codable {
    let canStartMoveInExportNow: Bool
    let canStartMoveOutExportNow: Bool
    let canOpenDisputeBuilderNow: Bool
}

// MARK: - Dispute evidence catalog (`GET /api/disputes/:propertyId/evidence-catalog`)

struct DisputeEvidenceCatalogResponse: Codable {
    let propertyId: String
    let roomPhotos: [DisputeRoomPhotoItem]
    /// Evidence files attached only to a maintenance issue (not walkthrough inspection items). Omitted by older API builds.
    let maintenancePhotos: [DisputeMaintenancePhotoItem]?
    let maintenanceIssues: [DisputeMaintenanceIssueItem]
    let documents: [DisputeDocumentItem]
    let summary: DisputeEvidenceCatalogSummary
    let updatedAt: String
}

struct DisputeMaintenancePhotoItem: Codable {
    let evidenceFileId: String
    let maintenanceIssueId: String
    let issueTitle: String
    let issueCategory: String?
    let capturedAt: String?
    let label: String
    let thumbnailUrl: String?
}

struct DisputeRoomPhotoItem: Codable {
    let evidenceFileId: String
    let inspectionItemId: String?
    let roomId: String?
    let roomName: String?
    let entryTitle: String?
    let stage: String
    let capturedAt: String?
    let label: String
    let thumbnailUrl: String?
    let tagNames: [String]
    let conditionRating: Int?
}

struct DisputeMaintenanceIssueItem: Codable {
    let issueId: String
    let title: String
    let category: String?
    let status: String
    let createdAt: String?
    let label: String
    let attachmentCount: Int
}

struct DisputeDocumentItem: Codable {
    let documentId: String
    let type: String
    let label: String
    let uploadedAt: String?
    let previewUrl: String?
}

struct DisputeEvidenceCatalogSummary: Codable {
    let photoCount: Int
    let maintenanceCount: Int
    let documentCount: Int
}
