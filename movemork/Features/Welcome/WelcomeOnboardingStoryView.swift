//
//  WelcomeOnboardingStoryView.swift
//  movemork
//
//  Pre-auth pain → proof → report story pager.
//

import SwiftUI

struct WelcomeOnboardingStoryView: View {
    @Binding var page: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps = MoveMarkGrowthCopy.onboardingStorySteps

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TabView(selection: $page) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(step.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(step.body)
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 108)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: page)

            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == page
                                ? MoveMarkTheme.Colors.primary.opacity(0.9)
                                : MoveMarkTheme.Colors.textSecondary.opacity(0.28)
                        )
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
        }
    }
}
