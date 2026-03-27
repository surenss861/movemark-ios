//
//  VaultCoverExpansionContent.swift
//  movemork
//
//  Data for the expandable tray below the vault cover card. Built when we have full property data.
//

import SwiftUI

struct VaultCoverExpansionContent {
    let roomsText: String
    let openIssuesText: String
    let lastUpdated: String?
    let nextRoomLine: String?
    let progress: Double
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void
}
