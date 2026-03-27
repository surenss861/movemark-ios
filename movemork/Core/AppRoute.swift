//
//  AppRoute.swift
//  movemork
//
//  MoveMark — Push routing for authenticated app shell.
//

import Foundation

enum AppRoute: Hashable {
    case vaultDetail(propertyId: UUID)
    case walkthrough
    case roomDetail(roomID: UUID)
    case maintenance
    case maintenanceIssueDetail(issueID: UUID)
    case moveOut
    case moveOutRoomDetail(roomID: UUID)
    case disputeBuilder
    case exports
    case account
}
