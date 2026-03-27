//
//  MMTextField.swift
//  movemork
//
//  MoveMark — Styled text and secure field; slimmer label and shell.
//

import SwiftUI

struct MMTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(title.lowercased().contains("email") ? .emailAddress : .default)
                }
            }
            .font(MoveMarkTheme.Typography.body)
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.72), lineWidth: 0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
