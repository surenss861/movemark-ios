//
//  DashboardView.swift
//  movemork
//
//  MoveMark — Vault-first authenticated home; routes into PropertyVaultView.
//

import SwiftUI

struct DashboardView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore

    var body: some View {
        if let property = propertyStore.currentProperty {
            PropertyVaultView(property: property, path: $path)
        } else {
            EmptyView()
        }
    }
}
