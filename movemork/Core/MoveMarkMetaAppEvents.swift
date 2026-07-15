//
//  MoveMarkMetaAppEvents.swift
//  movemork
//
//  Generic Meta App Events for ad attribution. Never log renter-sensitive data.
//

import FacebookCore
import Foundation

enum MoveMarkMetaAppEvents {
    private static let createProofVaultLoggedKey = "MoveMark.meta.createProofVaultLogged"
    private static let loggedGenerateReportIDsKey = "MoveMark.meta.loggedGenerateReportIDs"

    static var isConfigured: Bool {
        let appID = (Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let clientToken = (Bundle.main.object(forInfoDictionaryKey: "FacebookClientToken") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !appID.isEmpty && appID != "YOUR_FACEBOOK_APP_ID"
            && !clientToken.isEmpty && clientToken != "YOUR_FACEBOOK_CLIENT_TOKEN"
    }

    static func configureOnLaunch() {
        guard isConfigured else { return }
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = false
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
    }

    static func activateApp() {
        guard isConfigured else { return }
        AppEvents.shared.activateApp()
    }

    static func logCompleteRegistration() {
        log(.completedRegistration)
    }

    static func logCompleteTutorial() {
        log(.completedTutorial)
    }

    static func logViewContent() {
        log(
            .viewedContent,
            parameters: [
                AppEvents.ParameterName.contentType: "paywall",
                AppEvents.ParameterName.contentID: "movemark_pro",
            ]
        )
    }

    static func logInitiateCheckout() {
        log(
            .initiatedCheckout,
            parameters: [
                AppEvents.ParameterName.contentType: "subscription",
                AppEvents.ParameterName.contentID: "movemark_pro",
            ]
        )
    }

    static func logCreateProofVaultIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: createProofVaultLoggedKey) else { return }
        UserDefaults.standard.set(true, forKey: createProofVaultLoggedKey)
        log(AppEvents.Name("CreateProofVault"))
    }

    static func logGenerateReport(exportID: UUID) {
        var logged = Set(
            UserDefaults.standard.stringArray(forKey: loggedGenerateReportIDsKey) ?? []
        )
        let key = exportID.uuidString
        guard !logged.contains(key) else { return }
        logged.insert(key)
        UserDefaults.standard.set(Array(logged), forKey: loggedGenerateReportIDsKey)
        log(AppEvents.Name("GenerateReport"))
    }

    static func logSubscribe() {
        log(.subscribe)
    }

    static func logPurchase(amount: Decimal, currency: String) {
        guard isConfigured else { return }
        let nsAmount = NSDecimalNumber(decimal: amount)
        AppEvents.shared.logPurchase(
            amount: nsAmount.doubleValue,
            currency: currency.uppercased()
        )
        logSubscribe()
    }

    private static func log(_ name: AppEvents.Name, parameters: [AppEvents.ParameterName: Any]? = nil) {
        guard isConfigured else { return }
        if let parameters {
            AppEvents.shared.logEvent(name, parameters: parameters)
        } else {
            AppEvents.shared.logEvent(name)
        }
    }
}
