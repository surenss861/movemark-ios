//
//  ExportHistoryView.swift
//  movemork
//
//  MoveMark — Reports: loads the rental's exports, keeps their status current, and owns the secure
//  report flow (authenticated download → local PDF → native preview / share). ``ReportsHomeView`` draws it.
//

import SwiftUI

struct ExportHistoryView: View {
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible
    @Environment(\.dismiss) private var dismiss

    private struct ReportPreviewItem: Identifiable {
        let id = UUID()
        let fileURL: URL
        let title: String
        let exportType: String
    }

    var showOpenVaultsCTA: Bool = false
    var onOpenVaults: (() -> Void)? = nil
    var onContinueRoomProof: (() -> Void)? = nil
    var onOpenMoveOutProof: (() -> Void)? = nil
    /// The dispute row opens the evidence packet builder, which generates, views and shares the packet.
    var onOpenDisputePacket: (() -> Void)? = nil

    @State private var exports: [ExportRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var reportPreviewItem: ReportPreviewItem?
    @State private var isDownloadingReport = false
    @State private var verificationStatus: [UUID: ExportVerificationStatus] = [:]
    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var lastReportReadiness: MMNextBestActionMapper.ReportReadiness? = nil
    @State private var isExporting = false
    @State private var isMoveOutExporting = false
    @State private var isDisputeExporting = false
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .unlimitedExports
    /// A ready move-out report or dispute packet: view, share, or generate a new one.
    @State private var otherReportMenu: ReportsHomeModel.OtherReport?

    // MARK: - Export status (polled while a report is queued or processing)

    private var apiBaseURL: String? { MoveMarkBackendConfig.apiBaseURLString }

    /// Prefer hydrated `currentProperty`; fall back to persisted `activePropertyId` so Exports matches Vault when hydration lags or the vault tab is not mounted.
    private var resolvedExportPropertyId: UUID? {
        if let id = propertyStore.currentProperty?.id { return id }
        if let aid = propertyStore.activePropertyId,
           propertyStore.properties.contains(where: { $0.id == aid }) {
            return aid
        }
        return nil
    }

    private var hasActiveVault: Bool {
        resolvedExportPropertyId != nil
    }

    private var activeVaultDisplayTitle: String? {
        guard let pid = resolvedExportPropertyId else { return nil }
        if let cp = propertyStore.currentProperty, cp.id == pid {
            let t = cp.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : cp.title
        }
        guard let row = propertyStore.properties.first(where: { $0.id == pid }) else { return nil }
        let t = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : row.title
    }

    /// Hydrated vault only — same source as ``PropertyStore.isExportReady(for:)``.
    private var resolvedPropertyRecord: PropertyRecord? {
        guard let pid = resolvedExportPropertyId,
              let cp = propertyStore.currentProperty, cp.id == pid else { return nil }
        return cp
    }

    /// `nil` when the active vault isn’t hydrated yet (e.g. only `activePropertyId`); then we don’t block the “no exports yet” path.
    private var isExportReadyForResolvedVault: Bool? {
        guard let p = resolvedPropertyRecord else { return nil }
        return propertyStore.isExportReady(for: p)
    }

    var body: some View {
        ReportsHomeView(
            model: reportsModel,
            onPrimary: performPrimaryAction,
            onShare: { if let row = latestReadyRow(of: ["move_in_report"]) { share(row) } },
            onViewLastReport: { if let row = latestReadyRow(of: ["move_in_report"]) { viewReport(row) } },
            onHistory: { item, action in
                guard let row = exports.first(where: { $0.id == item.id }) else { return }
                switch action {
                case .view: viewReport(row)
                case .share: share(row)
                case .retry: retryExport(row)
                }
            },
            onOther: openOtherReport,
            onRetry: { Task { await loadExports() } }
        )
        .refreshable {
            await loadExports()
        }
        // At the root the dark header runs under the status bar; pushed (from a saved room's receipt), the
        // back button sits on the same dark band.
        .toolbar(rootTabBarVisible ? .hidden : .automatic, for: .navigationBar)
        .toolbarBackground(ReportsHomeView.headerColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .onChange(of: reportReadinessSnapshot) { _, _ in
            handleReportReadinessChange()
        }
        .onAppear {
            lastReportReadiness = currentReportReadiness
        }
        .confirmationDialog(
            otherReportMenu?.title ?? "",
            isPresented: Binding(get: { otherReportMenu != nil }, set: { if !$0 { otherReportMenu = nil } }),
            titleVisibility: .visible,
            presenting: otherReportMenu
        ) { other in
            let types = Self.exportTypes(forOther: other.id)
            Button("View report") { if let row = latestReadyRow(of: types) { viewReport(row) } }
            Button("Share") { if let row = latestReadyRow(of: types) { share(row) } }
            Button(other.id == Self.moveOutID ? "Generate new report" : "Generate new packet") {
                if other.id == Self.moveOutID { requestMoveOutExport() } else { requestDisputePacketExport() }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ReportPDFShareSheet(activityItems: shareItems)
            }
        }
        .fullScreenCover(item: $reportPreviewItem) { item in
            NavigationStack {
                QuickLookPreviewRepresentable(url: item.fileURL)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                reportPreviewItem = nil
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button("Share") {
                                shareCachedReport(at: item.fileURL, exportType: item.exportType)
                            }
                        }
                    }
            }
        }
        .overlay {
            if isDownloadingReport {
                ZStack {
                    MoveMarkTheme.Colors.textPrimary.opacity(0.25).ignoresSafeArea()
                    ProgressView("Opening report…")
                        .tint(MoveMarkTheme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .task(id: resolvedExportPropertyId) {
            await loadExports()
            await pollActiveExportsWhileNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveMarkExportsShouldRefresh)) { _ in
            Task {
                await loadExports()
                await pollActiveExportsWhileNeeded()
            }
        }
    }

    // MARK: - What Reports shows

    private static let moveOutID = "move_out"
    private static let disputeID = "dispute"

    private static func exportTypes(forOther id: String) -> Set<String> {
        id == moveOutID ? ["move_out_report"] : ["dispute_packet", "dispute_summary"]
    }

    private var reportsModel: ReportsHomeModel {
        var model = ReportsHomeModel(rentalName: activeVaultDisplayTitle ?? "Your rental", primary: primaryState)
        if let property = resolvedPropertyRecord {
            model.documented = propertyStore.documentedRoomCount(for: property)
            model.totalRooms = propertyStore.totalRoomCount(for: property)
            model.photos = propertyStore.totalPhotoCount(for: property)
            model.records = propertyStore.uploadedSupportingRecordCount(for: property)
            model.issues = propertyStore.openIssueCount(for: property)
        }
        model.primaryTitle = primaryTitle
        model.history = historyItems
        model.others = hasActiveVault ? otherReports : []
        model.errorMessage = errorMessage
        return model
    }

    /// Move-in exports, newest first.
    private var moveInRows: [ExportRow] {
        exports.filter { $0.exportType == "move_in_report" }
            .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
    }

    private func latestReadyRow(of types: Set<String>) -> ExportRow? {
        exports.filter { types.contains($0.exportType) && verificationStatus[$0.id] == .ready }
            .max { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
    }

    /// The move-in report's state, from its newest attempt: an older failure never hides a newer report,
    /// and a newer failure keeps the last good report openable.
    private var primaryState: ReportsHomeModel.Primary {
        guard hasActiveVault else { return isLoading ? .loading : .noRental }
        if isExporting { return .generating }
        guard let latest = moveInRows.first else {
            if isLoading { return .loading }
            if isExportReadyForResolvedVault == true { return .canGenerate }
            // Same rule as ``PropertyStore.isExportReady(for:)``: a documented room and one supporting record.
            if let property = resolvedPropertyRecord, propertyStore.documentedRoomCount(for: property) > 0 {
                return .needsProof(.record)
            }
            return .needsProof(.rooms)
        }
        switch verificationStatus[latest.id] ?? .unknown {
        case .queued, .processing, .verifying:
            return .generating
        case .serverFailed, .missingPath:
            return .failed(lastReadyAt: parsedDate(latestReadyRow(of: ["move_in_report"])?.createdAt))
        case .unknown:
            return .loading
        case .ready, .invalidURL, .verificationFailed:
            // A download problem is reported in the error row; the report itself exists.
            return .ready(generatedAt: parsedDate(latest.createdAt))
        }
    }

    private var primaryTitle: String {
        switch primaryState {
        case .noRental: return "Go to Proof"
        case .needsProof(.rooms): return "Continue room proof"
        case .needsProof(.record): return "Add a record"
        case .canGenerate:
            return subscriptionManager.canExportMoveIn(forUser: sessionManager.userId)
                ? "Generate report" : "Upgrade for another report"
        default: return "Generate report"
        }
    }

    private func performPrimaryAction() {
        switch primaryState {
        case .noRental:
            openProof()
        case .needsProof(.rooms):
            if let onContinueRoomProof { onContinueRoomProof() } else { openProof() }
        case .needsProof(.record):
            // Records are added from Proof's next actions (lease, deposit receipt, listing).
            openProof()
        case .canGenerate:
            if subscriptionManager.canExportMoveIn(forUser: sessionManager.userId) {
                requestMoveInExport()
            } else {
                activePaywallReason = .unlimitedExports
                showPaywall = true
            }
        case .ready:
            if let row = latestReadyRow(of: ["move_in_report"]) { viewReport(row) }
        case .failed:
            if let row = moveInRows.first { retryExport(row) }
        case .loading, .generating:
            break
        }
    }

    /// The Proof tab at the root; pushed (over Proof), back to it.
    private func openProof() {
        if let onOpenVaults { onOpenVaults() } else { dismiss() }
    }

    private var historyItems: [ReportsHomeModel.HistoryItem] {
        let sorted = exports.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        var seenTypes: Set<String> = []
        return sorted.map { row in
            let family = row.exportType == "dispute_summary" ? "dispute_packet" : row.exportType
            let isNewestOfType = seenTypes.insert(family).inserted
            let status: ReportsHomeModel.HistoryItem.Status = switch verificationStatus[row.id] ?? .unknown {
            case .ready, .verificationFailed, .invalidURL: .ready
            case .queued, .processing, .verifying, .unknown: .generating
            case .serverFailed: .failed
            case .missingPath: .unavailable
            }
            return ReportsHomeModel.HistoryItem(
                id: row.id,
                title: label(for: row.exportType),
                date: parsedDate(row.createdAt),
                status: status,
                canRetry: status == .failed && isNewestOfType
            )
        }
    }

    private var otherReports: [ReportsHomeModel.OtherReport] {
        let hasPro = subscriptionManager.hasPro
        return [
            ReportsHomeModel.OtherReport(
                id: Self.moveOutID,
                title: "Move-out report",
                detail: hasPro ? otherDetail(moveOutReadiness, types: ["move_out_report"], noProof: "Not started")
                    : "Re-capture rooms before you return the keys.",
                isProLocked: !hasPro,
                isGenerating: hasPro && (moveOutReadiness == .processing || isMoveOutExporting)
            ),
            ReportsHomeModel.OtherReport(
                id: Self.disputeID,
                title: "Dispute packet",
                detail: hasPro ? otherDetail(disputeReadiness, types: ["dispute_packet", "dispute_summary"], noProof: "Needs move-in proof")
                    : "Bundle your proof if your deposit is questioned.",
                isProLocked: !hasPro,
                isGenerating: hasPro && (disputeReadiness == .processing || isDisputeExporting)
            ),
        ]
    }

    private func otherDetail(_ readiness: SecondaryReportReadiness, types: Set<String>, noProof: String) -> String {
        switch readiness {
        case .noProof: return noProof
        case .readyToMake: return "Ready to generate"
        case .processing: return "Generating…"
        case .failed: return "Couldn't generate · Tap to retry"
        case .readyToShare:
            guard let date = parsedDate(latestReadyRow(of: types)?.createdAt) else { return "Ready" }
            return "Ready · \(ReportsHomeView.stamp(date))"
        }
    }

    private func openOtherReport(_ other: ReportsHomeModel.OtherReport) {
        let isMoveOut = other.id == Self.moveOutID
        if !isMoveOut, let onOpenDisputePacket {
            onOpenDisputePacket()
            return
        }
        if subscriptionManager.hasPro, (isMoveOut ? moveOutReadiness : disputeReadiness) == .readyToShare {
            otherReportMenu = other
            return
        }
        let cta = isMoveOut ? moveOutPrimaryCTA : disputePrimaryCTA
        if cta.enabled { cta.action() }
    }

    /// Polls while any export is queued/processing, so a finished or failed report shows up without a
    /// manual refresh. (There is no push channel on the Neon backend; the worker usually finishes within
    /// seconds.)
    private func pollActiveExportsWhileNeeded() async {
        let intervalNanos: UInt64 = 2_500_000_000

        for _ in 0..<40 {
            let hasActive = verificationStatus.values.contains { status in
                switch status {
                case .queued, .processing, .verifying:
                    return true
                default:
                    return false
                }
            }
            guard hasActive else { return }
            try? await Task.sleep(nanoseconds: intervalNanos)
            await loadExportsQuietly()
        }
    }

    private func loadExportsQuietly() async {
        guard let apiClient = try? makeAPIClient() else { return }
        guard let currentPropertyId = resolvedExportPropertyId else { return }
        do {
            let items = try await apiClient.fetchExports(propertyId: currentPropertyId)
            var nextVerification: [UUID: ExportVerificationStatus] = [:]
            for item in items {
                switch item.status {
                case .queued:
                    nextVerification[item.id] = .queued
                case .processing:
                    nextVerification[item.id] = .processing
                case .failed:
                    nextVerification[item.id] = .serverFailed
                case .completed:
                    let fp = (item.filePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    nextVerification[item.id] = fp.isEmpty ? .missingPath : .ready
                }
            }
            exports = items.map { item in
                ExportRow(
                    id: item.id,
                    disputeId: nil,
                    propertyId: item.propertyId,
                    userId: item.userId,
                    exportType: item.type,
                    filePath: item.filePath,
                    createdAt: item.requestedAt ?? item.createdAt
                )
            }
            verificationStatus = nextVerification
        } catch {
            // Quiet poll — keep existing list; user can pull to refresh.
        }
    }

    /// Drives readiness transitions (unlock haptic + toast).
    private var reportReadinessSnapshot: String {
        "\(hasActiveVault)-\(isExportReadyForResolvedVault.map { $0 ? 1 : 0 } ?? -1)-\(exports.count)-\(readinessPillText)"
    }

    private var currentReportReadiness: MMNextBestActionMapper.ReportReadiness {
        MMNextBestActionMapper.reportReadiness(
            hasVault: hasActiveVault,
            isExportReady: isExportReadyForResolvedVault,
            hasReadyExport: exports.contains { verificationStatus[$0.id] == .ready },
            isProcessing: readinessPillText == "Processing" || readinessPillText == "Loading",
            isFailed: readinessPillText == "Failed"
        )
    }

    private func handleReportReadinessChange() {
        let readiness = currentReportReadiness
        defer { lastReportReadiness = readiness }

        guard let previous = lastReportReadiness else { return }

        if previous == .notReady, readiness == .readyToMake {
            MMHaptics.medium()
            presentProofToast(.exportsUnlocked())
        }
    }

    private func presentProofToast(_ message: MMProofToastMessage) {
        MMProofToastPresenter.show(
            message,
            message: $proofToast,
            isVisible: $proofToastVisible
        )
    }

    private var readinessPillText: String {
        if isLoading { return "Loading" }
        if exports.contains(where: { ($0.exportType == "move_in_report") && ((verificationStatus[$0.id] == .processing) || (verificationStatus[$0.id] == .queued) || (verificationStatus[$0.id] == .verifying)) }) {
            return "Processing"
        }
        if exports.contains(where: { ($0.exportType == "move_in_report") && ((verificationStatus[$0.id] == .serverFailed) || (verificationStatus[$0.id]?.isProblem == true)) }) {
            return "Failed"
        }
        if isExportReadyForResolvedVault == false { return "Not ready" }
        if exports.contains(where: { $0.exportType == "move_in_report" }) { return "Ready" }
        if isExportReadyForResolvedVault == true { return "Ready" }
        return hasActiveVault ? "Not ready" : "No vault"
    }

    private enum SecondaryReportReadiness {
        case noProof
        case readyToMake
        case processing
        case readyToShare
        case failed
    }

    private var moveOutReadiness: SecondaryReportReadiness {
        guard let property = resolvedPropertyRecord else { return .noProof }
        let photos = propertyStore.moveOutPhotoCount(for: property)
        if photos <= 0 { return .noProof }
        let moveOutExports = exports.filter { $0.exportType == "move_out_report" }
        if moveOutExports.contains(where: { verificationStatus[$0.id] == .serverFailed }) { return .failed }
        if moveOutExports.contains(where: { isActiveExportJob(verificationStatus[$0.id] ?? .unknown) }) { return .processing }
        if moveOutExports.contains(where: { verificationStatus[$0.id] == .ready }) { return .readyToShare }
        return .readyToMake
    }

    private var disputeReadiness: SecondaryReportReadiness {
        guard let property = resolvedPropertyRecord else { return .noProof }
        let documented = propertyStore.documentedRoomCount(for: property)
        let hasProof = documented > 0 || exports.contains {
            $0.exportType == "move_in_report" && verificationStatus[$0.id] == .ready
        }
        if !hasProof { return .noProof }
        let disputeExports = exports.filter { $0.exportType == "dispute_packet" || $0.exportType == "dispute_summary" }
        if disputeExports.contains(where: { verificationStatus[$0.id] == .serverFailed }) { return .failed }
        if disputeExports.contains(where: { isActiveExportJob(verificationStatus[$0.id] ?? .unknown) }) { return .processing }
        if disputeExports.contains(where: { verificationStatus[$0.id] == .ready }) { return .readyToShare }
        return .readyToMake
    }

    private var moveOutPrimaryCTA: (title: String, enabled: Bool, action: () -> Void) {
        if !subscriptionManager.hasPro {
            return ("Upgrade to Pro", true, {
                activePaywallReason = .moveOutExport
                showPaywall = true
            })
        }
        switch moveOutReadiness {
        case .noProof:
            return ("Open move-out proof", true, { onOpenMoveOutProof?() })
        case .readyToMake:
            return (isMoveOutExporting ? "Making report…" : "Make move-out report", !isMoveOutExporting, { requestMoveOutExport() })
        case .readyToShare:
            return ("View / Share", true, {
                if let row = exports.first(where: { $0.exportType == "move_out_report" && verificationStatus[$0.id] == .ready }) {
                    viewReport(row)
                }
            })
        case .processing:
            return ("Building report…", false, {})
        case .failed:
            return (isMoveOutExporting ? "Retrying…" : "Retry report", !isMoveOutExporting, { requestMoveOutExport() })
        }
    }

    private var disputePrimaryCTA: (title: String, enabled: Bool, action: () -> Void) {
        if !subscriptionManager.hasPro {
            return ("Included with Pro", true, {
                activePaywallReason = .disputePacket
                showPaywall = true
            })
        }
        switch disputeReadiness {
        case .noProof:
            return ("Continue room proof", true, {
                if let onContinueRoomProof {
                    onContinueRoomProof()
                } else {
                    onOpenVaults?()
                }
            })
        case .readyToMake:
            return (isDisputeExporting ? "Building packet…" : "Build dispute packet", !isDisputeExporting, { requestDisputePacketExport() })
        case .readyToShare:
            return ("View / Share", true, {
                if let row = exports.first(where: {
                    ($0.exportType == "dispute_packet" || $0.exportType == "dispute_summary") &&
                    verificationStatus[$0.id] == .ready
                }) {
                    viewReport(row)
                }
            })
        case .processing:
            return ("Building packet…", false, {})
        case .failed:
            return (isDisputeExporting ? "Retrying…" : "Retry packet", !isDisputeExporting, { requestDisputePacketExport() })
        }
    }

    private func isActiveExportJob(_ status: ExportVerificationStatus) -> Bool {
        switch status {
        case .queued, .processing, .verifying:
            return true
        default:
            return false
        }
    }

    private func requestMoveOutExport() {
        guard let property = resolvedPropertyRecord ?? propertyStore.currentProperty else { return }
        guard !isMoveOutExporting else { return }
        guard subscriptionManager.canExportMoveOut() else {
            activePaywallReason = .moveOutExport
            showPaywall = true
            return
        }
        guard let baseURL = apiBaseURL else {
            errorMessage = "API base URL is missing. Set MoveMarkAPIBaseURL in build settings."
            return
        }

        isMoveOutExporting = true
        errorMessage = nil

        Task { @MainActor in
            defer { isMoveOutExporting = false }
            do {
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestMoveOutExport(propertyId: property.id)
                MMProofToastPresenter.show(.reportQueued(), message: $proofToast, isVisible: $proofToastVisible)
                NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
                await loadExports()
            } catch {
                errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                    error,
                    fallback: "Couldn't queue move-out report. Try again.",
                    intent: .mutate
                )
                MMHaptics.error()
            }
        }
    }

    private func requestDisputePacketExport() {
        guard let property = resolvedPropertyRecord ?? propertyStore.currentProperty else { return }
        guard !isDisputeExporting else { return }
        guard subscriptionManager.hasPro else {
            activePaywallReason = .disputePacket
            showPaywall = true
            return
        }
        guard let baseURL = apiBaseURL else {
            errorMessage = "API base URL is missing. Set MoveMarkAPIBaseURL in build settings."
            return
        }

        isDisputeExporting = true
        errorMessage = nil

        Task { @MainActor in
            defer { isDisputeExporting = false }
            do {
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestDisputePacketExport(propertyId: property.id)
                MMProofToastPresenter.show(.reportQueued(), message: $proofToast, isVisible: $proofToastVisible)
                NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
                await loadExports()
            } catch {
                errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                    error,
                    fallback: "Couldn't queue dispute packet. Try again.",
                    intent: .mutate
                )
                MMHaptics.error()
            }
        }
    }

    private func label(for exportType: String) -> String {
        switch exportType {
        case "move_in_report":
            return "Move-in report"
        case "move_out_report":
            return "Move-out report"
        case "dispute_packet":
            return "Dispute packet"
        case "dispute_summary":
            return "Dispute summary"
        default:
            return exportType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func parsedDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }

    private func loadExports() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await MainActor.run {
            verificationStatus = [:]
        }

        guard let apiClient = try? makeAPIClient() else {
            errorMessage = "API base URL is missing. Set MoveMarkAPIBaseURL in build settings."
            exports = []
            return
        }

        guard let currentPropertyId = resolvedExportPropertyId else {
            exports = []
            errorMessage = nil
            return
        }

        do {
            let items = try await apiClient.fetchExports(propertyId: currentPropertyId)

            var nextVerification: [UUID: ExportVerificationStatus] = [:]
            for item in items {
                switch item.status {
                case .queued:
                    nextVerification[item.id] = .queued
                case .processing:
                    nextVerification[item.id] = .processing
                case .failed:
                    nextVerification[item.id] = .serverFailed
                case .completed:
                    let fp = (item.filePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if fp.isEmpty {
                        nextVerification[item.id] = .missingPath
                    } else {
                        nextVerification[item.id] = .ready
                    }
                }
            }
            let rows = items.map { item in
                ExportRow(
                    id: item.id,
                    disputeId: nil,
                    propertyId: item.propertyId,
                    userId: item.userId,
                    exportType: item.type,
                    filePath: item.filePath,
                    createdAt: item.requestedAt ?? item.createdAt
                )
            }
            exports = rows
            verificationStatus = nextVerification
        } catch {
            errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                error,
                fallback: "Couldn’t load exports. Try again."
            )
            exports = []
            MMHaptics.error()
        }
    }

    private func retryExport(_ row: ExportRow) {
        switch row.exportType {
        case "move_in_report":
            requestMoveInExport()
        case "move_out_report":
            requestMoveOutExport()
        case "dispute_packet", "dispute_summary":
            requestDisputePacketExport()
        default:
            Task { await loadExports() }
        }
    }

    private func prepareLocalReportFile(for row: ExportRow) async throws -> URL {
        let client = try makeAPIClient()
        let response = try await client.fetchDownloadURL(exportId: row.id.uuidString)
        guard let signedURL = URL(string: response.downloadUrl) else {
            throw APIClientError.invalidResponse
        }
        return try await ReportFileDownloader.downloadPDF(
            from: signedURL,
            exportType: row.exportType
        )
    }

    private func viewReport(_ row: ExportRow) {
        Task { @MainActor in
            MMHaptics.soft()
            errorMessage = nil
            isDownloadingReport = true
            defer { isDownloadingReport = false }

            do {
                let localURL = try await prepareLocalReportFile(for: row)
                try ReportFileDownloader.validateReportFile(at: localURL)
                reportPreviewItem = ReportPreviewItem(
                    fileURL: localURL,
                    title: ReportFileDownloader.displayTitle(for: row.exportType),
                    exportType: row.exportType
                )
                verificationStatus[row.id] = .ready
                presentProofToast(
                    MMProofToastMessage(
                        kind: .success,
                        title: "Report ready",
                        message: "Preview or share your PDF."
                    )
                )
            } catch let reportError as ReportFileError {
                errorMessage = reportError.localizedDescription
                MMHaptics.error()
            } catch let api as APIClientError {
                handleReportDownloadAPIError(api, row: row)
            } catch {
                errorMessage = MoveMarkFlowMessage.documentPreviewFailed(error)
                MMHaptics.error()
            }
        }
    }

    private func shareCachedReport(at fileURL: URL, exportType: String) {
        do {
            let item = try ReportFileDownloader.makeShareItem(for: fileURL, exportType: exportType)
            shareItems = [item]
            showShareSheet = true
            MoveMarkAnalytics.track(.reportShared, properties: ["type": exportType])
        } catch {
            errorMessage = (error as? ReportFileError)?.localizedDescription
                ?? "Couldn't share report. Try saving it first."
            MMHaptics.error()
        }
    }

    private func share(_ row: ExportRow) {
        Task { @MainActor in
            MMHaptics.soft()
            errorMessage = nil
            isDownloadingReport = true
            defer { isDownloadingReport = false }

            do {
                let localURL = try await prepareLocalReportFile(for: row)
                let item = try ReportFileDownloader.makeShareItem(for: localURL, exportType: row.exportType)
                shareItems = [item]
                showShareSheet = true
                MoveMarkAnalytics.track(.reportShared, properties: ["type": row.exportType])
                verificationStatus[row.id] = .ready
                presentProofToast(
                    MMProofToastMessage(
                        kind: .success,
                        title: "Ready to share",
                        message: "Send your PDF report."
                    )
                )
            } catch let reportError as ReportFileError {
                errorMessage = reportError.localizedDescription
                MMHaptics.error()
            } catch let api as APIClientError {
                handleReportDownloadAPIError(api, row: row)
            } catch {
                let mapped = MoveMarkFlowMessage.documentPreviewFailed(error)
                verificationStatus[row.id] = .verificationFailed(mapped)
                errorMessage = mapped
                MMHaptics.error()
            }
        }
    }

    private func handleReportDownloadAPIError(_ api: APIClientError, row: ExportRow) {
        if case .exportNotReady = api {
            verificationStatus[row.id] = .processing
            errorMessage = nil
        } else if case .exportFailed = api {
            verificationStatus[row.id] = .serverFailed
            errorMessage = MoveMarkFlowMessage.exportServerFailedHint
            presentProofToast(.reportFailed())
            MMHaptics.error()
        } else {
            let mapped = MoveMarkFlowMessage.exportOrAPIFailed(
                api,
                fallback: "Couldn’t prepare your report. Try again."
            )
            verificationStatus[row.id] = .verificationFailed(mapped)
            errorMessage = mapped
            MMHaptics.error()
        }
    }

    private var hasActiveMoveInExportJob: Bool {
        exports.contains { row in
            guard row.exportType == "move_in_report" else { return false }
            guard let status = verificationStatus[row.id] else { return false }
            switch status {
            case .queued, .processing, .verifying:
                return true
            default:
                return false
            }
        }
    }

    private func requestMoveInExport() {
        guard let property = resolvedPropertyRecord ?? propertyStore.currentProperty else { return }
        guard !isExporting else { return }
        guard !hasActiveMoveInExportJob else {
            errorMessage = "A move-in report is already queued or processing. Open Reports to check status."
            MMProofToastPresenter.show(
                .reportQueued(),
                message: $proofToast,
                isVisible: $proofToastVisible
            )
            return
        }
        guard isExportReadyForResolvedVault == true else { return }
        guard subscriptionManager.canExportMoveIn(forUser: sessionManager.userId) else {
            activePaywallReason = .unlimitedExports
            showPaywall = true
            return
        }
        guard let baseURL = apiBaseURL else {
            errorMessage = "API base URL is missing. Set MoveMarkAPIBaseURL in build settings."
            return
        }

        isExporting = true
        errorMessage = nil

        Task { @MainActor in
            defer { isExporting = false }

            do {
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestMoveInExport(propertyId: property.id)

                if !subscriptionManager.hasPro, let uid = sessionManager.userId {
                    subscriptionManager.incrementFreeMoveInExportCount(forUser: uid)
                }

                MoveMarkAnalytics.track(.reportGenerated, properties: ["type": "move_in"])

                MMProofToastPresenter.show(
                    .reportQueued(),
                    message: $proofToast,
                    isVisible: $proofToastVisible
                )
                NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
                await loadExports()
                await pollActiveExportsWhileNeeded()
            } catch {
                errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                    error,
                    fallback: "Couldn’t queue move-in report. Try again.",
                    intent: .mutate
                )
                MMHaptics.error()
            }
        }
    }

    private func makeAPIClient() throws -> ExportAPIClient {
        guard let apiBaseURL else { throw APIClientError.invalidBaseURL }
        return try ExportAPIClient(baseURLString: apiBaseURL)
    }

}

extension Notification.Name {
    /// Posted after a move-in export is queued from Walkthrough so ``ExportHistoryView`` can reload without switching tabs.
    static let moveMarkExportsShouldRefresh = Notification.Name("MoveMark.exportsShouldRefresh")
}
