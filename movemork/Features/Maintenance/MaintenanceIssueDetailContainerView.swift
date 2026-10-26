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

    private let repo = MaintenanceRepository()

    init(issueID: UUID, initialIssue: MaintenanceIssueRow? = nil, initialError: String? = nil) {
        self.issueID = issueID
        _issue = State(initialValue: initialIssue)
        _loadError = State(initialValue: initialError)
    }

    var body: some View {
        Group {
            if let issue {
                MaintenanceIssueDetailView(issue: issue)
            } else if let loadError {
                MMScreen(title: "Issue not found", isPushed: true) {
                    MMEmptyBlock(
                        icon: "wrench.and.screwdriver",
                        title: "This issue isn't available",
                        message: loadError
                    )
                    .frame(minHeight: 420, alignment: .top)
                }
            } else {
                MMScreen(title: "Maintenance issue", isPushed: true) {
                    HStack(spacing: 10) {
                        ProgressView().tint(MMInk.secondary)
                        Text("Loading issue…").mmFont(14).foregroundStyle(MMInk.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 420, alignment: .top)
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
        }
    }
}
