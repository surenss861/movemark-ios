//
//  ExportHistoryView.swift
//  movemork
//
//  MoveMark — Reports history with proof trail and quiet row cards.
//

import SwiftUI
import Supabase

struct ExportHistoryView: View {
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible

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

    @State private var exports: [ExportRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successBanner: String? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var reportPreviewItem: ReportPreviewItem?
    @State private var isDownloadingReport = false
    @State private var verificationStatus: [UUID: ExportVerificationStatus] = [:]
    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var reportUnlockPulse = false
    @State private var lastReportReadiness: MMNextBestActionMapper.ReportReadiness? = nil
    @State private var isExporting = false
    @State private var isMoveOutExporting = false
    @State private var isDisputeExporting = false
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .unlimitedExports
    @State private var reportsContentAppeared = false

    // MARK: - Realtime export status (falls back to polling below when unavailable)
    @State private var exportsChannel: RealtimeChannelV2?
    @State private var exportsRealtimeTask: Task<Void, Never>?

    private var apiBaseURL: String? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "MoveMarkAPIBaseURL") as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return value
    }

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
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: false, ctaBloom: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .padding(.bottom, 24)

                    if hasActiveVault {
                        if shouldShowReportProofTrail {
                            MMReportReadinessChecklist(
                                items: reportChecklistItems,
                                appeared: reportsContentAppeared
                            )
                        }

                        reportPreviewHero
                            .mmAppearRise(isVisible: reportsContentAppeared, delay: 0.06, offset: 6)

                        secondaryExportSections
                            .mmAppearRise(isVisible: reportsContentAppeared, delay: 0.12, offset: 6)
                    }

                    if let successBanner {
                        MMCard(tone: .quiet, padding: 14, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                                Text(successBanner)
                                    .font(MoveMarkTheme.Typography.subheadline)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            }
                        }
                    }

                    if let errorMessage {
                        MMErrorBanner(
                            message: errorMessage,
                            retryTitle: MMCopy.tryAgain,
                            onRetry: { Task { await loadExports() } }
                        )
                    }

                    if !hasActiveVault && !isLoading {
                        noVaultSelectedState
                    } else if hasActiveVault && !isLoading && exports.isEmpty {
                        exportHistoryEmptyState
                    } else if !isLoading, !exports.isEmpty {
                        exportHistorySections
                    }

                    if rootTabBarVisible {
                        MMSignedInScrollTailSpacer(kind: .reportsTab)
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 10)
                .mmScrollContentTopInset(2)
            }
            .refreshable {
                await loadExports()
            }
        }
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .onChange(of: reportReadinessSnapshot) { _, _ in
            handleReportReadinessChange()
        }
        .onAppear {
            lastReportReadiness = currentReportReadiness
            if !reportsContentAppeared {
                reportsContentAppeared = true
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
            await subscribeExportsRealtime()
            await pollActiveExportsWhileNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveMarkExportsShouldRefresh)) { _ in
            Task {
                await loadExports()
                await pollActiveExportsWhileNeeded()
            }
        }
        .onDisappear {
            teardownExportsRealtime()
        }
    }

    /// Subscribes to `postgres_changes` on `public.exports` for the active property so completed/failed
    /// exports update immediately instead of waiting on the poll loop below. RLS (`exports_select_own`)
    /// still scopes what this can see — the added `supabase_realtime` publication membership only changes
    /// how the client is notified, not who can read which rows.
    private func subscribeExportsRealtime() async {
        teardownExportsRealtime()
        guard let propertyId = resolvedExportPropertyId else { return }

        let channel = supabase.channel("exports-property-\(propertyId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "exports",
            filter: .eq("property_id", value: propertyId)
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            // Realtime unavailable (e.g. offline, socket blocked) — `pollActiveExportsWhileNeeded` below
            // is the fallback and will run at its normal cadence since `exportsChannel` stays nil.
            return
        }

        exportsChannel = channel
        exportsRealtimeTask = Task {
            for await _ in changes {
                if Task.isCancelled { return }
                await loadExportsQuietly()
            }
        }
    }

    private func teardownExportsRealtime() {
        exportsRealtimeTask?.cancel()
        exportsRealtimeTask = nil
        if let exportsChannel {
            Task { await supabase.removeChannel(exportsChannel) }
            self.exportsChannel = nil
        }
    }

    /// Fallback when Realtime is unavailable (or as a safety net against a silently-dropped connection):
    /// poll while any export is queued/processing. Once Realtime is connected, the interval is stretched
    /// out significantly since Realtime — not this loop — is doing the real-time work.
    private func pollActiveExportsWhileNeeded() async {
        let quickIntervalNanos: UInt64 = 2_500_000_000
        let realtimeBackstopIntervalNanos: UInt64 = 15_000_000_000

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
            let interval = exportsChannel != nil ? realtimeBackstopIntervalNanos : quickIntervalNanos
            try? await Task.sleep(nanoseconds: interval)
            await loadExportsQuietly()
        }
    }

    private func loadExportsQuietly() async {
        guard let apiClient = try? makeAPIClient() else { return }
        guard let currentPropertyId = resolvedExportPropertyId else { return }
        do {
            let token = try await currentAccessToken()
            let items = try await apiClient.fetchExports(accessToken: token, propertyId: currentPropertyId)
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

    private func canShareExport(_ status: ExportVerificationStatus) -> Bool {
        switch status {
        case .ready:
            return true
        case .serverFailed, .queued, .processing, .verifying, .missingPath, .invalidURL, .unknown, .verificationFailed:
            return false
        }
    }

    private func shouldShowVerifyButton(for status: ExportVerificationStatus) -> Bool {
        switch status {
        case .ready, .serverFailed:
            return false
        case .unknown, .queued, .processing, .verifying, .missingPath, .invalidURL, .verificationFailed:
            return true
        }
    }

    private var header: some View {
        MMProofSectionHeader(
            title: "Your reports",
            subtitle: "Turn saved proof into shareable records."
        )
    }

    private var exportContextStrip: some View {
        MMCard(tone: .quiet, padding: 12, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Rental proof")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                    Text("·")
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.6))
                    Text("Current vault")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    Text("·")
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.45))
                    Text(activeVaultDisplayTitle ?? "Selected vault")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
                Text(exportContextLine)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var exportContextLine: String {
        if resolvedPropertyRecord == nil {
            return "Open your vault once to see if a report is ready."
        }
        let reports = exports.count
        if reports == 0 {
            return "No reports yet."
        }
        return reports == 1 ? "1 report ready to share." : "\(reports) reports ready to share."
    }

    private var shouldShowReportProofTrail: Bool {
        switch currentReportReadiness {
        case .notReady, .readyToMake, .readyToShare, .processing, .failed:
            return true
        case .noVault:
            return false
        }
    }

    private var reportPreviewHero: some View {
        MMReportPreviewHero(
            state: reportPreviewHeroState,
            metricsLine: isLoading ? nil : readinessMetricsLine,
            headline: reportHeroHeadline,
            footnote: reportHeroFootnote,
            proofChips: reportProofChips,
            primaryTitle: reportPrimaryCTA.title,
            isPrimaryDisabled: isExporting || currentReportReadiness == .processing || isLoading,
            unlockPulse: reportUnlockPulse,
            onPrimary: reportPrimaryCTA.action
        )
    }

    private var reportPreviewHeroState: MMReportPreviewHero.State {
        if isLoading { return .loading }
        switch currentReportReadiness {
        case .notReady, .noVault: return .notReady
        case .readyToMake: return .canMake
        case .processing: return .processing
        case .readyToShare: return .ready
        case .failed: return .failed
        }
    }

    private var reportHeroHeadline: String {
        if isLoading { return "Checking saved proof…" }
        switch currentReportReadiness {
        case .notReady, .noVault:
            return "Finish room proof first."
        case .readyToMake:
            return "You have enough proof to create a move-in report."
        case .readyToShare:
            return "Your move-in report is ready to share."
        case .processing:
            return "Building your PDF report."
        case .failed:
            return "We couldn't finish your report."
        }
    }

    private var reportHeroFootnote: String? {
        guard !isLoading else { return nil }
        switch currentReportReadiness {
        case .notReady, .noVault:
            return "Complete each room before creating your report."
        case .readyToMake:
            return "Add more rooms and docs for a stronger report."
        default:
            return nil
        }
    }

    private var reportProofChips: [String] {
        guard let property = resolvedPropertyRecord else { return [] }
        var chips: [String] = []

        let totalRooms = propertyStore.totalRoomCount(for: property)
        let documented = propertyStore.documentedRoomCount(for: property)
        if totalRooms > 0 {
            chips.append("\(documented)/\(totalRooms) rooms")
        }

        let photos = propertyStore.totalPhotoCount(for: property)
        if photos > 0 {
            chips.append(photos == 1 ? "1 photo" : "\(photos) photos")
        }

        let requiredDocs = PropertyStore.moveInRequiredDocumentTypes.count
        let missingDocs = propertyStore.missingSupportingRecordCount(for: property)
        let uploadedDocs = max(0, requiredDocs - missingDocs)
        if requiredDocs > 0 {
            chips.append("\(uploadedDocs)/\(requiredDocs) docs")
        }

        return chips
    }

    private var reportChecklistItems: [MMProofChecklistItem] {
        guard let property = resolvedPropertyRecord else {
            return [
                MMProofChecklistItem(title: "Room photos", detail: "Open your vault to start room proof", state: .incomplete),
                MMProofChecklistItem(title: "Lease & docs", detail: "Add lease and deposit records", state: .incomplete),
                MMProofChecklistItem(title: "Damage tags", detail: "Tag issues while you photograph rooms", state: .locked),
                MMProofChecklistItem(title: "Move-out proof", detail: "Optional later — before you move out", state: .locked),
                MMProofChecklistItem(title: "Report", detail: "Locked until proof is ready", state: .locked)
            ]
        }

        let totalRooms = propertyStore.totalRoomCount(for: property)
        let documented = propertyStore.documentedRoomCount(for: property)
        let requiredDocs = PropertyStore.moveInRequiredDocumentTypes.count
        let missingDocs = propertyStore.missingSupportingRecordCount(for: property)
        let uploadedDocs = max(0, requiredDocs - missingDocs)

        let openIssues = propertyStore.openIssueCount(for: property)

        let roomsState: MMProofChecklistItem.State = {
            if totalRooms == 0 { return .incomplete }
            if documented == 0 { return .incomplete }
            if documented >= totalRooms { return .complete }
            return .incomplete
        }()

        let docsState: MMProofChecklistItem.State = missingDocs == 0 ? .complete : .incomplete

        let issuesState: MMProofChecklistItem.State = {
            if documented == 0 { return .locked }
            return .complete
        }()

        let moveOutState: MMProofChecklistItem.State = .locked

        let reportState: MMProofChecklistItem.State = {
            if isExportReadyForResolvedVault == true { return .complete }
            return .locked
        }()

        let issuesDetail: String = {
            if documented == 0 { return "Tag scratches and stains as you photograph" }
            if openIssues == 0 { return "No issues tagged yet" }
            return openIssues == 1 ? "1 issue tagged" : "\(openIssues) issues tagged"
        }()

        let reportDetail: String = {
            if isExportReadyForResolvedVault == true {
                return "Can make from saved proof"
            }
            return "Unlocks after room proof + docs"
        }()

        return [
            MMProofChecklistItem(
                title: "Room photos",
                detail: totalRooms == 0
                    ? "Add rooms in your vault"
                    : "\(documented) of \(totalRooms) rooms ready",
                state: roomsState
            ),
            MMProofChecklistItem(
                title: "Lease & docs",
                detail: "\(uploadedDocs) of \(requiredDocs) docs uploaded",
                state: docsState
            ),
            MMProofChecklistItem(
                title: "Damage tags",
                detail: issuesDetail,
                state: issuesState
            ),
            MMProofChecklistItem(
                title: "Move-out proof",
                detail: "Optional later",
                state: moveOutState
            ),
            MMProofChecklistItem(
                title: "Report",
                detail: reportDetail,
                state: reportState
            )
        ]
    }

    /// Drives readiness transitions (unlock motion + toasts).
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
            reportUnlockPulse = true
            MMHaptics.medium()
            presentProofToast(.exportsUnlocked())

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.55))
                reportUnlockPulse = false
            }
        }
    }

    private func presentProofToast(_ message: MMProofToastMessage) {
        MMProofToastPresenter.show(
            message,
            message: $proofToast,
            isVisible: $proofToastVisible
        )
    }

    private var reportPrimaryCTA: (title: String, action: () -> Void) {
        if isLoading {
            return ("Checking report…", {})
        }

        switch currentReportReadiness {
        case .notReady:
            return ("Continue room proof", {
                if let onContinueRoomProof {
                    onContinueRoomProof()
                } else {
                    onOpenVaults?()
                }
            })
        case .readyToMake:
            if subscriptionManager.canExportMoveIn(forUser: sessionManager.userId) {
                return (isExporting ? "Making report…" : "Make report", {
                    requestMoveInExport()
                })
            }
            return ("Upgrade for another report", {
                activePaywallReason = .unlimitedExports
                showPaywall = true
            })
        case .readyToShare:
            return ("View / Share report", {
                if let row = exports.first(where: {
                    $0.exportType == "move_in_report" && verificationStatus[$0.id] == .ready
                }) {
                    viewReport(row)
                }
            })
        case .processing:
            return ("Building…", {})
        case .failed:
            return ("Try again", { Task { await loadExports() } })
        case .noVault:
            return ("Open vaults", { onOpenVaults?() })
        }
    }

    private var readinessMetricsLine: String? {
        guard let p = resolvedPropertyRecord else { return nil }
        let documented = propertyStore.documentedRoomCount(for: p)
        let total = propertyStore.totalRoomCount(for: p)
        let issues = propertyStore.openIssueCount(for: p)

        var parts: [String] = []
        if total > 0 {
            parts.append("\(documented) of \(total) rooms ready")
        }
        if issues > 0 {
            parts.append(issues == 1 ? "1 issue tagged" : "\(issues) issues tagged")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

    private var exportHistoryEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export history")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.leading, 2)

            Text("Create your first move-in report once proof is ready.")
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var noVaultSelectedState: some View {
        ProofReportCard(
            model: ProofReportModel(
                reportTitle: "Move-in report",
                metricsLine: "Pick a vault to see report readiness",
                statusLabel: "Needs proof",
                statusTone: .neutral,
                footnote: "Reports belong to one rental. Create or open a vault first."
            ),
            primaryTitle: "Open vault",
            onPrimary: { onOpenVaults?() },
            primaryEnabled: showOpenVaultsCTA
        )
    }

    private var secondaryExportSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            MMReportExportSection(
                sectionTitle: "Move-out report",
                sectionSubtitle: "Re-capture rooms before you return the keys.",
                statusLabel: moveOutStatusLabel,
                statusTone: moveOutStatusTone,
                metricsLine: moveOutMetricsLine,
                footnote: moveOutFootnote,
                primaryTitle: moveOutPrimaryCTA.title,
                primaryEnabled: moveOutPrimaryCTA.enabled,
                isProcessing: moveOutReadiness == .processing,
                isProLocked: !subscriptionManager.hasPro,
                onPrimary: moveOutPrimaryCTA.action
            )

            MMReportExportSection(
                sectionTitle: "Dispute packet",
                sectionSubtitle: "Bundle your proof if your deposit is questioned.",
                statusLabel: disputeStatusLabel,
                statusTone: disputeStatusTone,
                footnote: disputeFootnote,
                primaryTitle: disputePrimaryCTA.title,
                primaryEnabled: disputePrimaryCTA.enabled,
                isProcessing: disputeReadiness == .processing,
                isProLocked: !subscriptionManager.hasPro,
                useQuietPrimaryWhenLocked: true,
                legalNote: "MoveMark organizes your proof. It does not provide legal advice.",
                onPrimary: disputePrimaryCTA.action
            )
        }
    }

    private var exportHistorySections: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export history")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.leading, 2)

            VStack(spacing: 8) {
                ForEach(exports) { row in
                    let status = verificationStatus[row.id] ?? .unknown
                    ExportHistoryRow(
                        title: label(for: row.exportType),
                        dateLine: formattedDate(row.createdAt),
                        statusLabel: status.displayLabel,
                        statusTone: historyStatusTone(status),
                        isProcessing: isActiveExportJob(status),
                        canShare: canShareExport(status),
                        canRetry: status == .serverFailed,
                        onShare: { share(row) },
                        onRetry: { retryExport(row) }
                    )
                }
            }
        }
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

    private var moveOutStatusLabel: String {
        switch moveOutReadiness {
        case .noProof: return "Needs proof"
        case .readyToMake: return "Report can be made"
        case .processing: return "Building report"
        case .readyToShare: return "Ready to share"
        case .failed: return "Failed"
        }
    }

    private var disputeStatusLabel: String {
        switch disputeReadiness {
        case .noProof: return "Needs proof"
        case .readyToMake: return "Report can be made"
        case .processing: return "Building report"
        case .readyToShare: return "Ready to share"
        case .failed: return "Failed"
        }
    }

    private var moveOutStatusTone: ProofStatusTone {
        switch moveOutReadiness {
        case .readyToShare: return .success
        case .failed: return .danger
        case .processing: return .warning
        case .noProof: return .warning
        case .readyToMake: return .neutral
        }
    }

    private var disputeStatusTone: ProofStatusTone {
        switch disputeReadiness {
        case .readyToShare: return .success
        case .failed: return .danger
        case .processing: return .warning
        case .noProof: return .warning
        case .readyToMake: return .neutral
        }
    }

    private var moveOutMetricsLine: String? {
        guard let property = resolvedPropertyRecord else { return nil }
        let photos = propertyStore.moveOutPhotoCount(for: property)
        guard photos > 0 else { return nil }
        let rooms = propertyStore.moveOutDocumentedRoomCount(for: property)
        let total = propertyStore.totalRoomCount(for: property)
        return "\(rooms) of \(total) rooms · \(photos) move-out photos"
    }

    private var moveOutFootnote: String? {
        switch moveOutReadiness {
        case .noProof: return "Capture move-out room photos first."
        case .readyToMake: return "Add more move-out proof for a stronger report."
        case .readyToShare: return "Your move-out report is ready to share."
        case .failed: return "Something went wrong. Try again when you're ready."
        case .processing: return nil
        }
    }

    private var disputeFootnote: String? {
        switch disputeReadiness {
        case .noProof: return "Save move-in room proof before building a packet."
        case .readyToMake: return "Add more proof for a stronger packet."
        case .readyToShare: return "Your dispute packet is ready to share."
        case .failed: return "Something went wrong. Try again when you're ready."
        case .processing: return nil
        }
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
            return ("View / Share report", true, {
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
            return ("View / Share packet", true, {
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

    private func historyStatusTone(_ status: ExportVerificationStatus) -> ProofStatusTone {
        switch status {
        case .ready: return .success
        case .serverFailed: return .danger
        case .queued, .processing, .verifying: return .warning
        default: return .neutral
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
                let session = try await supabase.auth.session
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestMoveOutExport(
                    propertyId: property.id,
                    accessToken: session.accessToken
                )
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
                let session = try await supabase.auth.session
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestDisputePacketExport(
                    propertyId: property.id,
                    accessToken: session.accessToken
                )
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

    private var reportPreviewMock: some View {
        MMArtifactSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Report preview")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(MoveMarkTheme.Colors.primaryPressed)

                    Spacer()

                    Image(systemName: "doc.richtext")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MoveMarkTheme.Colors.textPrimary.opacity(0.18))
                        .frame(width: 118, height: 8)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MoveMarkTheme.Colors.panelStroke)
                        .frame(width: 160, height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MoveMarkTheme.Colors.panelStroke.opacity(0.7))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MoveMarkTheme.Colors.panelStroke.opacity(0.7))
                        .frame(height: 6)
                }

                HStack(spacing: 8) {
                    statusPill("Rooms")
                    statusPill("Photos")
                    statusPill("Docs")
                }
            }
            .padding(16)
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(MoveMarkTheme.Colors.mint.opacity(0.5))
            .clipShape(Capsule())
    }

    private var disputeRows: [ExportRow] {
        exports.filter { $0.exportType == "dispute_packet" || $0.exportType == "dispute_summary" }
    }

    private func rows(for type: String) -> [ExportRow] {
        exports.filter { $0.exportType == type }
    }

    @ViewBuilder
    private func exportSection(title: String, rows: [ExportRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MMSectionHeader(title: title, subtitle: nil)

                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        exportRowCard(row)
                    }
                }
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

    private func exportRowCard(_ row: ExportRow) -> some View {
        let status = verificationStatus[row.id] ?? .unknown

        return MMCard(tone: .artifact, padding: 16, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                exportRowThumbnail(for: row)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(label(for: row.exportType))
                            .font(MoveMarkTheme.Typography.cardTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        exportStatusLabel(status)
                    }

                    Text(formattedDate(row.createdAt))
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                    Text(shortPath(row.filePath))
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
                        .lineLimit(1)

                    if status == .serverFailed {
                        Text(MoveMarkFlowMessage.exportServerFailedHint)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if case .verificationFailed(let msg) = status, !msg.isEmpty {
                        Text(msg)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    MMButton(
                        title: MMNextBestAction.shareReport.title,
                        action: { share(row) },
                        kind: .primary,
                        size: .compact,
                        isDisabled: !canShareExport(status),
                        expandsToFillWidth: false
                    )

                    if shouldShowVerifyButton(for: status) {
                        MMButton(
                            title: status == .verifying ? "Checking…" : "Check status",
                            action: { verify(row) },
                            kind: .quiet,
                            size: .compact,
                            isDisabled: status == .verifying,
                            expandsToFillWidth: false
                        )
                    }
                }
            }
        }
    }

    private func exportRowThumbnail(for row: ExportRow) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.mint,
                            MoveMarkTheme.Colors.panelAlt
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 72)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.6), lineWidth: 0.8)
                .frame(width: 58, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MoveMarkTheme.Colors.textPrimary.opacity(0.2))
                    .frame(width: 22, height: 4)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MoveMarkTheme.Colors.panelStroke)
                    .frame(width: 30, height: 3)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MoveMarkTheme.Colors.panelStroke.opacity(0.7))
                    .frame(width: 26, height: 3)

                Spacer()

                Image(systemName: icon(for: row.exportType))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
            }
            .padding(10)
            .frame(width: 58, height: 72, alignment: .topLeading)
        }
    }

    private func icon(for exportType: String) -> String {
        switch exportType {
        case "move_in_report":
            return "doc.text"
        case "move_out_report":
            return "doc.plaintext"
        case "dispute_packet", "dispute_summary":
            return "doc.richtext"
        default:
            return "doc"
        }
    }

    @ViewBuilder
    private func exportStatusLabel(_ status: ExportVerificationStatus) -> some View {
        switch status {
        case .ready:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticSuccess)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

        case .verifying:
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.95))
            }

        case .unknown:
            Text(status.displayLabel)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))

        case .queued:
            HStack(spacing: 4) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.95))
            }

        case .processing:
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.95))
            }

        case .missingPath, .invalidURL, .verificationFailed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.95))
            }

        case .serverFailed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticDanger)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticDanger.opacity(0.95))
            }
        }
    }

    private func verify(_ row: ExportRow) {
        verificationStatus[row.id] = .verifying
        Task { @MainActor in
            do {
                let accessToken = try await currentAccessToken()
                let client = try makeAPIClient()
                _ = try await client.fetchDownloadURL(exportId: row.id.uuidString, accessToken: accessToken)
                verificationStatus[row.id] = .ready
                MMHaptics.success()
            } catch let api as APIClientError {
                if case .exportNotReady = api {
                    verificationStatus[row.id] = .processing
                    MMHaptics.soft()
                } else if case .exportFailed = api {
                    verificationStatus[row.id] = .serverFailed
                    MMHaptics.error()
                } else {
                    verificationStatus[row.id] = .verificationFailed(
                        MoveMarkFlowMessage.exportOrAPIFailed(
                            api,
                            fallback: "Verification failed. Try again."
                        )
                    )
                    MMHaptics.error()
                }
            } catch {
                verificationStatus[row.id] = .verificationFailed(
                    MoveMarkFlowMessage.exportOrAPIFailed(
                        error,
                        fallback: "Verification failed. Try again."
                    )
                )
                MMHaptics.error()
            }
        }
    }

    private func shortPath(_ value: String?) -> String {
        value?.components(separatedBy: "/").last ?? (value ?? "—")
    }

    private static let exportHistoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy · h:mm a"
        return formatter
    }()

    private func formattedDate(_ value: String?) -> String {
        guard let value else { return "Unknown date" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: value)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: value)
        }
        guard let date else { return value }
        return Self.exportHistoryDateFormatter.string(from: date)
    }

    private func loadExports() async {
        isLoading = true
        errorMessage = nil
        successBanner = nil
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
            let token = try await currentAccessToken()
            let items = try await apiClient.fetchExports(accessToken: token, propertyId: currentPropertyId)

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
        let accessToken = try await currentAccessToken()
        let client = try makeAPIClient()
        let response = try await client.fetchDownloadURL(exportId: row.id.uuidString, accessToken: accessToken)
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
            successBanner = nil
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
            successBanner = nil
            isDownloadingReport = true
            defer { isDownloadingReport = false }

            do {
                let localURL = try await prepareLocalReportFile(for: row)
                let item = try ReportFileDownloader.makeShareItem(for: localURL, exportType: row.exportType)
                shareItems = [item]
                showShareSheet = true
                verificationStatus[row.id] = .ready
                successBanner = nil
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
            successBanner = nil
            errorMessage = nil
        } else if case .exportFailed = api {
            verificationStatus[row.id] = .serverFailed
            successBanner = nil
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
                let session = try await supabase.auth.session
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestMoveInExport(
                    propertyId: property.id,
                    accessToken: session.accessToken
                )

                if !subscriptionManager.hasPro, let uid = sessionManager.userId {
                    subscriptionManager.incrementFreeMoveInExportCount(forUser: uid)
                }

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

    private func currentAccessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }
}

extension Notification.Name {
    /// Posted after a move-in export is queued from Walkthrough so ``ExportHistoryView`` can reload without switching tabs.
    static let moveMarkExportsShouldRefresh = Notification.Name("MoveMark.exportsShouldRefresh")
}
