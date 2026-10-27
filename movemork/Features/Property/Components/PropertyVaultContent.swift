//
//  PropertyVaultContent.swift
//  movemork
//
//  @file The rental record as a presentational view — the master file for one rental. The dark header names
//        the rental (address, move-in date) and states its move-in proof as the Proof header does. The light
//        sheet then reads in order of weight: rooms (the next room with the one capture action, then every
//        room's proof), records (lease, deposit receipt, listing proof — Added / Needed, one action each),
//        maintenance and move-out as related proof, and the rental's details quietly at the bottom.
//        PropertyVaultView owns every state, upload and backend call and feeds this a model, so the screen
//        can be snapshotted in every state.
//  @domain property
//  @see [[MMSystem+Rental.swift]]
//

import SwiftUI

struct PropertyVaultModel {
    struct Record: Identifiable {
        var id: String { type.rawValue }
        let type: VaultDocumentType
        let isPresent: Bool
        /// Present: when it was added ("Oct 19, 2025"), when known.
        var addedOn: String? = nil
        /// Present: what the file is ("lease-2025.pdf", or "Image" for photos stored under generated names).
        var file: String? = nil
        var isHighlighted = false
    }

    /// Maintenance cases for this rental. `total` is nil when only the open count is known.
    struct Maintenance {
        var open = 0
        var total: Int? = nil
    }

    /// Move-out, shown only once it's relevant (move-out proof exists, or the lease is ending).
    struct MoveOut {
        var documented: Int
        var total: Int
        /// Days until the lease ends, when that is why move-out is showing.
        var daysUntilLeaseEnd: Int? = nil
    }

    enum Link { case maintenance, moveOut, caseBuilder, exports }

    struct Detail: Identifiable {
        var id: String { label }
        let label: String
        let value: String
    }

    var title: String
    /// "Unit 2304 · Toronto, ON".
    var addressLine: String?
    /// "Moved in Oct 19, 2025".
    var moveInLine: String?
    var rooms: [MMRentalRoom] = []
    var nextRoomID: UUID?
    var summaryError: String?
    /// Every record slot, in display order; the first `priorityCount` always show.
    var records: [Record] = []
    var priorityCount = 3
    var uploadError: String?
    var softNotice: String?
    var previewError: String?
    var isUploading = false
    var maintenance = Maintenance()
    var moveOut: MoveOut? = nil
    /// Address and dates, always shown in Rental details.
    var details: [Detail] = []
    /// Deposit, rent and landlord, shown under "More details".
    var moreDetails: [Detail] = []

    var documented: Int { rooms.filter(\.isDocumented).count }
    var total: Int { rooms.count }
}

struct PropertyVaultContent: View {
    let model: PropertyVaultModel
    @Binding var showAllRecords: Bool
    @Binding var showDetails: Bool
    var appeared = true

    /// Capture the next room.
    var onPrimary: () -> Void = {}
    var onRetrySummary: () -> Void = {}
    var onSeeAllRooms: () -> Void = {}
    var onOpenRoom: (UUID) -> Void = { _ in }
    var onRetryUpload: () -> Void = {}
    var onViewRecord: (VaultDocumentType) -> Void = { _ in }
    var onUploadRecord: (VaultDocumentType) -> Void = { _ in }
    var onDeleteRecord: (VaultDocumentType) -> Void = { _ in }
    var onLink: (PropertyVaultModel.Link) -> Void = { _ in }
    var onEdit: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        MMRecordScreen(
            eyebrow: "Rental record",
            title: model.title,
            lines: [model.addressLine, model.moveInLine].compactMap { $0 },
            headerExtra: {
                MMHeaderProofProgress(done: model.documented, total: model.total).padding(.top, 22)
            }
        ) {
            if let error = model.summaryError, model.uploadError == nil {
                MMNotice(message: error, tone: .info, actionTitle: MMCopy.tryAgain, action: onRetrySummary)
                    .padding(.bottom, 22)
            }
            section(delay: 0, top: 0) { roomsSection }
            section(delay: 0.06) { recordsSection }
            section(delay: 0.10) { relatedSection }
            section(delay: 0.14) { detailsSection }
        }
    }

    private func section<C: View>(delay: Double, top: CGFloat = 32, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(.top, top)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(MMMotion.screenTransition.delay(delay), value: appeared)
    }

    // MARK: Rooms — the evidence, and the one action

    @ViewBuilder
    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMRecordSectionHeader(title: "Rooms",
                                  actionTitle: model.rooms.isEmpty ? nil : "All rooms",
                                  action: model.rooms.isEmpty ? nil : onSeeAllRooms)
            if model.rooms.isEmpty {
                MMEmptyBlock(
                    icon: "door.left.hand.open",
                    title: "No rooms yet",
                    message: "Add the rooms you'll document, then photograph each one before you unpack. That becomes your move-in record.",
                    actionTitle: "Add rooms",
                    action: onSeeAllRooms
                )
            } else {
                MMRentalRoomsBlock(
                    rooms: model.rooms,
                    nextID: model.nextRoomID,
                    limit: 4,
                    completeTitle: "Every room documented",
                    completeActionTitle: "Generate move-in report",
                    completeAction: { onLink(.exports) },
                    onCapture: onPrimary,
                    onOpenRoom: onOpenRoom,
                    onSeeAll: onSeeAllRooms
                )
            }
        }
    }

    // MARK: Records — lease, deposit receipt, listing proof

    private var priorityRecords: [PropertyVaultModel.Record] { Array(model.records.prefix(model.priorityCount)) }
    private var otherRecords: [PropertyVaultModel.Record] { Array(model.records.dropFirst(model.priorityCount)) }
    /// Other records show when added, or when the list is expanded.
    private var visibleRecords: [PropertyVaultModel.Record] {
        priorityRecords + otherRecords.filter { showAllRecords || $0.isPresent }
    }
    private var hiddenRecordCount: Int { otherRecords.filter { !$0.isPresent }.count }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMRecordSectionHeader(title: "Records",
                                  detail: "\(priorityRecords.filter(\.isPresent).count) of \(priorityRecords.count) added")
            if let uploadError = model.uploadError {
                MMNotice(message: uploadError, actionTitle: MMCopy.tryAgain, action: onRetryUpload)
            }
            if let notice = model.softNotice, model.uploadError == nil {
                MMNotice(message: notice.trimmingCharacters(in: .whitespaces), tone: .info)
            }
            if let previewError = model.previewError {
                MMNotice(message: previewError, tone: .warning)
            }
            MMGroup(footer: model.records.contains(where: \.isPresent)
                    ? "Touch and hold an added record to replace or delete it." : nil) {
                ForEach(Array(visibleRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 { MMRowDivider(leading: dynamicTypeSize.isAccessibilitySize ? 16 : 52) }
                    recordRow(record)
                }
                if hiddenRecordCount > 0 {
                    MMRowDivider(leading: dynamicTypeSize.isAccessibilitySize ? 16 : 52)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAllRecords.toggle() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: showAllRecords ? "chevron.up" : "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MMInk.secondary)
                                .frame(width: 24)
                            Text(showAllRecords ? "Fewer records" : "Other records")
                                .mmFont(15.5).foregroundStyle(MMInk.text)
                            Spacer()
                            if !showAllRecords && !dynamicTypeSize.isAccessibilitySize {
                                Text("Receipts, invoices").mmFont(13).foregroundStyle(MMInk.secondary).lineLimit(1)
                            }
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
        let busy = record.type.acceptsImage && model.isUploading
        return MMRecordRow(
            title: Self.recordTitle(record.type),
            icon: Self.recordIcon(record.type),
            isPresent: record.isPresent,
            detail: record.isPresent ? record.addedOn : Self.recordReason(record.type),
            file: record.file,
            isHighlighted: record.isHighlighted
        ) {
            if record.isPresent && !busy {
                Button { onViewRecord(record.type) } label: { MMRowActionLabel(title: "View") }
                    .buttonStyle(MMLightPressStyle())
                    .accessibilityLabel("View \(Self.recordTitle(record.type))")
            } else {
                Button { onUploadRecord(record.type) } label: { MMRowActionLabel(title: "Add", isBusy: busy) }
                    .buttonStyle(MMLightPressStyle())
                    .disabled(busy)
                    .accessibilityLabel("Add \(Self.recordTitle(record.type))")
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

    static func recordIcon(_ type: VaultDocumentType) -> String {
        switch type {
        case .lease: "signature"
        case .depositReceipt: "dollarsign.circle"
        case .listingScreenshot: "photo"
        case .cleaningReceipt: "sparkles"
        case .utilityProof: "bolt"
        case .moveOutInvoice: "doc.plaintext"
        case .other: "doc"
        }
    }

    /// Why a missing record is worth adding.
    static func recordReason(_ type: VaultDocumentType) -> String {
        switch type {
        case .lease: "Ties your proof to this rental"
        case .depositReceipt: "Shows what you paid, and when"
        case .listingScreenshot: "How the rental was advertised"
        case .cleaningReceipt: "Shows the unit was cleaned"
        case .utilityProof: "Dates when you lived here"
        case .moveOutInvoice: "Any charges at move-out"
        case .other: "Anything else worth keeping"
        }
    }

    // MARK: Related proof — maintenance, move-out

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMRecordSectionHeader(title: model.moveOut == nil ? "Maintenance" : "Maintenance & move-out")
            MMGroup {
                Button { onLink(.maintenance) } label: {
                    MMStatusRow(title: "Maintenance log", subtitle: maintenanceLine, icon: "wrench.and.screwdriver",
                                status: model.maintenance.open > 0 ? openLabel : nil, tone: .needed)
                }
                .buttonStyle(MMLightPressStyle())
                .accessibilityElement(children: .combine)
                if let moveOut = model.moveOut {
                    MMRowDivider(leading: dynamicTypeSize.isAccessibilitySize ? 16 : 52)
                    Button { onLink(.moveOut) } label: {
                        MMStatusRow(title: "Move-out", subtitle: moveOutLine(moveOut), icon: "arrow.2.circlepath")
                    }
                    .buttonStyle(MMLightPressStyle())
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var openLabel: String { "\(model.maintenance.open) open" }

    private var maintenanceLine: String {
        let open = model.maintenance.open
        let total = max(model.maintenance.total ?? open, open)
        if total == 0 { return "No cases recorded. When something breaks, record it with photos and a date." }
        let cases = total == 1 ? "1 case recorded" : "\(total) cases recorded"
        let resolved = total - open
        if open == 0 { return "\(cases) · all resolved" }
        return resolved > 0 ? "\(cases) · \(resolved) resolved" : cases
    }

    private func moveOutLine(_ moveOut: PropertyVaultModel.MoveOut) -> String {
        if moveOut.documented == 0 {
            if let days = moveOut.daysUntilLeaseEnd {
                let when = days == 0 ? "today" : (days == 1 ? "in 1 day" : "in \(days) days")
                return "Lease ends \(when). Compare move-in to move-out, room by room."
            }
            return "Compare move-in to move-out, room by room."
        }
        return "\(moveOut.documented) of \(moveOut.total) rooms recaptured"
    }

    // MARK: Rental details — quiet, last

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rental details").mmFont(16, .semibold).foregroundStyle(MMInk.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onEdit) {
                    Text("Edit").mmFont(14, .semibold).foregroundStyle(MMInk.text)
                        .frame(minWidth: 44, minHeight: 32, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .accessibilityLabel("Edit rental details")
            }
            MMGroup {
                ForEach(Array(model.details.enumerated()), id: \.element.id) { index, detail in
                    if index > 0 { MMRowDivider() }
                    detailRow(detail)
                }
                if showDetails {
                    ForEach(model.moreDetails) { detail in
                        MMRowDivider()
                        detailRow(detail)
                    }
                }
                if !model.moreDetails.isEmpty {
                    MMRowDivider()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showDetails.toggle() }
                    } label: {
                        HStack {
                            Text(showDetails ? "Fewer details" : "Deposit, rent and landlord").mmFont(15).foregroundStyle(MMInk.text)
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
    }

    private func detailRow(_ detail: PropertyVaultModel.Detail) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(detail.label).mmFont(15).foregroundStyle(MMInk.secondary).fixedSize()
                Spacer(minLength: 12)
                Text(detail.value).mmFont(15).foregroundStyle(MMInk.text).multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.label).mmFont(13).foregroundStyle(MMInk.secondary)
                Text(detail.value).mmFont(15).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mapping from records (shared by the screen and its snapshots)

extension PropertyVaultModel {
    static func displayTitle(for property: PropertyRecord) -> String {
        let title = property.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let address = property.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? "Your rental" : address
    }

    static func addressLine(for property: PropertyRecord) -> String? {
        RentalAddress.line(title: displayTitle(for: property), street: property.addressLine1,
                           unit: property.addressLine2, city: property.city, province: property.provinceState)
    }

    static func moveInLine(for property: PropertyRecord, now: Date = Date()) -> String {
        let date = MMRecordDate.display(property.moveInDate)
        return property.moveInDate > now ? "Moving in \(date)" : "Moved in \(date)"
    }
}

extension PropertyVaultModel.Detail {
    /// Address and dates: what identifies the rental.
    static func primary(for property: PropertyRecord) -> [Self] {
        var rows: [Self] = []
        let street = [property.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
                      RentalAddress.unitLabel(property.addressLine2)]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let place = [RentalLocation.line(city: property.city, province: property.provinceState),
                     property.postalCode.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }.joined(separator: " ")
        let address = [street, place].filter { !$0.isEmpty }.joined(separator: "\n")
        if !address.isEmpty { rows.append(.init(label: "Address", value: address)) }
        rows.append(.init(label: "Move-in", value: MMRecordDate.display(property.moveInDate)))
        let end = MMRecordDate.display(property.leaseEndDate)
        if let start = property.leaseStartDate {
            rows.append(.init(label: "Lease", value: "\(MMRecordDate.display(start)) – \(end)"))
        } else {
            rows.append(.init(label: "Lease ends", value: end))
        }
        return rows
    }

    /// Deposit, rent, landlord: only what was entered.
    static func more(for property: PropertyRecord) -> [Self] {
        var rows: [Self] = []
        func money(_ raw: String) -> String? {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return value.hasPrefix("$") ? value : "$\(value)"
        }
        if let deposit = money(property.depositAmount) { rows.append(.init(label: "Deposit", value: deposit)) }
        if let rent = money(property.rentAmount) { rows.append(.init(label: "Rent", value: "\(rent) / month")) }
        let landlord = [property.landlordName, property.landlordEmail, property.landlordPhone]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !landlord.isEmpty { rows.append(.init(label: "Landlord", value: landlord.joined(separator: "\n"))) }
        return rows
    }
}
