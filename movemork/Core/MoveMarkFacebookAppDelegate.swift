//
//  MoveMarkFacebookAppDelegate.swift
//  movemork
//
//  Minimal UIApplicationDelegate hooks required by Meta App Events.
//

import FacebookCore
import UIKit

final class MoveMarkFacebookAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MoveMarkMetaAppEvents.configureOnLaunch()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        MoveMarkMetaAppEvents.activateApp()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard MoveMarkMetaAppEvents.isConfigured else { return false }
        return ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation]
        )
    }
}
