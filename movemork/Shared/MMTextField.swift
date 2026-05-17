//
//  MMTextField.swift
//  movemork
//
//  MoveMark — Dark inset fields for auth forms.
//

import SwiftUI
import UIKit

struct MMTextField: View {
    enum Density {
        case standard
        /// Auth intake — tighter label + 56pt control.
        case authCompact
    }

    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var density: Density = .standard

    private var labelSpacing: CGFloat {
        density == .authCompact ? 5 : 8
    }

    private var fieldHeight: CGFloat {
        density == .authCompact ? 56 : 54
    }

    private var titleFont: Font {
        density == .authCompact
            ? .system(size: 12.5, weight: .semibold)
            : .system(size: 13.5, weight: .semibold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(MoveMarkTheme.Typography.body)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }

                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(keyboardType)
                    }
                }
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .tint(MoveMarkTheme.Colors.proofMint)
                .padding(.horizontal, 16)
            }
            .frame(height: fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.subtleStroke, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    .padding(1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
