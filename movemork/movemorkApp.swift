//
//  movemorkApp.swift
//  movemork
//
//  MoveMark — Protect your deposit. Prove your case.
//

import SwiftUI

@main
struct movemorkApp: App {
    @State private var sessionManager = SessionManager()
    @State private var propertyStore = PropertyStore()
    @State private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(sessionManager)
                .environment(propertyStore)
                .environment(subscriptionManager)
                .preferredColorScheme(.dark)
        }
    }
}
