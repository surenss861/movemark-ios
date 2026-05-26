//
//  PropertyStore+Lifecycle.swift
//  movemork
//
//  Retention nudges: move-in week, lease docs, mid-lease, move-out.
//

import Foundation

extension PropertyStore {

    enum LifecycleNudge: Equatable {
        case finishRoomsBeforeUnpacking(remaining: Int)
        case addLeaseAndDepositDocs
        case makeMoveInReport
        case midLeaseMaintenance(issueCount: Int)
        case moveOutProofReminder(daysUntilEnd: Int?)

        var title: String {
            switch self {
            case .finishRoomsBeforeUnpacking(let remaining):
                return remaining == 1 ? "Finish 1 more room" : "Finish \(remaining) more rooms"
            case .addLeaseAndDepositDocs:
                return "Add lease & deposit receipt"
            case .makeMoveInReport:
                return "Make your move-in report"
            case .midLeaseMaintenance(let count):
                return count == 1 ? "Log 1 maintenance issue" : "Review \(count) open issues"
            case .moveOutProofReminder:
                return "Start move-out proof"
            }
        }

        var reason: String {
            switch self {
            case .finishRoomsBeforeUnpacking:
                return "Document rooms before you fully unpack — while damage is still visible."
            case .addLeaseAndDepositDocs:
                return "Lease and deposit records strengthen your proof if money is disputed."
            case .makeMoveInReport:
                return "Your room proof is ready — export a PDF before you need it."
            case .midLeaseMaintenance:
                return "Timestamp repairs and issues while you still live there."
            case .moveOutProofReminder(let days):
                if let days, days > 0 {
                    return "Lease ends in \(days) days — re-capture rooms before you return keys."
                }
                return "Re-capture each room before move-out so you have before-and-after proof."
            }
        }
    }

    func lifecycleNudge(for property: PropertyRecord) -> LifecycleNudge? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let moveIn = calendar.startOfDay(for: property.moveInDate)
        let daysSinceMoveIn = calendar.dateComponents([.day], from: moveIn, to: today).day ?? 0

        let total = totalRoomCount(for: property)
        let documented = documentedRoomCount(for: property)
        let missingDocs = missingSupportingRecordCount(for: property)

        if total > 0, documented < total, daysSinceMoveIn <= 5 {
            return .finishRoomsBeforeUnpacking(remaining: total - documented)
        }

        if missingDocs > 0, daysSinceMoveIn >= 3, daysSinceMoveIn <= 21 {
            return .addLeaseAndDepositDocs
        }

        if isExportReady(for: property), documented == total, total > 0 {
            return .makeMoveInReport
        }

        let issues = openIssueCount(for: property)
        if issues > 0, daysSinceMoveIn >= 14 {
            return .midLeaseMaintenance(issueCount: issues)
        }

        let leaseEnd = property.leaseEndDate
        if leaseEnd.timeIntervalSince1970 > 0 {
            let end = calendar.startOfDay(for: leaseEnd)
            let daysUntil = calendar.dateComponents([.day], from: today, to: end).day ?? 999
            if daysUntil <= 45, daysUntil >= 0 {
                let moveOutDone = moveOutDocumentedRoomCount(for: property)
                if moveOutDone < documented || documented == 0 {
                    return .moveOutProofReminder(daysUntilEnd: max(daysUntil, 0))
                }
            }
        } else if daysSinceMoveIn >= 330, documented > 0 {
            let moveOutDone = moveOutDocumentedRoomCount(for: property)
            if moveOutDone < documented {
                return .moveOutProofReminder(daysUntilEnd: nil)
            }
        }

        return nil
    }
}
