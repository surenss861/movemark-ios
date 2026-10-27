//
//  AuthenticatedShellView.swift
//  movemork
//
//  MoveMark — One NavigationStack, Vault root, path-based pushes and local sheets.
//

import SwiftUI

struct AuthenticatedShellView: View {
    @Binding var path: [AppRoute]
    @Namespace private var vaultNamespace

    var body: some View {
        NavigationStack(path: $path) {
            VaultRootView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .vaultDetail(let propertyId):
                        VaultDetailDestinationView(propertyId: propertyId, path: $path)
                    case .walkthrough:
                        RoomListView(path: $path)
                    case .roomDetail(let roomID):
                        RoomDetailDestinationView(roomID: roomID, path: $path)
                    case .maintenance:
                        MaintenanceLogView(path: $path)
                    case .maintenanceIssueDetail(let issueID):
                        MaintenanceIssueDetailContainerView(issueID: issueID)
                    case .moveOut:
                        MoveOutFoundationView(path: $path)
                    case .moveOutRoomDetail(let roomID):
                        MoveOutRoomDetailDestinationView(roomID: roomID, path: $path)
                    case .exports:
                        ExportHistoryView()
                    }
                }
        }
        .environment(\.vaultTransitionNamespace, vaultNamespace)
    }
}

// MARK: - Vault detail (property workspace; currentProperty set by dashboard before push)
struct VaultDetailDestinationView: View {
    let propertyId: UUID
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @Environment(\.vaultTransitionNamespace) private var vaultNamespace

    var body: some View {
        Group {
            if let property = propertyStore.currentProperty, property.id == propertyId {
                PropertyVaultView(property: property, path: $path, namespace: vaultNamespace)
            } else {
                // The rental record's own shape while it loads, so the push lands on the screen it becomes.
                MMRentalRecordSkeleton()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if propertyStore.currentProperty?.id != propertyId, let userId = sessionManager.userId {
                Task {
                    await propertyStore.selectProperty(id: propertyId, userId: userId)
                }
            }
        }
    }
}

// MARK: - Room detail (resolve name from store)
private struct RoomDetailDestinationView: View {
    let roomID: UUID
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore

    var body: some View {
        let room = propertyStore.currentProperty?.rooms.first(where: { $0.id == roomID })
        EvidenceCaptureView(
            roomID: roomID, roomName: room?.name ?? "Room", moveOutMode: false,
            // The receipt's next room replaces this one, so Back still returns to where capture started.
            onOpenRoom: { next in if !path.isEmpty { path[path.count - 1] = .roomDetail(roomID: next) } },
            onOpenReport: { path.append(.exports) }
        )
    }
}

// MARK: - Move-out room detail (same capture UI in move-out mode)
private struct MoveOutRoomDetailDestinationView: View {
    let roomID: UUID
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore

    var body: some View {
        let room = propertyStore.currentProperty?.rooms.first(where: { $0.id == roomID })
        EvidenceCaptureView(
            roomID: roomID, roomName: room?.name ?? "Room", moveOutMode: true,
            onOpenRoom: { next in if !path.isEmpty { path[path.count - 1] = .moveOutRoomDetail(roomID: next) } },
            onOpenReport: { path.append(.exports) }
        )
    }
}
