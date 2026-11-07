//
//  MaintenanceIssueDetailContainerView.swift
//  movemork
//
//  MoveMark — Loads issue by ID for path-based navigation, then shows detail.
//

import SwiftUI

struct MaintenanceIssueDetailContainerView: View {
    let issueID: UUID
    @Environment(PropertyStore.self) private var propertyStore

    @State private var issue: MaintenanceIssueRow?
    @State private var loadError: String?
    /// The lookup itself failed (network / server), as opposed to the case not existing: offer Try again.
    @State private var lookupFailed = false

    private let repo = MaintenanceRepository()

    init(issueID: UUID, initialIssue: MaintenanceIssueRow? = nil, initialError: String? = nil, initialLookupFailed: Bool = false) {
        self.issueID = issueID
        _issue = State(initialValue: initialIssue)
        _loadError = State(initialValue: initialError)
        _lookupFailed = State(initialValue: initialLookupFailed)
    }

    var body: some View {
        Group {
            if let issue {
                MaintenanceIssueDetailView(issue: issue)
            } else if let loadError, lookupFailed {
                MMScreen(eyebrow: "Maintenance case", title: "Couldn't open this case", isPushed: true) {
                    MMEmptyBlock(
                        icon: "wrench.and.screwdriver",
                        title: "The case file didn't load",
                        message: loadError,
                        actionTitle: MMCopy.tryAgain,
                        action: { Task { await loadIssue() } }
                    )
                }
            } else if let loadError {
                MMScreen(eyebrow: "Maintenance case", title: "Case not found", isPushed: true) {
                    MMEmptyBlock(
                        icon: "wrench.and.screwdriver",
                        title: "This case isn't available",
                        message: loadError
                    )
                }
            } else {
                MMScreen(eyebrow: "Maintenance case", title: "Opening case", isPushed: true) {
                    HStack(spacing: 10) {
                        ProgressView().tint(MMInk.secondary)
                        Text("Loading the case file…").mmFont(14).foregroundStyle(MMInk.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 40)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard issue == nil, loadError == nil else { return }
            await loadIssue()
        }
    }

    private func loadIssue() async {
        loadError = nil
        lookupFailed = false
        guard let property = propertyStore.currentProperty else {
            loadError = MoveMarkFlowMessage.noActiveProperty
            return
        }
        do {
            let found = try await repo.fetchIssue(id: issueID)
            // Guard against a stale link to a different property's issue.
            issue = found?.propertyId == property.id ? found : nil
            if issue == nil { loadError = MoveMarkFlowMessage.maintenanceIssueNotFound }
        } catch {
            loadError = MoveMarkFlowMessage.maintenanceIssueLookupFailed(error)
            lookupFailed = true
        }
    }
}
