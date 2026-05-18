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

    var showOpenVaultsCTA: Bool = false
    var onOpenVaults: (() -> Void)? = nil
    var onContinueRoomProof: (() -> Void)? = nil

    @State private var exports: [ExportRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successBanner: String? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var verificationStatus: [UUID: ExportVerificationStatus] = [:]
    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var reportUnlockPulse = false
    @State private var lastReportReadiness: MMNextBestActionMapper.ReportReadiness? = nil
    @State private var isExporting = false
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .unlimitedExports
    @State private var reportsContentAppeared = false

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
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardStack) {
                    header
                    if hasActiveVault {
                        reportPreviewHero
                            .mmAppearRise(isVisible: reportsContentAppeared, delay: 0, offset: 6)

                        if shouldShowReportProofTrail {
                            MMReportReadinessChecklist(
                                items: reportChecklistItems,
                                appeared: reportsContentAppeared
                            )
                        }
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
                    } else if !isLoading, !(hasActiveVault && exports.isEmpty) {
                        VStack(alignment: .leading, spacing: 18) {
                            exportSection(title: "Move-in reports", rows: rows(for: "move_in_report"))
                            exportSection(title: "Move-out reports", rows: rows(for: "move_out_report"))
                            exportSection(title: "Dispute packets", rows: disputeRows)
                        }
                    }

                    if rootTabBarVisible {
                        MMSignedInScrollTailSpacer(kind: .rootTab)
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
                .mmScrollContentTopInset(2)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
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
                ShareSheet(activityItems: shareItems)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveMarkExportsShouldRefresh)) { _ in
            Task { await loadExports() }
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
            title: "Your move-in report",
            subtitle: headerSubtitle
        )
    }

    private var headerSubtitle: String {
        "Build a clean report from saved room proof."
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
            return "You can make a report now."
        case .readyToShare:
            return "Your report is ready to share."
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
                return (isExporting ? "Making report…" : "Make move-in report", {
                    requestMoveInExport()
                })
            }
            return ("Upgrade for another report", {
                activePaywallReason = .unlimitedExports
                showPaywall = true
            })
        case .readyToShare:
            return ("View / Share report", {
                if let row = exports.first(where: { verificationStatus[$0.id] == .ready }) {
                    share(row)
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

    private var noVaultSelectedState: some View {
        MMCard(tone: .quiet, padding: 18, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                reportPreviewMock

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pick a vault first")
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Reports belong to one rental. Open a vault on the Vaults tab, then come back here.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showOpenVaultsCTA {
                    MMButton(
                        title: "Open vaults",
                        action: { onOpenVaults?() },
                        kind: .primary,
                        size: .standard
                    )
                    .padding(.top, 2)
                }
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

    private func formattedDate(_ value: String?) -> String {
        guard let value else { return "Unknown date" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
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

    private func share(_ row: ExportRow) {
        Task { @MainActor in
            MMHaptics.soft()
            errorMessage = nil
            successBanner = nil
            do {
                let accessToken = try await currentAccessToken()
                let client = try makeAPIClient()
                let response = try await client.fetchDownloadURL(exportId: row.id.uuidString, accessToken: accessToken)
                guard let url = URL(string: response.downloadUrl) else {
                    throw APIClientError.invalidResponse
                }
                shareItems = [url]
                showShareSheet = true
                verificationStatus[row.id] = .ready
                successBanner = nil
                presentProofToast(
                    MMProofToastMessage(
                        kind: .success,
                        title: "Ready to share",
                        message: "Use Share to save or send."
                    )
                )
            } catch let api as APIClientError {
                if case .exportNotReady = api {
                    verificationStatus[row.id] = .processing
                    successBanner = nil
                    errorMessage = nil
                } else if case .exportFailed = api {
                    verificationStatus[row.id] = .serverFailed
                    successBanner = nil
                    errorMessage = MoveMarkFlowMessage.exportServerFailedHint
                    presentProofToast(.reportFailed())
                } else {
                    let mapped = MoveMarkFlowMessage.exportOrAPIFailed(
                        api,
                        fallback: "Couldn’t prepare download. Try again."
                    )
                    verificationStatus[row.id] = .verificationFailed(mapped)
                    errorMessage = mapped
                    MMHaptics.error()
                }
            } catch {
                let mapped = MoveMarkFlowMessage.exportOrAPIFailed(
                    error,
                    fallback: "Couldn’t prepare download. Try again."
                )
                verificationStatus[row.id] = .verificationFailed(mapped)
                errorMessage = mapped
                MMHaptics.error()
            }
        }
    }

    private func requestMoveInExport() {
        guard let property = resolvedPropertyRecord ?? propertyStore.currentProperty else { return }
        guard !isExporting else { return }
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
