//
//  VaultTransitionNamespaceKey.swift
//  movemork
//
//  Shared namespace for matchedGeometryEffect from vault card to detail header.
//

import SwiftUI

struct VaultTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var vaultTransitionNamespace: Namespace.ID? {
        get { self[VaultTransitionNamespaceKey.self] }
        set { self[VaultTransitionNamespaceKey.self] = newValue }
    }
}
