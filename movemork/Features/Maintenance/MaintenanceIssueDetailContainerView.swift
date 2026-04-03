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

    var body: some View {
        Group {
            if let issue {
                MaintenanceIssueDetailView(issue: issue)
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.largeTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    Text("Issue not found")
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    Text(loadError)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await loadIssue() }
    }

    private func loadIssue() async {
        guard let property = propertyStore.currentProperty else {
            loadError = MoveMarkFlowMessage.noActiveProperty
            return
        }
        do {
            let issues = try await repo.fetchIssues(propertyId: property.id)
            issue = issues.first(where: { $0.id == issueID })
            if issue == nil { loadError = MoveMarkFlowMessage.maintenanceIssueNotFound }
        } catch {
            loadError = MoveMarkFlowMessage.maintenanceIssueLookupFailed(error)
        }
    }
}
