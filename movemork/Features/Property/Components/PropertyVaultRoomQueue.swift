//
//  PropertyVaultRoomQueue.swift
//  movemork
//
//  Room queue rail: header + horizontal RoomStatusCards.
//

import SwiftUI

struct PropertyVaultRoomQueue: View {
    let rooms: [RoomRecord]
    let nextRoomID: UUID?
    let pulseQueueHeadRoomId: UUID?
    let completedRooms: Int
    let totalRooms: Int
    let onSeeAll: () -> Void
    let onOpenRoom: (RoomRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rooms")
                        .font(MoveMarkTheme.Typography.captionEmphasis)
                        .tracking(0.8)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .textCase(.uppercase)

                    Text("\(completedRooms) of \(totalRooms) documented")
                        .font(MoveMarkTheme.Typography.detail)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))

                    if completedRooms < totalRooms {
                        Text("Tap a room to add proof")
                            .font(MoveMarkTheme.Typography.tinyMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.62))
                    }
                }

                Spacer()

                Button("See all", action: onSeeAll)
                    .font(MoveMarkTheme.Typography.detailEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(rooms) { room in
                        RoomStatusCard(
                            room: room,
                            isNext: room.id == nextRoomID,
                            isPulsing: room.id == pulseQueueHeadRoomId,
                            onTap: { onOpenRoom(room) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
