//
//  ExportHistoryView.swift
//  movemork
//
//  MoveMark — Export history with artifact-led empty state and quiet row cards.
//

import SwiftUI
import Supabase

struct ExportHistoryView: View {
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible

    var showOpenVaultsCTA: Bool = false
    var onOpenVaults: (() -> Void)? = nil

    @State private var exports: [ExportRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successBanner: String? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var verificationStatus: [UUID: ExportVerificationStatus] = [:]

    private var apiBaseURL: String? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "MoveMarkAPIBaseURL") as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return value
    }

    private var hasActiveVault: Bool {
        propertyStore.currentProperty != nil
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

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
                    } else if exports.isEmpty && !isLoading {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            exportSection(title: "Move-in reports", rows: rows(for: "move_in_report"))
                            exportSection(title: "Move-out reports", rows: rows(for: "move_out_report"))
                            exportSection(title: "Dispute packets", rows: disputeRows)
                        }
                    }

                    if isLoading {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 18)
                .padding(
                    .bottom,
                    rootTabBarVisible
                        ? MoveMarkTheme.Spacing.scrollTailRootTabChrome
                        : MoveMarkTheme.Spacing.scrollTailFocusedFlow
                )
            }
            .refreshable {
                await loadExports()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
        .task(id: propertyStore.currentProperty?.id) {
            await loadExports()
        }
    }

    private func canShareExport(_ status: ExportVerificationStatus) -> Bool {
        switch status {
        case .serverFailed, .queued, .processing, .verifying, .missingPath, .invalidURL:
            return false
        case .ready, .unknown, .verificationFailed:
            return true
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
        MMEditorialHeader(
            eyebrow: "MoveMark",
            title: "Exports",
            subtitle: "Reports and packets for your current vault."
        )
    }

    private var noVaultSelectedState: some View {
        MMCard(tone: .quiet, padding: 18, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                exportArtifactPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a vault to see exports")
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Exports are tied to the property you have open. Open a vault from the home list, then return here.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showOpenVaultsCTA {
                    MMButton(
                        title: "Open a vault",
                        action: { onOpenVaults?() },
                        kind: .secondary,
                        size: .standard
                    )
                    .padding(.top, 2)
                }
            }
        }
    }

    private var emptyState: some View {
        MMCard(tone: .quiet, padding: 18, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                exportArtifactPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text("No exports for this vault yet")
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Move-in reports, move-out reports, and dispute packets you generate for this property will appear here.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showOpenVaultsCTA {
                    MMButton(
                        title: "Open a vault to export",
                        action: { onOpenVaults?() },
                        kind: .secondary,
                        size: .standard
                    )
                    .padding(.top, 2)
                }
            }
        }
    }

    private var exportArtifactPreview: some View {
        MMArtifactSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("REPORT PREVIEW")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(MoveMarkTheme.Colors.accent)

                    Spacer()

                    Image(systemName: "doc.richtext")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 118, height: 8)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 160, height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.18))
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
            .background(Color.white.opacity(0.05))
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

        return MMCard(tone: .quiet, padding: 16, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                exportRowThumbnail(for: row)

                VStack(alignment: .leading, spacing: 8) {
                    Text(label(for: row.exportType))
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    HStack(spacing: 8) {
                        Text(formattedDate(row.createdAt))
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                        Text("·")
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.5))

                        exportStatusLabel(status)
                    }

                    Text(shortPath(row.filePath))
                        .font(MoveMarkTheme.Typography.caption)
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

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 8) {
                    MMButton(
                        title: "Share",
                        action: { share(row) },
                        kind: .secondary,
                        size: .compact,
                        isDisabled: !canShareExport(status),
                        expandsToFillWidth: false
                    )

                    if shouldShowVerifyButton(for: status) {
                        MMButton(
                            title: status == .verifying ? "Verifying…" : "Verify",
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
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
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
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 22, height: 4)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 30, height: 3)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.16))
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
                    .foregroundStyle(MoveMarkTheme.Colors.primary)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

        case .verifying:
            Text(status.displayLabel)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

        case .unknown:
            Text(status.displayLabel)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))

        case .queued:
            HStack(spacing: 4) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

        case .processing:
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

        case .missingPath, .invalidURL, .verificationFailed, .serverFailed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)

                Text(status.displayLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(.orange.opacity(0.95))
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
            } catch let api as APIClientError {
                if case .exportNotReady = api {
                    verificationStatus[row.id] = .processing
                } else {
                    verificationStatus[row.id] = .verificationFailed(
                        MoveMarkFlowMessage.exportOrAPIFailed(
                            api,
                            fallback: "Verification failed. Try again."
                        )
                    )
                }
            } catch {
                verificationStatus[row.id] = .verificationFailed(
                    MoveMarkFlowMessage.exportOrAPIFailed(
                        error,
                        fallback: "Verification failed. Try again."
                    )
                )
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

        guard let currentPropertyId = propertyStore.currentProperty?.id else {
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
        }
    }

    private func share(_ row: ExportRow) {
        Task { @MainActor in
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
                successBanner = "Download link ready — use Share to save or send."
            } catch let api as APIClientError {
                if case .exportNotReady = api {
                    verificationStatus[row.id] = .processing
                    successBanner = nil
                    errorMessage = nil
                } else {
                    let mapped = MoveMarkFlowMessage.exportOrAPIFailed(
                        api,
                        fallback: "Couldn’t prepare download. Try again."
                    )
                    verificationStatus[row.id] = .verificationFailed(mapped)
                    errorMessage = mapped
                }
            } catch {
                let mapped = MoveMarkFlowMessage.exportOrAPIFailed(
                    error,
                    fallback: "Couldn’t prepare download. Try again."
                )
                verificationStatus[row.id] = .verificationFailed(mapped)
                errorMessage = mapped
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
