//
//  MMTextField.swift
//  movemork
//
//  MoveMark — Dark inset fields for auth forms.
//

import SwiftUI
import UIKit

struct MMTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
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
            .frame(height: 54)
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
