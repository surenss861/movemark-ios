//
//  HomeScreen.swift
//  movemork
//
//  MoveMark — Clean launch: loading, vault, or empty state.
//

import SwiftUI

struct HomeScreen: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore
    @State private var showAddProperty = false
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                MoveMarkTheme.Colors.background.ignoresSafeArea()

                if shouldShowLoading {
                    loadingState
                } else if propertyStore.currentProperty != nil {
                    DashboardView(path: $path)
                } else {
                    emptyState
                }
            }
        }
        .sheet(isPresented: $showAddProperty) {
            NewPropertyView()
        }
        .task {
            if let userId = sessionManager.userId {
                await propertyStore.fetchAll(userId: userId)
            }
        }
    }

    private var shouldShowLoading: Bool {
        guard sessionManager.userId != nil else { return false }
        return !propertyStore.hasCompletedInitialFetch || propertyStore.isLoading
    }

    private var loadingState: some View {
        MMLoadingState(message: MMCopy.loadingProofTrail)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let error = propertyStore.errorMessage {
                    MMErrorBanner(
                        message: error,
                        retryTitle: MMCopy.tryAgain,
                        onRetry: {
                            Task {
                                if let userId = sessionManager.userId {
                                    await propertyStore.fetchAll(userId: userId)
                                }
                            }
                        }
                    )
                } else {
                    MMCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "Start here")

                            Text("No property yet")
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                            Text("Create your first property vault, then start capturing move-in proof room by room.")
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            MMButton(title: "Add property") {
                                print("🏠 Add property tapped")
                                showAddProperty = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Home")
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text("Your renter proof system starts here.")
                    .font(MoveMarkTheme.Typography.body)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Rectangle()
                    .fill(MoveMarkTheme.Colors.accent)
                    .frame(width: 38, height: 3)
                    .clipShape(Capsule())
            }

            Spacer()

            Button("Sign out") {
                propertyStore.clear()
                Task { await sessionManager.signOut() }
            }
            .font(MoveMarkTheme.Typography.subheadlineMedium)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }
}
