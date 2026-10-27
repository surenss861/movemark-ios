//
//  MaintenanceLogView.swift
//  movemork
//
//  MoveMark — Maintenance log: the rental's case archive. Open cases first, then resolved, each read as a case —
//  evidence thumbnail when it has one, title, category, reported date, photo count, calm status. Recording a new
//  issue happens in its own sheet (MaintenanceNewIssueSheet), opened from the header's "+" or the empty state.
//

import SwiftUI

struct MaintenanceLogView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var errorRetryAction: (() -> Void)? = nil
    @State private var softNotice: String? = nil
    @State private var isRecording = false
    /// Newest photo per case, for the row thumbnails (best effort; a case without one shows no photo).
    @State private var covers: [UUID: EvidencePhoto] = [:]

    private var log: [MaintenanceRecord] {
        propertyStore.maintenanceLog
    }

    private var openIssues: [MaintenanceRecord] {
        log.filter { $0.status != .resolved }
    }

    private var resolvedIssues: [MaintenanceRecord] {
        log.filter { $0.status == .resolved }
    }

    init(path: Binding<[AppRoute]>, initialError: String? = nil, initialNotice: String? = nil, initiallyLoading: Bool = false,
         initialCovers: [UUID: EvidencePhoto] = [:]) {
        _path = path
        _covers = State(initialValue: initialCovers)
        _errorMessage = State(initialValue: initialError)
        _softNotice = State(initialValue: initialNotice)
        _isLoading = State(initialValue: initiallyLoading)
    }

    var body: some View {
        MMScreen(
            title: "Maintenance",
            subtitle: "Issues recorded for this rental.",
            isPushed: true,
            trailing: { headerBar }
        ) {
            if let errorMessage {
                MMNotice(
                    message: errorMessage,
                    actionTitle: errorRetryAction != nil ? MMCopy.tryAgain : nil,
                    action: errorRetryAction
                )
                .padding(.bottom, 18)
            } else if let softNotice {
                MMNotice(message: softNotice, tone: .info).padding(.bottom, 18)
            }

            caseList
        }
        // Re-sync when the active vault changes; list reads `propertyStore.maintenanceLog` (hydrated on switch + refreshed here).
        .task(id: propertyStore.currentProperty?.id) { await syncMaintenanceLogFromServer() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isRecording) {
            NavigationStack {
                MaintenanceNewIssueSheet(
                    onSaved: { notice in
                        isRecording = false
                        errorMessage = nil
                        errorRetryAction = nil
                        softNotice = notice
                        if let id = propertyStore.currentProperty?.id {
                            Task { await loadCovers(propertyId: id) }
                        }
                    },
                    onCancel: { isRecording = false }
                )
            }
        }
    }

    /// The pushed header's top row: MoveMark wordmark on the left, the "+" (Proof header language) on the right.
    private var headerBar: some View {
        HStack {
            Text("MoveMark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Button { isRecording = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Record an issue")
            .padding(.trailing, -6)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var caseList: some View {
        if log.isEmpty && isLoading {
            HStack(spacing: 10) {
                ProgressView().tint(MMInk.secondary)
                Text("Loading cases…").mmFont(14).foregroundStyle(MMInk.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .accessibilityElement(children: .combine)
        } else if log.isEmpty {
            MMEmptyBlock(
                icon: "doc.text.magnifyingglass",
                title: "No cases recorded",
                message: "When something happens, record it with photos and a date.",
                actionTitle: "Record an issue",
                action: { isRecording = true }
            )
        } else {
            VStack(alignment: .leading, spacing: 26) {
                caseSection(title: "Open", rows: openIssues)
                caseSection(title: "Resolved", rows: resolvedIssues)
            }
            if isLoading {
                ProgressView().tint(MMInk.secondary).frame(maxWidth: .infinity).padding(.top, 14)
            }
        }
    }

    @ViewBuilder
    private func caseSection(title: String, rows: [MaintenanceRecord]) -> some View {
        if !rows.isEmpty {
            MMGroup(title: "\(title) · \(rows.count)") {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { MMRowDivider(leading: 14) }
                    Button {
                        path.append(.maintenanceIssueDetail(issueID: entry.id))
                    } label: {
                        caseRow(entry)
                    }
                    .buttonStyle(MMLightPressStyle())
                }
            }
        }
    }

    private func caseRow(_ entry: MaintenanceRecord) -> some View {
        let cover = entry.photoCount > 0 ? covers[entry.id] : nil
        return MMCaseRow(
            title: entry.title,
            line: "\(entry.category) · Reported \(MMCaseDate.text(entry.createdAt, time: false))",
            photoCount: entry.photoCount,
            status: entry.status == .resolved ? .resolved : (entry.status == .followUp ? .followUp : .open),
            hasThumb: cover != nil
        ) {
            if let cover {
                MMEvidenceImage(path: cover.thumbnailPath ?? cover.filePath, resolve: resolvePhotoURL,
                                size: CGSize(width: 60, height: 60), placeholder: MMInk.field)
            }
        }
    }

    private func resolvePhotoURL(_ path: String) async -> URL? {
        try? await InspectionRepository().signedURL(bucket: "maintenance-media", path: path)
    }

    /// Thumbnails are a nicety: a failed read leaves the rows without photos and never raises an error.
    private func loadCovers(propertyId: UUID) async {
        guard let found = try? await InspectionRepository().maintenanceCoverPhotos(propertyId: propertyId) else { return }
        MoveMarkStoredFileURLs.remember(Array(found.values))
        covers = found
    }

    private func syncMaintenanceLogFromServer() async {
        guard let property = propertyStore.currentProperty else { return }
        isLoading = true
        errorMessage = nil
        errorRetryAction = nil
        defer { isLoading = false }

        let ok = await propertyStore.refreshMaintenance(propertyId: property.id)
        await loadCovers(propertyId: property.id)
        if !ok {
            errorMessage = MoveMarkFlowMessage.maintenanceListSyncFailed
            errorRetryAction = { Task { await syncMaintenanceLogFromServer() } }
        }
    }
}
