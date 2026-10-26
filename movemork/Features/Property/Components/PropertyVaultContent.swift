//
//  PropertyVaultContent.swift
//  movemork
//
//  @file The rental detail as a presentational view: the dark header names the rental, the light sheet
//        carries its proof state with the one next action, its rooms, its records (lease, deposit receipt,
//        listing proof, invoices) as a native grouped list with a status and one action each, the proof
//        trail, tools and details. PropertyVaultView owns every state, upload and backend call and feeds
//        this a model, so the screen can be snapshotted in every state.
//  @domain property
//  @see [[MMSystem+Property.swift]]
//

import SwiftUI

struct PropertyVaultModel {
    struct Room: Identifiable {
        let id: UUID
        let name: String
        let detail: String
        let state: MMRoomRow.RoomState
        var isPulsing = false
    }

    struct Record: Identifiable {
        var id: String { type.rawValue }
        let type: VaultDocumentType
        let isPresent: Bool
        let subtitle: String
        var isHighlighted = false
    }

    struct Tool: Identifiable {
        enum Kind { case maintenance, moveOut, caseBuilder, exports }
        var id: Kind { kind }
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        var isPulsing = false
    }

    struct Detail: Identifiable {
        var id: String { label }
        let label: String
        let value: String
    }

    var title: String
    var location: String?
    var documented: Int
    var total: Int
    var photos: Int
    var progress: Double
    var nextLine: String
    var primaryTitle: String
    /// The camera glyph when the next action is a capture; none otherwise.
    var primaryIcon: String? = nil
    var summaryError: String?
    var trail: [MMProofTimelineRow] = []
    var highlightedTrailID: String?
    var rooms: [Room] = []
    /// Every record slot, in display order; the first `priorityCount` show when the list is collapsed.
    var records: [Record] = []
    var priorityCount = 3
    var uploadedCount = 0
    var uploadError: String?
    var softNotice: String?
    var previewError: String?
    var isUploading = false
    var tools: [Tool] = []
    var tenancy: [Detail] = []
    var contact: [Detail] = []
}

struct PropertyVaultContent: View {
    let model: PropertyVaultModel
    @Binding var showAllRecords: Bool
    @Binding var showDetails: Bool
    var appeared = true

    var onPrimary: () -> Void = {}
    var onRetrySummary: () -> Void = {}
    var onSeeAllRooms: () -> Void = {}
    var onOpenRoom: (UUID) -> Void = { _ in }
    var onRetryUpload: () -> Void = {}
    var onViewRecord: (VaultDocumentType) -> Void = { _ in }
    var onUploadRecord: (VaultDocumentType) -> Void = { _ in }
    var onDeleteRecord: (VaultDocumentType) -> Void = { _ in }
    var onTool: (PropertyVaultModel.Tool.Kind) -> Void = { _ in }
    var onEdit: () -> Void = {}

    var body: some View {
        MMScreen(eyebrow: "Rental", title: model.title, subtitle: model.location, isPushed: true) {
            proofPanel
            if let error = model.summaryError, model.uploadError == nil {
                MMNotice(message: error, actionTitle: MMCopy.tryAgain, action: onRetrySummary)
                    .padding(.top, 14)
            }
            section(delay: 0.06) { roomsSection }
            section(delay: 0.10) { recordsSection }
            section(delay: 0.14) { trailSection }
            section(delay: 0.17) { toolsSection }
            section(delay: 0.20) { detailsSection }
        }
    }

    private func section<C: View>(delay: Double, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(.top, 30)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(MMMotion.screenTransition.delay(delay), value: appeared)
    }

    // MARK: Proof state + the one action

    private var proofPanel: some View {
        MMPanel {
            Text("Move-in proof").mmFont(12.5).foregroundStyle(MMInk.secondary)
            Text(model.total == 0 ? "No rooms yet" : "\(model.documented) of \(model.total) rooms ready")
                .mmFont(20, .semibold)
                .foregroundStyle(MMInk.text)
                .padding(.top, 2)
            MMProgressLine(fraction: model.progress).padding(.top, 12)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.nextLine).mmFont(13.5).foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(model.photos) \(model.photos == 1 ? "photo" : "photos")")
                    .mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
            }
            .padding(.top, 10)
            MMPrimaryButton(title: model.primaryTitle, icon: model.primaryIcon) {
                MMHaptics.soft()
                onPrimary()
            }
            .padding(.top, 16)
        }
    }

    // MARK: Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionTitle(title: "Rooms", trailing: "See all", action: onSeeAllRooms)
            MMGroup {
                if model.rooms.isEmpty {
                    MMRow(title: "No rooms yet", subtitle: "Add the rooms you want documented.",
                          icon: "door.left.hand.open", action: onSeeAllRooms)
                } else {
                    ForEach(Array(model.rooms.enumerated()), id: \.element.id) { index, room in
                        if index > 0 { MMRowDivider(leading: 52) }
                        Button { onOpenRoom(room.id) } label: {
                            MMRoomRow(name: room.name, detail: room.detail, state: room.state, isHighlighted: room.isPulsing)
                        }
                        .buttonStyle(MMLightPressStyle())
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: Records (lease, deposit receipt, listing proof, invoices)

    private var visibleRecords: [PropertyVaultModel.Record] {
        showAllRecords ? model.records : Array(model.records.prefix(model.priorityCount))
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MMSectionTitle(title: "Records")
                Text("\(model.uploadedCount) of \(model.records.count) added")
                    .mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
            }
            if let uploadError = model.uploadError {
                MMNotice(message: uploadError, actionTitle: MMCopy.tryAgain, action: onRetryUpload)
            }
            if let notice = model.softNotice, model.uploadError == nil {
                MMNotice(message: notice, tone: .info)
            }
            if let previewError = model.previewError {
                MMNotice(message: previewError)
            }
            MMGroup(footer: model.records.contains(where: \.isPresent)
                    ? "Touch and hold an added record to replace or delete it." : nil) {
                ForEach(Array(visibleRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 { MMRowDivider(leading: 52) }
                    recordRow(record)
                }
                if model.records.count > model.priorityCount {
                    MMRowDivider(leading: 52)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAllRecords.toggle() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: showAllRecords ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MMInk.secondary)
                                .frame(width: 24)
                            Text(showAllRecords ? "Fewer records" : "All records")
                                .mmFont(15.5).foregroundStyle(MMInk.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MMLightPressStyle())
                }
            }
        }
    }

    private func recordRow(_ record: PropertyVaultModel.Record) -> some View {
        let busy = !record.isPresent && record.type.acceptsImage && model.isUploading
        return MMStatusRow(
            title: Self.recordTitle(record.type),
            subtitle: record.subtitle,
            icon: record.isPresent ? "doc.text.fill" : "doc.text",
            status: record.isPresent ? "Added" : "Needed",
            tone: record.isPresent ? .done : .needed,
            isHighlighted: record.isHighlighted
        ) {
            if record.isPresent {
                Button { onViewRecord(record.type) } label: { MMRowActionLabel(title: "View") }
                    .buttonStyle(MMLightPressStyle())
            } else {
                Button { onUploadRecord(record.type) } label: { MMRowActionLabel(title: "Add", isBusy: busy) }
                    .buttonStyle(MMLightPressStyle())
                    .disabled(busy)
            }
        }
        .contextMenu {
            if record.isPresent {
                Button(record.type.acceptsImage ? "Replace with photo" : "Replace") { onUploadRecord(record.type) }
                Button("Delete", role: .destructive) { onDeleteRecord(record.type) }
            }
        }
    }

    static func recordTitle(_ type: VaultDocumentType) -> String {
        let title = type.displayTitle
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    // MARK: Proof trail

    private var trailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionTitle(title: "Proof trail")
            MMGroup {
                if model.trail.isEmpty {
                    Text("Your proof trail will show up here.")
                        .mmFont(14).foregroundStyle(MMInk.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(model.trail.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { MMRowDivider(leading: 52) }
                        MMTrailRow(icon: row.iconName, title: row.title.prefix(1).uppercased() + row.title.dropFirst(), message: row.message, timestamp: row.timestamp,
                                   tone: row.status.rowTone, isHighlighted: row.id == model.highlightedTrailID)
                    }
                }
            }
        }
    }

    // MARK: Tools

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionTitle(title: "Tools")
            MMGroup {
                ForEach(Array(model.tools.enumerated()), id: \.element.id) { index, tool in
                    if index > 0 { MMRowDivider(leading: 52) }
                    Button { onTool(tool.kind) } label: {
                        MMStatusRow(title: tool.title, subtitle: tool.subtitle, icon: tool.icon, isHighlighted: tool.isPulsing)
                    }
                    .buttonStyle(MMLightPressStyle())
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MMSectionTitle(title: "Rental details")
                Button("Edit", action: onEdit).mmFont(14, .semibold).foregroundStyle(MMInk.text)
            }
            MMGroup {
                if showDetails {
                    ForEach(model.tenancy + model.contact) { detail in
                        detailRow(detail)
                        MMRowDivider()
                    }
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showDetails.toggle() }
                } label: {
                    HStack {
                        Text(showDetails ? "Hide details" : "Show details").mmFont(15.5).foregroundStyle(MMInk.text)
                        Spacer()
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MMInk.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
            }
        }
    }

    private func detailRow(_ detail: PropertyVaultModel.Detail) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(detail.label).mmFont(15).foregroundStyle(MMInk.secondary)
                Spacer(minLength: 12)
                Text(detail.value).mmFont(15).foregroundStyle(MMInk.text).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.label).mmFont(13).foregroundStyle(MMInk.secondary)
                Text(detail.value).mmFont(15).foregroundStyle(MMInk.text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mapping from records (shared by the screen and its snapshots)

extension PropertyVaultModel.Room {
    init(room: RoomRecord, isNext: Bool, isPulsing: Bool = false) {
        let photos = room.moveInPhotoTotal + room.moveOutPhotoTotal
        let issues = room.moveInIssueTagTotal + room.moveOutIssueTagTotal
        let isDone = !room.evidence.isEmpty
        self.init(
            id: room.id,
            name: room.name,
            detail: isDone ? MMProofTimelineBuilder.photoIssueLine(photos: photos, issues: issues) : "No proof yet",
            state: isDone ? .documented : (isNext ? .next : .todo),
            isPulsing: isPulsing
        )
    }
}

extension PropertyVaultModel.Tool {
    static func all(openIssues: Int, completedRooms: Int, readinessScore: Int, exportsSubtitle: String,
                    pulseDispute: Bool = false, pulseExports: Bool = false) -> [Self] {
        [
            .init(kind: .maintenance, title: "Maintenance",
                  subtitle: openIssues > 0
                      ? (openIssues == 1 ? "1 open issue" : "\(openIssues) open issues")
                      : "Track property issues",
                  icon: "wrench.and.screwdriver"),
            .init(kind: .moveOut, title: "Move-out",
                  subtitle: completedRooms > 0 ? "Compare before and after" : "Use with move-in proof",
                  icon: "arrow.2.circlepath"),
            .init(kind: .caseBuilder, title: "Case builder",
                  subtitle: readinessScore >= 70 ? "Build dispute packet" : "Assemble captured proof",
                  icon: "doc.text.magnifyingglass", isPulsing: pulseDispute),
            .init(kind: .exports, title: "Exports", subtitle: exportsSubtitle,
                  icon: "square.and.arrow.up", isPulsing: pulseExports),
        ]
    }
}

extension PropertyVaultModel.Detail {
    static func tenancy(for property: PropertyRecord) -> [Self] {
        var rows: [Self] = [.init(label: "Move-in", value: property.moveInDate.formatted(date: .abbreviated, time: .omitted))]
        if let start = property.leaseStartDate {
            rows.append(.init(label: "Lease start", value: start.formatted(date: .abbreviated, time: .omitted)))
        }
        rows.append(.init(label: "Lease end", value: property.leaseEndDate.formatted(date: .abbreviated, time: .omitted)))
        if !property.depositAmount.isEmpty { rows.append(.init(label: "Deposit", value: property.depositAmount)) }
        if !property.rentAmount.isEmpty { rows.append(.init(label: "Rent", value: property.rentAmount)) }
        return rows
    }

    static func contact(for property: PropertyRecord) -> [Self] {
        [
            .init(label: "Landlord", value: property.landlordName.isEmpty ? "Not added" : property.landlordName),
            .init(label: "Email", value: property.landlordEmail.isEmpty ? "Not added" : property.landlordEmail),
        ]
    }
}
