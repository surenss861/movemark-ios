//
//  DisputeBuilderView.swift
//  movemork
//
//  MoveMark — Premium dispute payoff: case setup, evidence selection, packet strength, export.
//

import SwiftUI
import Supabase

struct DisputeBuilderView: View {
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var summary = ""
    @State private var title = "Deposit dispute"
    @State private var amountInQuestion = ""
    @State private var moveOutDate = Date()
    @State private var receivedItemized = false
    @State private var chargeDate = Date()
    @State private var selectedType: DisputeDraft.DisputeType = .depositWithheld
    @State private var disputeId: UUID? = nil

    @State private var selectedEvidenceFileIds: Set<UUID> = []
    @State private var selectedMaintenanceIds: Set<UUID> = []
    @State private var selectedDocumentIds: Set<UUID> = []

    @State private var isGeneratingPDF = false
    @State private var isGeneratingPacket = false
    @State private var isSavingDraft = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var retryAction: (() -> Void)? = nil

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var navigateToExportHistory = false
    @State private var openExportsOnShareDismiss = false

    @State private var evidenceFiles: [EvidenceFileRow] = []
    @State private var maintenanceIssues: [MaintenanceIssueRow] = []
    @State private var documents: [PropertyDocumentRow] = []
    @State private var isLoadingEvidence = false

    private let disputeRepo = DisputeRepository()
    private let exportRepo = ExportRepository()
    private let inspectionRepo = InspectionRepository()
    private let maintenanceRepo = MaintenanceRepository()
    private let documentRepo = DocumentRepository()

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            if propertyStore.currentProperty == nil {
                emptyPropertyState
            } else if isLoadingEvidence && evidenceFiles.isEmpty && maintenanceIssues.isEmpty && documents.isEmpty {
                evidenceLoadingState
            } else {
                mainContent
            }
        }
        .sheet(
            isPresented: $showShareSheet,
            onDismiss: {
                if openExportsOnShareDismiss {
                    openExportsOnShareDismiss = false
                    navigateToExportHistory = true
                }
            }
        ) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
        .task {
            await loadEvidenceData()
            await loadDraftIfNeeded()
        }
        .navigationDestination(isPresented: $navigateToExportHistory) {
            ExportHistoryView()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var emptyPropertyState: some View {
        VStack(spacing: 20) {
            Text("No property yet")
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Create a property and add evidence before building a dispute packet.")
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var evidenceLoadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(MoveMarkTheme.Colors.primary)
                .scaleEffect(1.2)

            Text("Loading evidence and documents...")
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                caseSetupCard

                evidenceSelectionCard

                packetStrengthCard

                exportCard

                if let successMessage {
                    MMCard {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MoveMarkTheme.Colors.primary)

                            Text(successMessage)
                                .font(MoveMarkTheme.Typography.subheadlineMedium)
                                .foregroundStyle(MoveMarkTheme.Colors.primary)
                        }
                    }
                }

                if let errorMessage {
                    MMErrorBanner(
                        message: errorMessage,
                        retryTitle: retryAction != nil ? MMCopy.tryAgain : nil,
                        onRetry: retryAction
                    )
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 22)
            .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dispute builder")
                .font(MoveMarkTheme.Typography.screenTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Assemble the case packet when charges or deposit problems show up. Calm, evidence-backed, export-ready.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: 38, height: 3)
                .clipShape(Capsule())
        }
    }

    private var caseSetupCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Case setup")

                Picker("", selection: $selectedType) {
                    ForEach(DisputeDraft.DisputeType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                MMTextField(title: "Case title", placeholder: "Deposit dispute", text: $title)
                MMTextField(title: "Amount in question", placeholder: "2400", text: $amountInQuestion, keyboardType: .decimalPad)
                MMTextField(
                    title: "Summary",
                    placeholder: "Describe what happened and what you need to defend",
                    text: $summary
                )

                DatePicker("Move-out date", selection: $moveOutDate, displayedComponents: .date)
                    .colorScheme(.dark)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Toggle(isOn: $receivedItemized) {
                    Text("Received itemized charges")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
                .tint(MoveMarkTheme.Colors.primary)

                if receivedItemized {
                    DatePicker("Charge date", selection: $chargeDate, displayedComponents: .date)
                        .colorScheme(.dark)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
            }
        }
    }

    private var evidenceSelectionCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "What goes in the packet")

                Text("Choose the proof you want included. This becomes the record you export.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                selectionGroup(
                    title: "Room photos",
                    count: selectedEvidenceFileIds.count,
                    emptyText: "No room photos yet. Add move-in or move-out evidence from Walkthrough or Move-out.",
                    rows: evidenceFiles.map { file in
                        SelectionRowData(
                            id: file.id,
                            title: evidencePhotoRowTitle(for: file),
                            subtitle: evidencePhotoRowSubtitle(for: file)
                        )
                    },
                    selectedIDs: Binding(
                        get: { selectedEvidenceFileIds },
                        set: { selectedEvidenceFileIds = $0 }
                    )
                )

                selectionGroup(
                    title: "Maintenance issues",
                    count: selectedMaintenanceIds.count,
                    emptyText: "No maintenance issues logged yet.",
                    rows: maintenanceIssues.map { issue in
                        SelectionRowData(
                            id: issue.id,
                            title: issue.title,
                            subtitle: issue.category ?? "Issue"
                        )
                    },
                    selectedIDs: Binding(
                        get: { selectedMaintenanceIds },
                        set: { selectedMaintenanceIds = $0 }
                    )
                )

                selectionGroup(
                    title: "Documents",
                    count: selectedDocumentIds.count,
                    emptyText: "No documents uploaded yet. Add lease, deposit receipt, or screenshots in Vault.",
                    rows: documents.map { doc in
                        SelectionRowData(
                            id: doc.id,
                            title: documentRowTitle(doc),
                            subtitle: documentRowSubtitle(doc)
                        )
                    },
                    selectedIDs: Binding(
                        get: { selectedDocumentIds },
                        set: { selectedDocumentIds = $0 }
                    )
                )
            }
        }
    }

    private var packetStrengthCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(text: "Packet strength")
                    Spacer()
                    MMPill(text: readinessLabel, tone: readinessTone)
                }

                Text("A stronger packet usually includes room photos, supporting documents, and any relevant maintenance history.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                HStack(spacing: 10) {
                    FactChip(title: "Photos", value: "\(selectedEvidenceFileIds.count)")
                    FactChip(title: "Issues", value: "\(selectedMaintenanceIds.count)")
                    FactChip(title: "Docs", value: "\(selectedDocumentIds.count)")
                }

                detailRow("Dispute type", selectedType.rawValue)
                detailRow("Amount", amountDisplay)
                detailRow("Itemized charges", receivedItemized ? "Yes" : "No")
            }
        }
    }

    private var exportCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Export your case")

                Text("Save the draft, export a simple PDF, or generate the formal packet.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                ZStack {
                    MMButton(title: "Save draft", action: saveDraft, isSecondary: true, isDisabled: isSavingDraft)
                        .opacity(isSavingDraft ? 0.6 : 1.0)

                    if isSavingDraft {
                        ProgressView().tint(MoveMarkTheme.Colors.primary)
                    }
                }

                ZStack {
                    MMButton(title: "Export simple PDF", action: exportSimplePDF, isSecondary: true, isDisabled: isGeneratingPDF)
                        .opacity(isGeneratingPDF ? 0.6 : 1.0)

                    if isGeneratingPDF {
                        ProgressView().tint(MoveMarkTheme.Colors.primary)
                    }
                }

                ZStack {
                    MMButton(title: "Generate formal packet", action: generateFormalPacket, isDisabled: isGeneratingPacket)
                        .opacity(isGeneratingPacket ? 0.6 : 1.0)

                    if isGeneratingPacket {
                        ProgressView().tint(MoveMarkTheme.Colors.primary)
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var amountDisplay: String {
        let trimmed = amountInQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Not set" }
        return "$\(trimmed)"
    }

    private var totalSelectedCount: Int {
        selectedEvidenceFileIds.count + selectedMaintenanceIds.count + selectedDocumentIds.count
    }

    private var readinessLabel: String {
        if totalSelectedCount == 0 { return "Not ready" }
        if selectedEvidenceFileIds.count >= 6 && selectedDocumentIds.count >= 2 {
            return "Strong support"
        }
        if totalSelectedCount >= 4 {
            return "Good support"
        }
        return "Record building"
    }

    private var readinessTone: MMPill.Tone {
        switch readinessLabel {
        case "Strong support":
            return .success
        case "Good support":
            return .accent
        default:
            return .warning
        }
    }

    private func loadEvidenceData() async {
        guard let property = propertyStore.currentProperty else { return }

        isLoadingEvidence = true
        defer { isLoadingEvidence = false }

        do {
            async let filesTask = inspectionRepo.fetchEvidenceFiles(propertyId: property.id)
            async let maintenanceTask = maintenanceRepo.fetchIssues(propertyId: property.id)
            async let documentsTask = documentRepo.fetchDocuments(propertyId: property.id)

            evidenceFiles = try await filesTask
            maintenanceIssues = try await maintenanceTask
            documents = try await documentsTask
        } catch {
            errorMessage = MoveMarkFlowMessage.disputeEvidenceLoadFailed(error)
            retryAction = { Task { await loadEvidenceData() } }
        }
    }

    private func saveDraft() {
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else { return }
        guard !isSavingDraft else { return }

        isSavingDraft = true
        errorMessage = nil
        successMessage = nil
        retryAction = nil

        Task { @MainActor in
            defer { isSavingDraft = false }

            do {
                let amount: Double? = {
                    let trimmed = amountInQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    return Double(trimmed)
                }()

                let row = DisputeRow(
                    id: disputeId ?? UUID(),
                    propertyId: property.id,
                    userId: userId,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Deposit dispute" : title.trimmingCharacters(in: .whitespacesAndNewlines),
                    disputeType: mapDisputeType(selectedType),
                    status: "draft",
                    amountInQuestion: amount,
                    summary: summary.isEmpty ? nil : summary.trimmingCharacters(in: .whitespacesAndNewlines),
                    moveOutDate: Self.dbDateFormatter.string(from: moveOutDate),
                    receivedItemized: receivedItemized,
                    chargeDate: receivedItemized ? Self.dbDateFormatter.string(from: chargeDate) : nil,
                    createdAt: nil,
                    updatedAt: nil
                )

                let savedId = try await disputeRepo.upsertDispute(row)
                disputeId = savedId

                try await disputeRepo.replaceEvidenceLinks(
                    disputeId: savedId,
                    evidenceFileIds: Array(selectedEvidenceFileIds),
                    maintenanceIssueIds: Array(selectedMaintenanceIds),
                    propertyDocumentIds: Array(selectedDocumentIds)
                )

                successMessage = "Draft saved."
                MMHaptics.success()
            } catch {
                errorMessage = MoveMarkFlowMessage.disputeOperationFailed(
                    error,
                    fallback: "Couldn’t save draft. Try again."
                )
                retryAction = { saveDraft() }
            }
        }
    }

    private func exportSimplePDF() {
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else { return }
        guard !isGeneratingPDF else { return }

        isGeneratingPDF = true
        errorMessage = nil
        successMessage = nil
        retryAction = nil

        Task { @MainActor in
            defer { isGeneratingPDF = false }

            do {
                propertyStore.updateDisputeDraft(type: selectedType, summary: summary)
                let packetData = PDFGenerator.generateDisputeSummary(
                    property: property,
                    dispute: propertyStore.disputeDraft,
                    evidenceCount: selectedEvidenceFileIds.count,
                    photoCount: propertyStore.totalPhotoCount,
                    documentCount: selectedDocumentIds.count,
                    moveOutDate: moveOutDate,
                    receivedItemized: receivedItemized,
                    chargeDate: receivedItemized ? chargeDate : nil
                )

                let path = "\(userId)/\(property.id)/dispute_packet/\(UUID().uuidString).pdf"
                let storedPath = try await exportRepo.uploadExport(data: packetData, path: path)

                try await exportRepo.insertExport(
                    ExportRow(
                        id: UUID(),
                        disputeId: disputeId,
                        propertyId: property.id,
                        userId: userId,
                        exportType: "dispute_packet",
                        filePath: storedPath,
                        createdAt: nil
                    )
                )

                shareItems = [packetData]
                openExportsOnShareDismiss = true
                showShareSheet = true
                successMessage = "Simple PDF exported."
                MMHaptics.success()
            } catch {
                errorMessage = MoveMarkFlowMessage.disputeOperationFailed(
                    error,
                    fallback: "Couldn’t export PDF. Try again."
                )
                retryAction = { exportSimplePDF() }
            }
        }
    }

    private func generateFormalPacket() {
        guard !isGeneratingPacket else { return }
        guard let existingDisputeId = disputeId else {
            errorMessage = "Save the draft first."
            retryAction = nil
            return
        }
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.noPropertyOrAuth
            retryAction = nil
            return
        }

        isGeneratingPacket = true
        errorMessage = nil
        successMessage = nil
        retryAction = nil

        Task { @MainActor in
            defer { isGeneratingPacket = false }

            do {
                let session = try await supabase.auth.session
                let packet = try await disputeRepo.callGenerateDisputePacket(
                    disputeId: existingDisputeId,
                    propertyId: property.id,
                    jwt: session.accessToken
                )

                let exportRow = ExportRow(
                    id: UUID(),
                    disputeId: existingDisputeId,
                    propertyId: property.id,
                    userId: userId,
                    exportType: "dispute_packet",
                    filePath: packet.storagePath,
                    createdAt: nil
                )
                try await disputeRepo.insertExportRecord(exportRow)

                shareItems = [packet.shareURL]
                openExportsOnShareDismiss = true
                showShareSheet = true
                successMessage = "Formal packet generated."
                MMHaptics.success()
            } catch {
                errorMessage = MoveMarkFlowMessage.disputeOperationFailed(
                    error,
                    fallback: "Couldn’t generate formal packet. Try again."
                )
                retryAction = { generateFormalPacket() }
            }
        }
    }

    private func mapDisputeType(_ type: DisputeDraft.DisputeType) -> String {
        switch type {
        case .depositWithheld:
            return "deposit_withheld"
        case .cleaningFee:
            return "cleaning_fee"
        case .falseDamage:
            return "damage_charge"
        case .other:
            return "other"
        }
    }

    private func disputeType(from raw: String) -> DisputeDraft.DisputeType {
        switch raw {
        case "deposit_withheld": return .depositWithheld
        case "cleaning_fee": return .cleaningFee
        case "damage_charge", "false_damage": return .falseDamage
        case "itemized_deductions": return .other
        default: return .other
        }
    }

    private static let dbDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let evidenceCapturedAtISOFormatter = ISO8601DateFormatter()

    private static func parseDBDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return Self.dbDateFormatter.date(from: value)
    }

    private func loadDraftIfNeeded() async {
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else { return }
        do {
            guard let draft = try await disputeRepo.fetchDraft(propertyId: property.id, userId: userId) else { return }
            await MainActor.run {
                disputeId = draft.id
                title = draft.title
                amountInQuestion = draft.amountInQuestion.map { String(format: "%.0f", $0) } ?? ""
                summary = draft.summary ?? ""
                selectedType = disputeType(from: draft.disputeType)
                if let d = Self.parseDBDate(draft.moveOutDate) { moveOutDate = d }
                receivedItemized = draft.receivedItemized ?? false
                if let d = Self.parseDBDate(draft.chargeDate) { chargeDate = d }
            }
            let links = try await disputeRepo.fetchEvidenceLinks(disputeId: draft.id)
            await MainActor.run {
                selectedEvidenceFileIds = Set(links.evidenceFileIds)
                selectedMaintenanceIds = Set(links.maintenanceIssueIds)
                selectedDocumentIds = Set(links.propertyDocumentIds)
            }
        } catch {
            // Non-fatal; user can start fresh
        }
    }

    private func evidencePhotoRowTitle(for file: EvidenceFileRow) -> String {
        if file.maintenanceIssueId != nil {
            if let issue = maintenanceIssues.first(where: { $0.id == file.maintenanceIssueId }) {
                return "\(issue.title) · maintenance photo"
            }
            return uncategorizedEvidenceTitle(for: file, kind: "Maintenance photo")
        }
        guard let property = propertyStore.currentProperty else {
            return uncategorizedEvidenceTitle(for: file)
        }
        for room in property.rooms {
            if let rec = room.evidence.first(where: { $0.photos.contains(where: { $0.id == file.id }) }) {
                return "\(room.name) · \(rec.title)"
            }
            if let rec = room.moveOutEvidence.first(where: { $0.photos.contains(where: { $0.id == file.id }) }) {
                return "\(room.name) · \(rec.title) (move-out)"
            }
        }
        return uncategorizedEvidenceTitle(for: file)
    }

    /// When a file row doesn’t map to hydrated room/issue data, avoid raw storage paths in the UI.
    private func uncategorizedEvidenceTitle(for file: EvidenceFileRow, kind: String = "Uncategorized photo") -> String {
        let raw = file.capturedAt ?? file.createdAt ?? ""
        guard !raw.isEmpty, let date = Self.evidenceCapturedAtISOFormatter.date(from: raw) else {
            return kind
        }
        let dateStr = date.formatted(date: .abbreviated, time: .omitted)
        return "\(kind) · \(dateStr)"
    }

    private func evidencePhotoRowSubtitle(for file: EvidenceFileRow) -> String {
        if file.maintenanceIssueId != nil {
            if let issue = maintenanceIssues.first(where: { $0.id == file.maintenanceIssueId }) {
                let cat = issue.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return cat.isEmpty ? "Maintenance issue" : cat
            }
            return "Maintenance issue"
        }
        guard let property = propertyStore.currentProperty else {
            return evidenceCapturedLabel(for: file)
        }
        for room in property.rooms {
            if room.evidence.contains(where: { $0.photos.contains(where: { $0.id == file.id }) }) {
                return "Move-in · \(evidenceCapturedLabel(for: file))"
            }
            if room.moveOutEvidence.contains(where: { $0.photos.contains(where: { $0.id == file.id }) }) {
                return "Move-out · \(evidenceCapturedLabel(for: file))"
            }
        }
        return evidenceCapturedLabel(for: file)
    }

    private func evidenceCapturedLabel(for file: EvidenceFileRow) -> String {
        let raw = file.capturedAt ?? file.createdAt ?? ""
        guard !raw.isEmpty, let date = Self.evidenceCapturedAtISOFormatter.date(from: raw) else {
            return "Room photo"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func friendlyFileName(_ path: String) -> String {
        let name = path.components(separatedBy: "/").last ?? path
        return name.isEmpty ? "Photo" : name
    }

    private func documentRowTitle(_ doc: PropertyDocumentRow) -> String {
        let name = doc.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return friendlyFileName(doc.filePath)
    }

    private func documentRowSubtitle(_ doc: PropertyDocumentRow) -> String {
        let norm = DocumentRepository.normalizedDocumentType(doc.documentType)
        if let type = VaultDocumentType(rawValue: norm) {
            return type.displayTitle
        }
        if norm.isEmpty { return "Supporting document" }
        return norm.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Selection row model

private struct SelectionRowData: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
}

// MARK: - Selection group

private extension DisputeBuilderView {
    @ViewBuilder
    func selectionGroup(
        title: String,
        count: Int,
        emptyText: String,
        rows: [SelectionRowData],
        selectedIDs: Binding<Set<UUID>>
    ) -> some View {
        DisclosureGroup {
            if rows.isEmpty {
                Text(emptyText)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        Button {
                            if selectedIDs.wrappedValue.contains(row.id) {
                                selectedIDs.wrappedValue.remove(row.id)
                            } else {
                                selectedIDs.wrappedValue.insert(row.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIDs.wrappedValue.contains(row.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.wrappedValue.contains(row.id) ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.textSecondary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.title)
                                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                        .lineLimit(1)

                                    Text(row.subtitle)
                                        .font(MoveMarkTheme.Typography.footnote)
                                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            }
        } label: {
            HStack {
                Text(title)
                    .font(MoveMarkTheme.Typography.bodyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Spacer()
                MMPill(text: "\(count) selected", tone: count == 0 ? .warning : .success)
            }
        }
        .tint(MoveMarkTheme.Colors.textPrimary)
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
