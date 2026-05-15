//
//  MMActionPill.swift
//  movemork
//
//  Segmented pill control — strong selected fill, quiet inactive.
//

import SwiftUI

struct MMActionPill<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    @Namespace private var pillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    guard selection != option else { return }
                    MMHaptics.selection()
                    withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(
                            isSelected
                                ? MoveMarkTheme.Colors.textOnPrimary
                                : MoveMarkTheme.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(MoveMarkTheme.Colors.primary)
                                    .matchedGeometryEffect(id: "pill", in: pillNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MoveMarkTheme.Colors.mint.opacity(0.5))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1))
    }
}
