//
//  MMLifecycleNudgeCard.swift
//  movemork
//

import SwiftUI

struct MMLifecycleNudgeCard: View {
    let nudge: PropertyStore.LifecycleNudge
    let action: () -> Void

    var body: some View {
        ProofTaskCard(
            title: nudge.title,
            reason: nudge.reason,
            action: action
        )
    }
}
