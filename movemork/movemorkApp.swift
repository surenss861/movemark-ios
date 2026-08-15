//
//  movemorkApp.swift
//  movemork
//
//  MoveMark — Protect your deposit. Prove your case.
//

import Sentry
import SwiftUI

@main
struct movemorkApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://b1bf88391a6e0a03d52c1006cd029d19@o4510691451666432.ingest.us.sentry.io/4511664827596800"
            options.debug = false
            options.sendDefaultPii = false
            options.tracesSampleRate = 0.0
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version) (\(build))"
            }
        }
    }

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
                .onAppear {
                    MoveMarkAnalytics.track(.appOpened)
                }
        }
    }
}
