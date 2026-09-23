//
//  WelcomeLaunchControl.swift
//  movemork
//
//  Welcome-only — the primary launch control, layered over the hero video.
//

import SwiftUI

/// The Welcome CTA. Deliberately *not* `MMButton`.
///
/// `MMButton.primary` is a solid emerald slab: right on the app's own dark surfaces, wrong here.
/// Over video it becomes a second hero competing with the headline, and emerald stops meaning
/// "action" once it is also the largest block of colour on screen.
///
/// So the body is graphite and the emerald is spent on a single 44pt chip. The split is the
/// point — **body is the control, chip is the action** — and it is what makes the green read as
/// valuable rather than loud.
///
/// Scoped to Welcome. Every other primary CTA in the app still uses `MMButton`.
struct WelcomeLaunchControl: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            MMHaptics.light()
            action()
        } label: {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .buttonStyle(WelcomeLaunchControlStyle())
    }
}

private struct WelcomeLaunchControlStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return HStack(spacing: 12) {
            configuration.label
                .font(MoveMarkTheme.Typography.welcomeControl)
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            actionChip(pressed: pressed)
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(shape.fill(MoveMarkTheme.Colors.controlGraphite.opacity(0.90)))
        .overlay(shape.stroke(Color.white.opacity(0.11), lineWidth: 0.75))
        // Depth, never bloom. A green glow under this control would put emerald back on the
        // whole dock and undo the point of rationing it to the chip.
        .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 8)
        .contentShape(shape)
        .scaleEffect(pressed && !reduceMotion ? 0.985 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: pressed)
    }

    private func actionChip(pressed: Bool) -> some View {
        Circle()
            .fill(MoveMarkTheme.Colors.ctaActionEmerald)
            .frame(width: 44, height: 44)
            // A top-light rather than a gradient across the whole chip: it reads as a lit
            // physical object without turning into another shiny marketing button.
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .overlay(
                Image(systemName: "arrow.right")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: pressed && !reduceMotion ? 2 : 0)
            )
            // The chip carries the press: 7% darker, arrow 2pt forward.
            .brightness(pressed ? -0.07 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: pressed)
    }
}
