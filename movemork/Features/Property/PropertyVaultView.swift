//
//  PropertyVaultView.swift
//  movemork
//
//  MoveMark — Property command center: hero, rooms, documents, details, actions.
//

import SwiftUI
import PhotosUI
import Supabase

private struct VaultDocumentQuickLookItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let title: String
}

struct PropertyVaultView: View {
    let property: PropertyRecord
    @Binding var path: [AppRoute]
    /// When set, show hero header with matchedGeometryEffect from vault card.
    var namespace: Namespace.ID? = nil
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var uploadSoftNotice: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFilePicker = false
    @State private var pendingFileDocType = ""
    @State private var showEditProperty = false
    @State private var documentRows: [PropertyDocumentRow] = []
    @State private var deleteConfirmType: String? = nil
    @State private var previewErrorMessage: String? = nil
    @State private var lastFailedPhotoDocType: String? = nil
    @State private var lastFailedFileDocType: String? = nil
    @State private var contentVisible = false
    @State private var showReplacePhotoSheet = false
    @State private var pendingPhotoDocType: String? = nil

    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var lastKnownReadinessScore: Int? = nil
    @State private var lastKnownUploadedDocumentCount: Int? = nil
    @State private var lastKnownExportReady: Bool? = nil

    @State private var highlightedDocumentType: VaultDocumentType? = nil
    @State private var pulseExportsTile = false
    @State private var pulseDisputeTile = false
    @State private var pulseQueueHeadRoomId: UUID? = nil
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .disputePacket
    @State private var showAllSupportingRecords = false
    @State private var showPropertyDetails = false
    @State private var documentQuickLook: VaultDocumentQuickLookItem?
    @State private var documentPreviewTempURL: URL?
    @State private var isPreparingDocumentPreview = false
    /// Server-computed vault dashboard; when nil, UI falls back to ``PropertyStore`` (offline / API error).
    @State private var vaultSummary: VaultSummaryResponse?
    @State private var vaultSummaryError: String? = nil

    private let documentRepo = DocumentRepository()

    private static let documentTypeOrder: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot, .cleaningReceipt, .utilityProof, .moveOutInvoice, .other]
    private static let priorityDocumentTypes: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot]

    private var completedRooms: Int {
        if let v = vaultSummary { return v.walkthrough.documentedRooms }
        return propertyStore.documentedRoomCount(for: property)
    }
    private var totalRooms: Int {
        if let v = vaultSummary { return v.walkthrough.totalRooms }
        return propertyStore.totalRoomCount(for: property)
    }
    private var totalPhotos: Int { propertyStore.totalPhotoCount(for: property) }
    private var progress: Double {
        if let v = vaultSummary, v.walkthrough.totalRooms > 0 {
            return Double(v.walkthrough.documentedRooms) / Double(v.walkthrough.totalRooms)
        }
        return propertyStore.roomsCompletionProgress(for: property)
    }
    private var nextRoom: RoomRecord? {
        if let idString = vaultSummary?.walkthrough.nextRoom?.roomId,
           let uuid = UUID(uuidString: idString),
           let match = property.rooms.first(where: { $0.id == uuid }) {
            return match
        }
        return propertyStore.nextRoomToCapture(for: property)
    }
    private var missingRecordsCount: Int {
        if let v = vaultSummary { return v.supportingRecords.missingRequired }
        return propertyStore.missingSupportingRecordCount(for: property)
    }
    private var openIssuesCount: Int {
        if let v = vaultSummary { return v.maintenance.openCount }
        return propertyStore.openIssueCount(for: property)
    }
    private var readinessScore: Int {
        if let v = vaultSummary { return v.readiness.score }
        return propertyStore.readinessScore(for: property)
    }

    private var orderedRooms: [RoomRecord] {
        guard let next = nextRoom else { return property.rooms }
        return property.rooms.sorted { lhs, rhs in
            if lhs.id == next.id { return true }
            if rhs.id == next.id { return false }
            let lhsDone = !lhs.evidence.isEmpty
            let rhsDone = !rhs.evidence.isEmpty
            if lhsDone != rhsDone { return !lhsDone && rhsDone }
            return lhs.name < rhs.name
        }
    }

    private var walkthroughSubtitle: String {
        if let label = vaultSummary?.readiness.primaryNextAction?.label,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }
        if let next = nextRoom, next.evidence.isEmpty {
            return "Open \(next.name) to capture proof"
        }
        if totalRooms == 0 { return "Start documenting the property" }
        return "Review finished rooms"
    }

    private var exportsSubtitle: String {
        propertyStore.isExportReady(for: property)
            ? "Make and share reports"
            : "Add proof before making a report"
    }

    private var vaultProofTrailRows: [MMProofTimelineRow] {
        MMProofTimelineBuilder.vaultTrail(
            property: property,
            nextRoom: nextRoom,
            isExportReady: exportReady
        )
    }

    private var highlightedTrailRowID: String? {
        if let doc = highlightedDocumentType {
            return "doc-\(doc.rawValue)"
        }
        if let roomId = pulseQueueHeadRoomId {
            return "room-\(roomId.uuidString)"
        }
        return nil
    }

    private var uploadedDocumentCount: Int {
        propertyStore.uploadedSupportingRecordCount(for: property)
    }

    private var exportReady: Bool {
        propertyStore.isExportReady(for: property)
    }

    private var missingPriorityDocTypes: [VaultDocumentType] {
        Self.priorityDocumentTypes.filter { !hasDoc($0) }
    }

    var body: some View {
        ZStack {
            MMEmeraldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PropertyVaultHeroStage(
                        property: property,
                        namespace: namespace,
                        heroStatusLine: propertyStore.heroStatusLine(for: property)
                    )
                    .id(property.id)
                    .padding(.bottom, 8)

                    MMDepositProtectionCard(
                        depositDisplay: depositDisplayText,
                        proofScoreLabel: proofScoreLabel,
                        summaryLine: propertyStore.readinessSummaryLine(for: property),
                        roomsLine: "\(completedRooms) of \(totalRooms) rooms · \(totalPhotos) photos"
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 8)
                    .animation(MMMotion.screenTransition.delay(0.05), value: contentVisible)
                    .padding(.bottom, 12)

                    MMProofHeroCard(
                        headline: "\(completedRooms) of \(totalRooms) rooms done",
                        nextLine: readinessGuidanceLine,
                        progress: progress,
                        progressLabel: "\(readinessScore)% proof score",
                        primaryTitle: MMNextBestActionMapper.from(
                            propertyNextAction: propertyStore.primaryNextAction(for: property)
                        ).title,
                        onPrimary: { path.append(.walkthrough) },
                        style: .light
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 8)
                    .animation(MMMotion.screenTransition.delay(0.06), value: contentVisible)
                    .padding(.bottom, 14)

                    if let vaultSummaryError, uploadError == nil {
                        MMErrorBanner(
                            message: vaultSummaryError,
                            onRetry: { Task { await loadVaultSummary() } }
                        )
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 8)
                        .animation(MMMotion.screenTransition.delay(0.06), value: contentVisible)
                        .padding(.bottom, 10)
                    }

                    MMProofTimeline(
                        title: "Proof trail",
                        rows: vaultProofTrailRows,
                        highlightedRowID: highlightedTrailRowID,
                        appeared: contentVisible
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 8)
                    .animation(MMMotion.screenTransition.delay(0.10), value: contentVisible)
                    .padding(.bottom, 14)

                    PropertyVaultRoomQueue(
                        rooms: orderedRooms,
                        nextRoomID: nextRoom?.id,
                        pulseQueueHeadRoomId: pulseQueueHeadRoomId,
                        completedRooms: completedRooms,
                        totalRooms: totalRooms,
                        onSeeAll: { path.append(.walkthrough) },
                        onOpenRoom: { room in path.append(.roomDetail(roomID: room.id)) }
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 8)
                    .animation(MMMotion.screenTransition.delay(0.12), value: contentVisible)
                    .padding(.bottom, 16)

                    documentsSection
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 8)
                        .animation(MMMotion.screenTransition.delay(0.15), value: contentVisible)
                        .padding(.bottom, 16)

                    PropertyVaultSecondaryTools(
                        openIssuesCount: openIssuesCount,
                        completedRooms: completedRooms,
                        readinessScore: readinessScore,
                        exportsSubtitle: exportsSubtitle,
                        pulseDisputeTile: pulseDisputeTile,
                        pulseExportsTile: pulseExportsTile,
                        onMaintenance: { path.append(.maintenance) },
                        onMoveOut: { path.append(.moveOut) },
                        onDisputeBuilder: {
                            if subscriptionManager.canUseCaseBuilder() {
                                path.append(.disputeBuilder)
                            } else {
                                activePaywallReason = .disputePacket
                                showPaywall = true
                            }
                        },
                        onExports: { path.append(.exports) }
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 8)
                    .animation(MMMotion.screenTransition.delay(0.17), value: contentVisible)
                    .padding(.bottom, 18)

                    detailSection(property)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 8)
                        .animation(MMMotion.screenTransition.delay(0.20), value: contentVisible)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 0)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .mmEmeraldBackground()
        .sheet(isPresented: $showEditProperty) {
            NavigationStack {
                EditPropertyView(property: property)
                    .navigationTitle("Edit property")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showEditProperty = false
                            }
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                        }
                    }
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .task(id: property.id) {
            vaultSummaryError = nil
            async let documents: Void = loadDocumentRows()
            async let vault: Void = loadVaultSummary()
            _ = await (documents, vault)
            captureBaselineIfNeeded()
        }
        .onAppear {
            contentVisible = true
            captureBaselineIfNeeded()
            consumePendingVaultFeedbackIfNeeded()
        }
        .onDisappear {
            contentVisible = false
        }
        .alert("Delete document?", isPresented: Binding(get: { deleteConfirmType != nil }, set: { if !$0 { deleteConfirmType = nil } })) {
            Button("Cancel", role: .cancel) {
                deleteConfirmType = nil
            }
            Button("Delete", role: .destructive) {
                if let type = deleteConfirmType {
                    Task { await confirmDeleteDocument(type: type) }
                }
                deleteConfirmType = nil
            }
        } message: {
            Text("This file will be removed from your vault. You can upload again later. This can't be undone.")
        }
        .onChange(of: selectedPhotoItem) { _, new in
            guard let new else { return }
            let docType = pendingPhotoDocType ?? VaultDocumentType.listingScreenshot.rawValue
            handlePhotoSelection(item: new, docType: docType)
            pendingPhotoDocType = nil
            showReplacePhotoSheet = false
        }
        .sheet(isPresented: $showReplacePhotoSheet) {
            ReplacePhotoSheet(
                onDismiss: { showReplacePhotoSheet = false },
                selection: $selectedPhotoItem
            )
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                handleFileSelection(url: url, docType: pendingFileDocType)
            case .failure(let error):
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                MMHaptics.error()
            }
        }
        .fullScreenCover(item: $documentQuickLook, onDismiss: {
            if let url = documentPreviewTempURL {
                try? FileManager.default.removeItem(at: url)
                documentPreviewTempURL = nil
            }
        }) { item in
            NavigationStack {
                QuickLookPreviewRepresentable(url: item.fileURL)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                documentQuickLook = nil
                            }
                        }
                    }
            }
        }
        .overlay {
            if isPreparingDocumentPreview {
                ZStack {
                    MoveMarkTheme.Colors.textPrimary.opacity(0.25).ignoresSafeArea()
                    ProgressView("Opening…")
                        .tint(MoveMarkTheme.Colors.primary)
                }
            }
        }
    }

    private var depositDisplayText: String {
        let raw = property.depositAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "Deposit protection" }
        if raw.hasPrefix("$") { return raw }
        return "$\(raw)"
    }

    private var proofScoreLabel: String {
        if readinessScore >= 70 { return "Strong proof" }
        if readinessScore >= 40 { return "Building proof" }
        return "Early proof"
    }

    private var readinessGuidanceLine: String {
        if let label = vaultSummary?.readiness.primaryNextAction?.label,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }
        if totalRooms == 0 {
            return "Start by adding rooms, then capture move-in proof."
        }
        if completedRooms < totalRooms {
            return "Finish the rooms that are still missing photos."
        }
        if missingRecordsCount > 0 {
            return "Add receipts & lease docs to finish your proof."
        }
        return "Your proof looks strong. Keep docs up to date."
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Receipts & lease docs")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .textCase(.uppercase)

                    Text("Lease, deposit receipt, and other papers.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.86))
                }

                Spacer()

                Text("\(propertyStore.uploadedSupportingRecordCount(for: property)) of \(Self.documentTypeOrder.count) uploaded")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.56))
            }

            if let uploadError {
                MMErrorBanner(
                    message: uploadError,
                    retryTitle: MMCopy.tryAgain,
                    onRetry: retryDocumentUpload
                )
            }

            if let uploadSoftNotice, uploadError == nil {
                MMCard(tone: .quiet, padding: 14, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.9))
                        Text(uploadSoftNotice)
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    }
                }
            }

            if let previewErrorMessage {
                MMErrorBanner(message: previewErrorMessage)
            }

            if showAllSupportingRecords {
                VStack(spacing: 0) {
                    ForEach(Self.documentTypeOrder, id: \.self) { docType in
                        supportingRecordRow(for: docType)

                        if let last = Self.documentTypeOrder.last, docType != last {
                            Divider()
                                .background(MoveMarkTheme.Colors.divider.opacity(0.22))
                                .padding(.leading, 54)
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllSupportingRecords = false
                    }
                } label: {
                    Text("Collapse records")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(missingPriorityDocTypes.prefix(3), id: \.self) { docType in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(docType.displayTitle)
                                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                Text(recordSubtitle(for: docType, isPresent: false))
                                    .font(MoveMarkTheme.Typography.footnote)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Button {
                                startUpload(for: docType)
                            } label: {
                                recordActionButton(title: "Upload")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllSupportingRecords = true
                        }
                    } label: {
                        Text("See all records")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoveMarkTheme.Colors.surfaceInset.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.52), lineWidth: 0.5)
        )
    }

    private func recordSubtitle(for docType: VaultDocumentType, isPresent: Bool) -> String {
        switch docType {
        case .lease:
            return isPresent ? "Tenancy agreement attached" : "Tenancy agreement"
        case .depositReceipt:
            return isPresent ? "Payment proof attached" : "Payment proof"
        case .listingScreenshot:
            return isPresent ? "Original listing attached" : "Original listing"
        case .cleaningReceipt:
            return isPresent ? "Cleaning proof attached" : "Cleaning proof"
        case .utilityProof:
            return isPresent ? "Utility record attached" : "Utility record"
        case .moveOutInvoice:
            return isPresent ? "Move-out cost attached" : "Move-out cost"
        case .other:
            return isPresent ? "Additional proof attached" : "Additional proof"
        }
    }

    private func recordActionButton(title: String, isBusy: Bool = false) -> some View {
        Text(isBusy ? "Saving…" : title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(MoveMarkTheme.Colors.mint.opacity(0.55))
            .overlay(
                Capsule()
                    .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.55), lineWidth: 0.8)
            )
            .clipShape(Capsule())
    }

    private func supportingRecordRow(for docType: VaultDocumentType) -> some View {
        let present = hasDoc(docType)
        let isHighlighted = highlightedDocumentType == docType

        return SupportingRecordRow(
            title: docType.displayTitle,
            subtitle: recordSubtitle(for: docType, isPresent: present),
            isPresent: present
        ) {
            if present {
                Button {
                    Task { await previewDocument(type: docType) }
                } label: {
                    recordActionButton(title: "View")
                }
                .contextMenu {
                    if docType.acceptsImage {
                        Button("Replace with photo") {
                            pendingPhotoDocType = docType.rawValue
                            showReplacePhotoSheet = true
                        }
                    } else {
                        Button("Replace") {
                            pendingFileDocType = docType.rawValue
                            showFilePicker = true
                        }
                    }

                    Button("Delete", role: .destructive) {
                        deleteConfirmType = docType.rawValue
                    }
                }
            } else {
                if docType.acceptsImage {
                    Button {
                        pendingPhotoDocType = docType.rawValue
                        showReplacePhotoSheet = true
                    } label: {
                        recordActionButton(title: "Add", isBusy: isUploading)
                    }
                    .disabled(isUploading)
                } else {
                    Button {
                        pendingFileDocType = docType.rawValue
                        showFilePicker = true
                    } label: {
                        recordActionButton(title: "Add")
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isHighlighted
                        ? MoveMarkTheme.Colors.primary.opacity(0.10)
                        : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isHighlighted
                        ? MoveMarkTheme.Colors.primary.opacity(0.18)
                        : Color.clear,
                    lineWidth: 0.8
                )
        )
        .animation(.easeInOut(duration: 0.22), value: isHighlighted)
    }

    private func detailSection(_ property: PropertyRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Property details")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Button("Edit") {
                    showEditProperty = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPropertyDetails.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(showPropertyDetails ? "Hide details" : "Show details")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    Image(systemName: showPropertyDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if showPropertyDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tenancy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))

                    VStack(spacing: 10) {
                        detailRow("Move-in", property.moveInDate.formatted(date: .abbreviated, time: .omitted))

                        if let start = property.leaseStartDate {
                            detailRow("Lease start", start.formatted(date: .abbreviated, time: .omitted))
                        }

                        detailRow("Lease end", property.leaseEndDate.formatted(date: .abbreviated, time: .omitted))

                        if !property.depositAmount.isEmpty {
                            detailRow("Deposit", property.depositAmount)
                        }

                        if !property.rentAmount.isEmpty {
                            detailRow("Rent", property.rentAmount)
                        }
                    }
                }

                Divider()
                    .background(MoveMarkTheme.Colors.divider.opacity(0.22))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Contact")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))

                    VStack(spacing: 10) {
                        detailRow("Landlord", property.landlordName.isEmpty ? "Not added" : property.landlordName)
                        detailRow("Email", property.landlordEmail.isEmpty ? "Not added" : property.landlordEmail)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoveMarkTheme.Colors.panel.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.48), lineWidth: 0.5)
        )
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.96))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private func showFeedback(_ event: VaultFeedbackEvent) {
        let toast = MMProofToastMessage.fromVaultFeedback(event)
        MMProofToastPresenter.show(
            toast,
            message: $proofToast,
            isVisible: $proofToastVisible
        )
    }

    private func consumePendingVaultFeedbackIfNeeded() {
        guard let event = propertyStore.pendingVaultFeedback else { return }
        propertyStore.pendingVaultFeedback = nil
        showFeedback(event)

        let shouldPulseNextRoom: Bool = {
            switch event {
            case .roomCompleted, .moveOutRoomCompleted:
                return true
            default:
                return false
            }
        }()
        if shouldPulseNextRoom, let nextId = nextRoom?.id {
            pulseQueueHeadRoomId = nextId
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.24)) {
                    pulseQueueHeadRoomId = nil
                }
            }
        }
    }

    private func captureBaselineIfNeeded() {
        if lastKnownReadinessScore == nil {
            lastKnownReadinessScore = readinessScore
        }
        if lastKnownUploadedDocumentCount == nil {
            lastKnownUploadedDocumentCount = uploadedDocumentCount
        }
        if lastKnownExportReady == nil {
            lastKnownExportReady = exportReady
        }
    }

    /// Keeps workflow toasts / highlights accurate after deletes (upload path already updates via `evaluateWorkflowFeedback`).
    private func refreshWorkflowBaseline() {
        let prop = (propertyStore.currentProperty?.id == property.id) ? propertyStore.currentProperty! : property
        lastKnownReadinessScore = propertyStore.readinessScore(for: prop)
        lastKnownUploadedDocumentCount = propertyStore.uploadedSupportingRecordCount(for: prop)
        lastKnownExportReady = propertyStore.isExportReady(for: prop)
    }

    private func triggerDocumentHighlight(_ docType: VaultDocumentType) {
        highlightedDocumentType = docType

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if highlightedDocumentType == docType {
                withAnimation(.easeOut(duration: 0.22)) {
                    highlightedDocumentType = nil
                }
            }
        }
    }

    private func triggerExportsPulse() {
        withAnimation(.easeInOut(duration: 0.22)) {
            pulseExportsTile = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.24)) {
                pulseExportsTile = false
            }
        }
    }

    private func triggerDisputePulse() {
        withAnimation(.easeInOut(duration: 0.22)) {
            pulseDisputeTile = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.24)) {
                pulseDisputeTile = false
            }
        }
    }

    /// Evaluate after an action (e.g. upload). Uses store's current property when matching so state is fresh. Shows one toast per run; drives row highlight and tile pulses.
    private func evaluateWorkflowFeedback(
        documentName: String? = nil,
        documentType: VaultDocumentType? = nil
    ) {
        let prop = (propertyStore.currentProperty?.id == property.id) ? propertyStore.currentProperty! : property
        let previousReadiness = lastKnownReadinessScore ?? propertyStore.readinessScore(for: prop)
        let previousDocumentCount = lastKnownUploadedDocumentCount ?? propertyStore.uploadedSupportingRecordCount(for: prop)
        let previousExportReady = lastKnownExportReady ?? propertyStore.isExportReady(for: prop)

        let newReadiness = propertyStore.readinessScore(for: prop)
        let newDocumentCount = propertyStore.uploadedSupportingRecordCount(for: prop)
        let newExportReady = propertyStore.isExportReady(for: prop)

        if let documentType, newDocumentCount > previousDocumentCount {
            triggerDocumentHighlight(documentType)
        }

        if previousExportReady == false && newExportReady == true {
            triggerExportsPulse()
        }

        let crossedIntoStrongerReadinessBand =
            (previousReadiness < 40 && newReadiness >= 40) ||
            (previousReadiness < 70 && newReadiness >= 70)

        if crossedIntoStrongerReadinessBand {
            triggerDisputePulse()
        }

        if previousExportReady == false && newExportReady == true {
            MMHaptics.success()
            showFeedback(.exportsUnlocked)
        } else if newReadiness > previousReadiness {
            MMHaptics.success()
            showFeedback(.readinessImproved(oldScore: previousReadiness, newScore: newReadiness))
        } else if let documentName, newDocumentCount > previousDocumentCount {
            MMHaptics.success()
            showFeedback(.documentUploaded(documentName: documentName))
        }

        lastKnownReadinessScore = newReadiness
        lastKnownUploadedDocumentCount = newDocumentCount
        lastKnownExportReady = newExportReady

        Task { await loadVaultSummary() }
    }

    private func docRow(for documentType: String) -> PropertyDocumentRow? {
        let keys = Set(DocumentRepository.documentTypeQueryKeys(documentType))
        return documentRows.first { keys.contains($0.documentType) }
    }

    private func hasDoc(_ type: VaultDocumentType) -> Bool {
        let keys = DocumentRepository.documentTypeQueryKeys(type.rawValue)
        return keys.contains { property.vaultDocuments.contains($0) }
    }

    private func hasVaultDocMatching(_ docType: String) -> Bool {
        let keys = DocumentRepository.documentTypeQueryKeys(docType)
        return keys.contains { property.vaultDocuments.contains($0) }
    }

    private func startUpload(for docType: VaultDocumentType) {
        if docType.acceptsImage {
            pendingPhotoDocType = docType.rawValue
            showReplacePhotoSheet = true
        } else {
            pendingFileDocType = docType.rawValue
            showFilePicker = true
        }
    }

    private func loadDocumentRows() async {
        do {
            documentRows = try await documentRepo.fetchDocuments(propertyId: property.id)
        } catch {
            documentRows = []
        }
    }

    /// Fetches server-side vault summary (rooms, docs, maintenance, readiness, exports/dispute flags). Fails silently and keeps local store UI when the API is unavailable.
    private func loadVaultSummary() async {
        guard
            let base = Bundle.main.object(forInfoDictionaryKey: "MoveMarkAPIBaseURL") as? String,
            !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        do {
            let session = try await supabase.auth.session
            let client = try ExportAPIClient(baseURLString: base)
            let summary = try await client.fetchVaultSummary(
                propertyId: property.id,
                accessToken: session.accessToken,
                includeExports: true,
                includeDispute: true
            )
            vaultSummary = summary
            vaultSummaryError = nil
        } catch {
            vaultSummary = nil
            vaultSummaryError = MoveMarkFlowMessage.vaultSummaryRefreshFailed
        }
    }

    /// Re-fetch rows after upload without wiping the list on failure (avoids “everything disappeared” after a successful upload).
    private func refreshDocumentRowsAfterMutation() async -> Bool {
        do {
            documentRows = try await documentRepo.fetchDocuments(propertyId: property.id)
            return true
        } catch {
            return false
        }
    }

    /// If the refetch omits a row we just inserted (read-after-write lag) or failed, merge the known-good row so preview / View work immediately.
    private func reconcileDocumentRows(anchoring expected: PropertyDocumentRow) {
        if documentRows.contains(where: { $0.id == expected.id }) { return }
        let slotKeys = Set(DocumentRepository.documentTypeQueryKeys(expected.documentType))
        let withoutSlot = documentRows.filter { !slotKeys.contains($0.documentType) }
        documentRows = [expected] + withoutSlot
    }

    private func previewDocument(type: VaultDocumentType) async {
        previewErrorMessage = nil
        uploadError = nil
        guard let row = docRow(for: type.rawValue) else {
            previewErrorMessage = MoveMarkFlowMessage.documentPreviewMissing
            return
        }
        await MainActor.run { isPreparingDocumentPreview = true }
        do {
            let remoteURL = try await documentRepo.signedURL(
                bucket: DocumentRepository.storageBucket(forDocumentType: row.documentType),
                path: row.filePath
            )
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let ext = preferredPreviewFileExtension(for: row, docType: type)
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("vault-doc-\(UUID().uuidString)", isDirectory: false)
                .appendingPathExtension(ext)
            try data.write(to: temp, options: .atomic)
            await MainActor.run {
                if let old = documentPreviewTempURL {
                    try? FileManager.default.removeItem(at: old)
                }
                documentPreviewTempURL = temp
                documentQuickLook = VaultDocumentQuickLookItem(fileURL: temp, title: type.displayTitle)
            }
        } catch {
            await MainActor.run {
                previewErrorMessage = MoveMarkFlowMessage.documentPreviewFailed(error)
            }
        }
        await MainActor.run { isPreparingDocumentPreview = false }
    }

    private func preferredPreviewFileExtension(for row: PropertyDocumentRow, docType: VaultDocumentType) -> String {
        let fromName = (row.fileName as NSString).pathExtension.lowercased()
        if !fromName.isEmpty { return fromName }
        let fromPath = (row.filePath as NSString).pathExtension.lowercased()
        if !fromPath.isEmpty { return fromPath }
        switch docType {
        case .listingScreenshot:
            return "jpg"
        default:
            return "pdf"
        }
    }

    private func confirmDeleteDocument(type: String) async {
        let slotKeys = Set(DocumentRepository.documentTypeQueryKeys(type))
        do {
            try await documentRepo.deleteDocuments(propertyId: property.id, documentType: type)
            documentRows.removeAll { slotKeys.contains($0.documentType) }
            previewErrorMessage = nil
            let metaOK = await propertyStore.refreshDocuments(propertyId: property.id)
            let rowsOK = await refreshDocumentRowsAfterMutation()
            uploadSoftNotice = nil
            uploadError = nil
            if !metaOK || !rowsOK {
                uploadSoftNotice = MoveMarkFlowMessage.documentVaultRefreshHint
            }
            refreshWorkflowBaseline()
            await loadVaultSummary()
        } catch {
            uploadError = MoveMarkFlowMessage.documentDeleteFailed(error)
        }
    }

    private func retryDocumentUpload() {
        uploadSoftNotice = nil
        if let docType = lastFailedPhotoDocType, let item = selectedPhotoItem {
            uploadError = nil
            handlePhotoSelection(item: item, docType: docType)
            return
        }
        if let docType = lastFailedFileDocType {
            uploadError = nil
            pendingFileDocType = docType
            showFilePicker = true
        }
    }

    private func handlePhotoSelection(item: PhotosPickerItem, docType: String) {
        guard let userId = sessionManager.userId else { return }
        uploadError = nil
        uploadSoftNotice = nil
        previewErrorMessage = nil
        lastFailedPhotoDocType = docType
        isUploading = true

        Task { @MainActor in
            defer { isUploading = false }
            let canonicalType = DocumentRepository.normalizedDocumentType(docType)
            do {
                if hasVaultDocMatching(docType) {
                    try await documentRepo.deleteDocuments(propertyId: property.id, documentType: docType)
                }
            } catch {
                uploadError = MoveMarkFlowMessage.documentDeleteFailed(error)
                return
            }

            guard let data = try? await item.loadTransferable(type: Data.self) else {
                uploadError = MoveMarkFlowMessage.documentImageReadFailed
                return
            }
            let compressed: Data
            if let image = UIImage(data: data) {
                compressed = image.jpegData(compressionQuality: 0.82) ?? data
            } else {
                compressed = data
            }
            let fileName = "\(UUID()).jpg"
            let path = "\(userId)/\(property.id)/\(canonicalType)/\(fileName)"
            let targetBucket = DocumentRepository.storageBucket(forDocumentType: canonicalType)

            do {
                _ = try await documentRepo.uploadDocument(data: compressed, bucket: targetBucket, path: path)
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                return
            }

            let row = PropertyDocumentRow(
                id: UUID(),
                propertyId: property.id,
                userId: userId,
                documentType: canonicalType,
                filePath: path,
                fileName: fileName,
                uploadedAt: nil,
                metadata: nil
            )
            do {
                try await documentRepo.insertDocumentRecord(row)
            } catch {
                await documentRepo.removeStaleUpload(documentType: canonicalType, path: path)
                uploadError = MoveMarkFlowMessage.documentRecordCreateFailed(error)
                return
            }

            let metaOK = await propertyStore.refreshDocuments(propertyId: property.id)
            let rowsOK = await refreshDocumentRowsAfterMutation()
            reconcileDocumentRows(anchoring: row)
            propertyStore.ensureVaultDocumentTypePresent(propertyId: property.id, documentType: canonicalType)
            if !metaOK || !rowsOK {
                uploadSoftNotice = MoveMarkFlowMessage.documentVaultRefreshHint
            }

            if let type = VaultDocumentType(rawValue: canonicalType) {
                evaluateWorkflowFeedback(
                    documentName: type.displayTitle,
                    documentType: type
                )
            } else {
                evaluateWorkflowFeedback(documentName: "Document")
            }

            uploadError = nil
            lastFailedPhotoDocType = nil
            selectedPhotoItem = nil
        }
    }

    private func handleFileSelection(url: URL, docType: String) {
        guard let userId = sessionManager.userId else { return }
        uploadError = nil
        uploadSoftNotice = nil
        previewErrorMessage = nil
        lastFailedFileDocType = nil
        isUploading = true

        Task { @MainActor in
            defer { isUploading = false }
            let canonicalType = DocumentRepository.normalizedDocumentType(docType)
            do {
                if hasVaultDocMatching(docType) {
                    try await documentRepo.deleteDocuments(propertyId: property.id, documentType: docType)
                }
            } catch {
                uploadError = MoveMarkFlowMessage.documentDeleteFailed(error)
                lastFailedFileDocType = docType
                return
            }

            guard url.startAccessingSecurityScopedResource() else {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(
                    NSError(domain: "MoveMark.Vault", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not access the selected file. Try again or pick a different file."
                    ])
                )
                lastFailedFileDocType = docType
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                lastFailedFileDocType = docType
                return
            }

            let fileName = url.lastPathComponent
            let path = "\(userId)/\(property.id)/\(canonicalType)/\(UUID().uuidString)-\(fileName)"
            let targetBucket = DocumentRepository.storageBucket(forDocumentType: canonicalType)

            do {
                _ = try await documentRepo.uploadDocument(data: data, bucket: targetBucket, path: path)
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                lastFailedFileDocType = docType
                return
            }

            let row = PropertyDocumentRow(
                id: UUID(),
                propertyId: property.id,
                userId: userId,
                documentType: canonicalType,
                filePath: path,
                fileName: fileName,
                uploadedAt: nil,
                metadata: nil
            )
            do {
                try await documentRepo.insertDocumentRecord(row)
            } catch {
                await documentRepo.removeStaleUpload(documentType: canonicalType, path: path)
                uploadError = MoveMarkFlowMessage.documentRecordCreateFailed(error)
                lastFailedFileDocType = docType
                return
            }

            let metaOK = await propertyStore.refreshDocuments(propertyId: property.id)
            let rowsOK = await refreshDocumentRowsAfterMutation()
            reconcileDocumentRows(anchoring: row)
            propertyStore.ensureVaultDocumentTypePresent(propertyId: property.id, documentType: canonicalType)
            if !metaOK || !rowsOK {
                uploadSoftNotice = MoveMarkFlowMessage.documentVaultRefreshHint
            }

            if let type = VaultDocumentType(rawValue: canonicalType) {
                evaluateWorkflowFeedback(
                    documentName: type.displayTitle,
                    documentType: type
                )
            } else {
                evaluateWorkflowFeedback(documentName: "Document")
            }

            uploadError = nil
            lastFailedFileDocType = nil
        }
    }
}

// MARK: - Replace photo sheet (for image doc types)

private struct ReplacePhotoSheet: View {
    let onDismiss: () -> Void
    @Binding var selection: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("Choose photo", systemImage: "photo.on.rectangle.angled")
                        .font(MoveMarkTheme.Typography.button)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(MoveMarkTheme.Colors.fieldFill)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button("Cancel") { onDismiss() }
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
            .padding(24)
            .navigationTitle("Replace with photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }
            }
        }
    }
}
