//
//  DisputePacketContent.swift
//  movemork
//
//  @file The evidence packet builder, presentational: DISPUTE PACKET header → what is being questioned → evidence
//        included (rooms involved as the locked Move-out spreads, then records MoveMark already holds) → missing
//        proof → packet contents → one action. Assembled from the rental's recorded evidence; nothing re-entered.
//

import SwiftUI

/// Everything the packet screen shows, derived from the rental and its exports.
struct DisputePacketModel {
    enum Packet: Equatable {
        case needsMoveInProof
        case ready
        case generating
        case generated(date: String)
        case failed
    }

    struct Record: Identifiable, Equatable {
        let id: String
        let title: String
        let icon: String
        let detail: String
    }

    struct Missing: Identifiable, Equatable {
        enum Target: Equatable { case rentalRecord, moveOut, rooms, reports }
        let id: String
        let title: String
        let detail: String
        let target: Target
    }

    let title: String
    let rooms: [RoomRecord]
    let selectedRoomIDs: Set<UUID>
    let records: [Record]
    let missing: [Missing]
    let moveInPhotos: Int
    let moveOutPhotos: Int
    let documents: Int
    let issues: Int
    let moveInReportIncluded: Bool
    let packet: Packet
    let hasPro: Bool

    /// Rooms with any proof can be named as involved; a room with nothing recorded adds nothing to a packet.
    var selectableRooms: [RoomRecord] {
        rooms.filter { MMRoomProofMetrics.photoCount(for: $0) > 0 || !$0.moveOutEvidence.isEmpty }
    }

    var involved: [MoveOutComparison] {
        selectableRooms.filter { selectedRoomIDs.contains($0.id) }.map(MoveOutComparison.make(room:))
    }

    var statusLine: String {
        switch packet {
        case .needsMoveInProof: "Needs move-in proof"
        case .ready, .failed: "Ready to generate"
        case .generating: "Generating"
        case .generated(let date): "Generated \(date)"
        }
    }

    /// "8 move-in photos · 3 move-out photos · 2 documents · 1 recorded issue" — the counts the PDF states.
    var contentLines: [String] {
        func n(_ count: Int, _ one: String, _ many: String) -> String { "\(count) \(count == 1 ? one : many)" }
        var lines = [
            n(moveInPhotos, "move-in photo", "move-in photos"),
            n(moveOutPhotos, "move-out photo", "move-out photos"),
            n(documents, "document", "documents"),
            n(issues, "recorded issue", "recorded issues"),
        ]
        lines.append(moveInReportIncluded ? "Move-in report included" : "Move-in report not attached")
        lines.append("Dated timeline of the rental")
        return lines
    }

    // MARK: Building from the rental

    static func make(property: PropertyRecord, maintenance: [MaintenanceRecord], exports: [ExportRow],
                     readyIDs: Set<UUID>, activeIDs: Set<UUID>, failedIDs: Set<UUID>,
                     selectedRoomIDs: Set<UUID>, hasPro: Bool) -> DisputePacketModel {
        let rooms = property.rooms
        let moveInPhotos = rooms.reduce(0) { $0 + MMRoomProofMetrics.photoCount(for: $1) }
        let moveOutPhotos = rooms.reduce(0) { total, room in total + room.moveOutEvidence.reduce(0) { $0 + $1.photoCount } }
        let documentTypes: [(VaultDocumentType, String, String)] = [
            (.lease, "Lease agreement", "Ties the packet to this rental."),
            (.depositReceipt, "Deposit receipt", "Shows what you paid, and when."),
            (.listingScreenshot, "Listing proof", "Shows how the rental was advertised."),
        ]

        func ready(_ type: String) -> ExportRow? {
            exports.filter { $0.exportType == type && readyIDs.contains($0.id) }.max { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        }
        let moveInReport = ready("move_in_report")
        let moveOutReport = ready("move_out_report")

        var records: [Record] = []
        var missing: [Missing] = []
        if let moveInReport {
            records.append(.init(id: "moveInReport", title: "Move-in report", icon: "doc.richtext",
                                 detail: Self.day(moveInReport.createdAt).map { "Generated \($0) · PDF" } ?? "PDF ready"))
        } else if moveInPhotos > 0 {
            missing.append(.init(id: "moveInReport", title: "Move-in report not generated",
                                 detail: "The packet lists your room proof; the report attaches it as a PDF.", target: .reports))
        }
        if let moveOutReport {
            records.append(.init(id: "moveOutReport", title: "Move-out report", icon: "doc.richtext",
                                 detail: Self.day(moveOutReport.createdAt).map { "Generated \($0) · PDF" } ?? "PDF ready"))
        }
        if moveOutPhotos == 0 {
            missing.append(.init(id: "moveOut", title: "Move-out proof not recorded",
                                 detail: "Photograph each room before you return the keys.", target: .moveOut))
        }
        var documents = 0
        for (type, title, reason) in documentTypes {
            if ProofSprint.isDocumentUploaded(type, in: property) {
                documents += 1
                records.append(.init(id: type.rawValue, title: title, icon: PropertyVaultContent.recordIcon(type),
                                     detail: "On your rental record"))
            } else if type != .listingScreenshot {
                missing.append(.init(id: type.rawValue, title: "\(title) not added", detail: reason, target: .rentalRecord))
            }
        }
        if !maintenance.isEmpty {
            let open = maintenance.filter { $0.status != .resolved }.count
            let cases = maintenance.count == 1 ? "1 case recorded" : "\(maintenance.count) cases recorded"
            records.append(.init(id: "maintenance", title: "Maintenance log", icon: "wrench.and.screwdriver",
                                 detail: open == 0 ? "\(cases) · all resolved" : "\(cases) · \(open) open"))
        }
        if moveInPhotos == 0 {
            missing.insert(.init(id: "moveInProof", title: "Move-in proof not recorded",
                                 detail: "A packet starts from the condition you moved into.", target: .rooms), at: 0)
        }

        let issueTags = Set(rooms.flatMap { room in (room.evidence + room.moveOutEvidence).flatMap { $0.issueTags } })
        let packets = exports.filter { $0.exportType == "dispute_packet" || $0.exportType == "dispute_summary" }
        let packet: Packet
        if moveInPhotos == 0 && moveInReport == nil {
            packet = .needsMoveInProof
        } else if packets.contains(where: { activeIDs.contains($0.id) }) {
            packet = .generating
        } else if let done = packets.filter({ readyIDs.contains($0.id) }).max(by: { ($0.createdAt ?? "") < ($1.createdAt ?? "") }) {
            packet = .generated(date: Self.day(done.createdAt) ?? "")
        } else if packets.contains(where: { failedIDs.contains($0.id) }) {
            packet = .failed
        } else {
            packet = .ready
        }

        return DisputePacketModel(
            title: PropertyVaultModel.displayTitle(for: property), rooms: rooms, selectedRoomIDs: selectedRoomIDs,
            records: records, missing: missing, moveInPhotos: moveInPhotos, moveOutPhotos: moveOutPhotos,
            documents: documents, issues: issueTags.count + maintenance.count,
            moveInReportIncluded: moveInReport != nil, packet: packet, hasPro: hasPro
        )
    }

    private static func day(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parsers: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
            return [a, b]
        }()
        guard let date = parsers.lazy.compactMap({ $0.date(from: iso) }).first else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct DisputePacketContent: View {
    let model: DisputePacketModel
    @Binding var question: String
    @Binding var amount: String
    var resolve: (String) async -> URL? = { _ in nil }
    var errorMessage: String? = nil
    var isDownloading = false
    var onToggleRoom: (UUID) -> Void = { _ in }
    var onOpenPhoto: (MoveOutComparison, MoveOutSide) -> Void = { _, _ in }
    var onCaptureMoveOut: (UUID) -> Void = { _ in }
    var onMissing: (DisputePacketModel.Missing.Target) -> Void = { _ in }
    var onGenerate: () -> Void = {}
    var onView: () -> Void = {}
    var onShare: () -> Void = {}
    var onRetry: () -> Void = {}

    var body: some View {
        MMRecordScreen(
            eyebrow: "Dispute packet",
            title: model.title,
            lines: ["Build a record of the evidence related to this issue."],
            headerExtra: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(isReadyState ? MMInk.limeMark : MMInk.heroSecondary.opacity(0.6))
                        .frame(width: 7, height: 7)
                    Text(model.statusLine).mmFont(12.5, .medium).foregroundStyle(.white)
                }
                .padding(.top, 18)
                .accessibilityElement(children: .combine)
            }
        ) {
            VStack(alignment: .leading, spacing: 32) {
                if let errorMessage {
                    MMNotice(message: errorMessage, tone: .info, actionTitle: MMCopy.tryAgain, action: onRetry)
                }
                questionSection
                evidenceSection
                if !model.missing.isEmpty { missingSection }
                contentsSection
                actionSection
            }
        }
    }

    private var isReadyState: Bool {
        switch model.packet {
        case .ready, .generated: true
        default: false
        }
    }

    // MARK: What is being questioned

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMRecordSectionHeader(title: "What is being questioned")
            MMField(title: "Issue", placeholder: "e.g. Deduction for the kitchen counter", text: $question,
                    autocapitalization: .sentences, submitLabel: .next)
            MMField(title: "Amount questioned (optional)", placeholder: "e.g. $350", text: $amount,
                    keyboard: .numbersAndPunctuation, autocapitalization: .never)
            Text("Kept with this packet on this iPhone, to keep the evidence focused.")
                .mmFont(13)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 2)
        }
    }

    // MARK: Evidence included

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMRecordSectionHeader(title: "Evidence included")
            if !model.selectableRooms.isEmpty {
                Text("Rooms involved").mmFont(13, .medium).foregroundStyle(MMInk.secondary).padding(.leading, 2)
                FlowLayout(spacing: 8) {
                    ForEach(model.selectableRooms) { room in
                        MMChip(title: room.name, isSelected: model.selectedRoomIDs.contains(room.id)) { onToggleRoom(room.id) }
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Rooms involved")

                // The locked Move-out grammar, unchanged: spreads for differences, the missing side as a card,
                // unchanged rooms compact.
                ForEach(model.involved) { item in
                    switch item.state {
                    case .changed, .newIssue:
                        MoveOutSpreadCard(comparison: item, resolve: resolve, onOpenPhoto: { onOpenPhoto(item, $0) })
                    case .missing:
                        MoveOutMissingCard(comparison: item, resolve: resolve, isPrimary: false,
                                           onOpenPhoto: { onOpenPhoto(item, $0) }, onCapture: { onCaptureMoveOut(item.id) })
                    case .unchanged, .noBaseline:
                        MoveOutCompactRow(comparison: item, resolve: resolve, onOpenPhoto: { onOpenPhoto(item, $0) })
                            .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous)
                                .strokeBorder(MMInk.cardStroke, lineWidth: 1))
                    }
                }
            }

            if !model.records.isEmpty {
                MMGroup {
                    ForEach(Array(model.records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 { MMRowDivider(leading: 52) }
                        includedRow(record)
                    }
                }
                .padding(.top, model.involved.isEmpty ? 0 : 4)
            }
        }
    }

    /// A record already on file, in the rental record's row geometry: icon, title, what it is, a quiet check.
    private func includedRow(_ record: DisputePacketModel.Record) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(MMInk.text.opacity(0.8))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).mmFont(16).foregroundStyle(MMInk.text)
                Text(record.detail).mmFont(13).foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MMInk.text.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight + 6, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Included")
    }

    // MARK: Missing proof

    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMRecordSectionHeader(title: "Missing proof")
            MMGroup {
                ForEach(Array(model.missing.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { MMRowDivider() }
                    Button { onMissing(item.target) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).mmFont(16).foregroundStyle(MMInk.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.detail).mmFont(13).foregroundStyle(MMInk.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            MMRowChevron()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MMLightPressStyle())
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Packet contents

    private var contentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMRecordSectionHeader(title: "Packet contents")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.contentLines, id: \.self) { line in
                    Text(line).mmFont(15).monospacedDigit().foregroundStyle(MMInk.text)
                }
            }
            .padding(.leading, 2)
            Text("The packet covers the whole rental record, with dates.")
                .mmFont(13)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 2)
        }
    }

    // MARK: Action

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 6) {
            switch model.packet {
            case .needsMoveInProof:
                MMPrimaryButton(title: "Add move-in proof", icon: "camera") { onMissing(.rooms) }
            case .ready, .failed:
                if model.packet == .failed {
                    Text("The last packet couldn't be generated. Your evidence is unchanged.")
                        .mmFont(13).foregroundStyle(MMInk.secondary).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MMPrimaryButton(title: "Generate evidence packet", icon: "doc.richtext", action: onGenerate)
                if !model.hasPro {
                    Text("The evidence packet is part of Pro.")
                        .mmFont(13).foregroundStyle(MMInk.secondary)
                }
            case .generating:
                MMPrimaryButton(title: "Generating evidence packet…", isLoading: true, isDisabled: true, action: {})
                Text("This takes a moment. You can leave this screen.")
                    .mmFont(13).foregroundStyle(MMInk.secondary)
            case .generated:
                MMPrimaryButton(title: isDownloading ? "Opening…" : "View evidence packet", icon: "doc.richtext",
                                isLoading: isDownloading, isDisabled: isDownloading, action: onView)
                MMSecondaryButton(title: "Share", icon: "square.and.arrow.up", isDisabled: isDownloading, action: onShare)
                Button("Generate a new packet", action: onGenerate)
                    .mmFont(14)
                    .foregroundStyle(MMInk.secondary)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
