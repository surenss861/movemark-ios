//
//  PropertyStore+Workflow.swift
//  movemork
//
//  Workflow / readiness: hero line, cards, export, dispute draft.
//

import Foundation

extension PropertyStore {

    static let requiredVaultDocumentTypes: [VaultDocumentType] = [
        .lease, .depositReceipt, .listingScreenshot, .cleaningReceipt, .utilityProof, .moveOutInvoice, .other
    ]

    static let moveInRequiredDocumentTypes: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot]

    enum PropertyNextAction: Equatable {
        case captureRoom(roomID: UUID, roomName: String)
        case uploadDocument(VaultDocumentType)
        case reviewMaintenance(issueCount: Int)
        case openDisputeBuilder
        case openExports
        case reviewVault

        var title: String {
            switch self {
            case .captureRoom(_, let roomName):
                return "Next: \(roomName)"
            case .uploadDocument(let type):
                return "Add \(type.displayTitle)"
            case .reviewMaintenance(let issueCount):
                return issueCount == 1 ? "Review 1 issue" : "Review \(issueCount) issues"
            case .openDisputeBuilder:
                return "Open dispute builder"
            case .openExports:
                return "Make your move-in report"
            case .reviewVault:
                return "Review vault"
            }
        }

        var shortCTA: String {
            switch self {
            case .captureRoom:
                return "Finish move-in proof"
            case .uploadDocument:
                return "Add docs"
            case .reviewMaintenance:
                return "Review issues"
            case .openDisputeBuilder:
                return "Open dispute"
            case .openExports:
                return "Make your move-in report"
            case .reviewVault:
                return "Open"
            }
        }
    }

    var totalEvidenceCount: Int {
        currentProperty?.rooms.reduce(0) { partial, room in
            partial + room.evidence.count + room.moveOutEvidence.count
        } ?? 0
    }

    var totalPhotoCount: Int {
        currentProperty?.rooms.reduce(0) { partial, room in
            partial
            + room.evidence.reduce(0) { $0 + $1.photoCount }
            + room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }
        } ?? 0
    }

    func updateDisputeDraft(type: DisputeDraft.DisputeType? = nil, summary: String? = nil) {
        var draft = disputeDraft
        if let type { draft.type = type }
        if let summary { draft.summary = summary }
        draft.selectedEvidenceCount = totalEvidenceCount
        draft.selectedDocumentCount = currentProperty?.vaultDocuments.count ?? 0
        disputeDraft = draft
    }

    var readinessLabel: String {
        guard let property = currentProperty else { return "No property" }
        let roomCount = property.rooms.count
        let evidenceCount = totalEvidenceCount

        if roomCount == 0 { return "Setup needed" }
        if evidenceCount == 0 { return "Start capture" }
        if evidenceCount < roomCount { return "In progress" }
        return "Proof saved"
    }

    func totalRoomCount(for property: PropertyRecord) -> Int {
        property.rooms.count
    }

    func documentedRoomCount(for property: PropertyRecord) -> Int {
        property.rooms.filter { roomHasMoveInPhotos($0) }.count
    }

    func nextRoomToCapture(for property: PropertyRecord) -> RoomRecord? {
        property.rooms.first(where: { !roomHasMoveInPhotos($0) }) ?? property.rooms.first
    }

    private func roomHasMoveInPhotos(_ room: RoomRecord) -> Bool {
        room.evidence.contains { $0.photoCount > 0 }
    }

    func totalPhotoCount(for property: PropertyRecord) -> Int {
        property.rooms.reduce(0) { partial, room in
            partial + room.evidence.reduce(0) { $0 + $1.photoCount }
        }
    }

    func moveOutPhotoCount(for property: PropertyRecord) -> Int {
        property.rooms.reduce(0) { partial, room in
            partial + room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }
        }
    }

    func moveOutDocumentedRoomCount(for property: PropertyRecord) -> Int {
        property.rooms.filter { room in
            room.moveOutEvidence.contains { $0.photoCount > 0 }
        }.count
    }

    func totalIssueTagCount(for property: PropertyRecord) -> Int {
        property.rooms.reduce(0) { partial, room in
            partial + room.evidence.flatMap(\.issueTags).count
        }
    }

    /// Returns the count of non-resolved maintenance issues for the given property.
    /// **Limitation:** Only the currently active (hydrated) property returns a live count.
    /// Non-active properties always return 0 because the maintenance log is only loaded
    /// for `currentProperty`. Callers should not rely on this for non-active properties.
    /// Open maintenance issues for **this** property — but only when it is the **active** hydrated vault.
    /// Non-active properties always return `0` (we do not load `maintenanceLog` for other vault cards).
    func openIssueCount(for property: PropertyRecord) -> Int {
        if currentProperty?.id == property.id {
            return maintenanceLog.filter { $0.status != .resolved }.count
        }
        return 0
    }

    func uploadedSupportingRecordCount(for property: PropertyRecord) -> Int {
        let uploaded = Set(property.vaultDocuments)
        return Self.moveInRequiredDocumentTypes.filter { type in
            DocumentRepository.documentTypeQueryKeys(type.rawValue).contains { uploaded.contains($0) }
        }.count
    }

    func missingSupportingRecordCount(for property: PropertyRecord) -> Int {
        max(Self.moveInRequiredDocumentTypes.count - uploadedSupportingRecordCount(for: property), 0)
    }

    func roomsCompletionProgress(for property: PropertyRecord) -> Double {
        let total = totalRoomCount(for: property)
        guard total > 0 else { return 0 }
        return Double(documentedRoomCount(for: property)) / Double(total)
    }

    func readinessScore(for property: PropertyRecord) -> Int {
        let documentedRooms = documentedRoomCount(for: property)
        let totalRooms = totalRoomCount(for: property)
        let openIssues = openIssueCount(for: property)

        let roomScore: Double = {
            guard totalRooms > 0 else { return 0 }
            return Double(documentedRooms) / Double(totalRooms) * 70
        }()

        let documentScore: Double = {
            let totalDocs = Self.moveInRequiredDocumentTypes.count
            guard totalDocs > 0 else { return 0 }
            let uploaded = uploadedSupportingRecordCount(for: property)
            return Double(uploaded) / Double(totalDocs) * 20
        }()

        let maintenancePenalty: Double = min(Double(openIssues) * 4, 10)
        let raw = roomScore + documentScore + 10 - maintenancePenalty
        return max(0, min(Int(raw.rounded()), 100))
    }

    func isExportReady(for property: PropertyRecord) -> Bool {
        documentedRoomCount(for: property) > 0 && missingSupportingRecordCount(for: property) <= 2
    }

    func primaryNextAction(for property: PropertyRecord) -> PropertyNextAction {
        if let room = nextRoomToCapture(for: property), !roomHasMoveInPhotos(room) {
            return .captureRoom(roomID: room.id, roomName: room.name)
        }
        if let missingDoc = Self.moveInRequiredDocumentTypes.first(where: { type in
            !DocumentRepository.documentTypeQueryKeys(type.rawValue).contains { property.vaultDocuments.contains($0) }
        }) {
            return .uploadDocument(missingDoc)
        }
        let issues = openIssueCount(for: property)
        if issues > 0 {
            return .reviewMaintenance(issueCount: issues)
        }
        if isExportReady(for: property) {
            return .openExports
        }
        return .reviewVault
    }

    func readinessSummaryLine(for property: PropertyRecord) -> String {
        let rooms = "\(documentedRoomCount(for: property))/\(totalRoomCount(for: property)) rooms"
        let issues = openIssueCount(for: property) == 1
            ? "1 open issue"
            : "\(openIssueCount(for: property)) open issues"
        let docsMissing = missingSupportingRecordCount(for: property)
        let docs = docsMissing == 0 ? "All docs uploaded" : "\(docsMissing) docs missing"
        return [rooms, issues, docs].joined(separator: " · ")
    }

    func heroStatusLine(for property: PropertyRecord) -> String {
        var parts: [String] = []
        parts.append("\(documentedRoomCount(for: property)) of \(totalRoomCount(for: property)) rooms ready")
        let missingDocs = missingSupportingRecordCount(for: property)
        if missingDocs > 0 {
            parts.append("\(missingDocs) docs missing")
        }
        return parts.joined(separator: " · ")
    }

    /// Main proof/workspace statement for the active vault card (tier 2 — not property identity).
    func proofWorkspaceHeadline(for property: PropertyRecord) -> String {
        let total = totalRoomCount(for: property)
        let documented = documentedRoomCount(for: property)

        if total == 0 {
            return "Add rooms to begin move-in proof"
        }
        if documented == 0 {
            return "Move-in proof not started"
        }
        if documented < total {
            return "Move-in proof in progress"
        }
        if missingSupportingRecordCount(for: property) > 0 {
            return "Rooms done · add receipts & lease docs"
        }
        let issues = openIssueCount(for: property)
        if issues > 0 {
            return issues == 1 ? "1 open maintenance issue" : "\(issues) open maintenance issues"
        }
        if isExportReady(for: property) {
            return "Damage recorded — report ready when you need it"
        }
        return "Your move-in proof looks strong"
    }

    /// Short proof metrics for the active card (photos + room progress).
    func compactProofMetricsLine(for property: PropertyRecord) -> String {
        let photos = totalPhotoCount(for: property)
        let doc = documentedRoomCount(for: property)
        let total = totalRoomCount(for: property)
        var parts: [String] = []
        if total > 0 {
            parts.append("\(doc)/\(total) rooms with proof")
        }
        if photos > 0 {
            parts.append("\(photos) photos saved")
        }
        return parts.joined(separator: " · ")
    }
}
