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
            // Without this every build reports as "production", so simulator/test-run hangs
            // (slow debug cold launches under xcodebuild) were firing production alerts.
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version) (\(build))"
            }
        }
    }

    @State private var sessionManager = SessionManager()
    @State private var propertyStore = PropertyStore()
    @State private var subscriptionManager = SubscriptionManager()

    #if DEBUG
    /// `-MMRichQA vault-9` renders one fixture case. Absent in release builds.
    private static var richQAScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-MMRichQA"), args.indices.contains(flag + 1) else { return nil }
        return args[flag + 1]
    }
    #endif

    private var signedInRoot: some View {
        AppRouter()
            .environment(sessionManager)
            .environment(propertyStore)
            .environment(subscriptionManager)
            .preferredColorScheme(.dark)
            .onAppear {
                MoveMarkAnalytics.track(.appOpened)
            }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let qaScreen = Self.richQAScreen {
                    MMRichQAGallery(screen: qaScreen)
                } else {
                    signedInRoot
                }
                #else
                signedInRoot
                #endif
            }
        }
    }
}
