//
//  SubscriptionManager.swift
//  movemork
//
//  Single source of truth for Pro / paywalled features. Do not duplicate entitlement logic elsewhere.
//  `hasPro` follows RevenueCat entitlement id `movemark_pro1` (Product catalog → Entitlements).
//

import Foundation
import Observation
import OSLog
import RevenueCat

private let subscriptionLog = Logger(subsystem: "movemark.movemork", category: "Subscription")

@MainActor
@Observable
final class SubscriptionManager {
    var hasPro: Bool = false
    var isLoading: Bool = false
    var lastErrorMessage: String? = nil
    var currentOffering: Offering? = nil

    private let proEntitlementID = "movemark_pro1"
    private var hasStartedCustomerInfoListener = false
    private var lastKnownAppUserID: String? = nil

    private let freeMoveInExportCountKey = "MoveMark.freeMoveInExportCount"

    var freeMoveInExportCount: Int {
        UserDefaults.standard.integer(forKey: freeMoveInExportCountKey)
    }

    func incrementFreeMoveInExportCount() {
        let next = freeMoveInExportCount + 1
        UserDefaults.standard.set(next, forKey: freeMoveInExportCountKey)
    }

    func canExportMoveIn() -> Bool {
        hasPro || freeMoveInExportCount < 1
    }

    func remainingFreeMoveInExportsText() -> String {
        if hasPro {
            return "Unlimited move-in exports with Pro"
        }

        let remaining = max(0, 1 - freeMoveInExportCount)
        if remaining == 1 {
            return "1 free move-in export remaining"
        } else {
            return "Free move-in export used"
        }
    }

    func configure(appUserID: String? = nil) {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        // Production / TestFlight: keep logs low; use RevenueCat dashboard for diagnostics.
        Purchases.logLevel = .warn
        #endif

        if !Purchases.isConfigured {
            let apiKey = Self.resolvedRevenueCatPublicAPIKey
            guard Self.isValidRevenueCatPublicKey(apiKey) else {
                lastErrorMessage = Self.userFacingRevenueCatKeyError(resolvedKey: apiKey)
                subscriptionLog.error(
                    "RevenueCat API key missing or invalid. Prefix: \(Self.keyDiagnosticPrefix(apiKey), privacy: .public) plistKey=RevenueCatPublicAPIKey"
                )
                return
            }

            var builder = Configuration.Builder(withAPIKey: apiKey)

            if let appUserID, !appUserID.isEmpty {
                builder = builder.with(appUserID: appUserID)
                lastKnownAppUserID = appUserID
            }

            Purchases.configure(with: builder.build())
            #if !DEBUG
            // TestFlight / App Store: verify embedded key in Console (category Subscription) without logging the full secret.
            subscriptionLog.notice(
                "RevenueCat configured (App Store key prefix \(Self.keyDiagnosticPrefix(apiKey), privacy: .public))"
            )
            #endif
        }

        // Never touch Purchases.shared before configure — that crashes at runtime.
        guard Purchases.isConfigured else { return }
        startCustomerInfoListenerIfNeeded()
    }

    /// App Store public SDK key (`appl_…`) from merged Info.plist `RevenueCatPublicAPIKey` → `$(REVENUECAT_APP_STORE_PUBLIC_KEY)`, or scheme env `REVENUECAT_PUBLIC_API_KEY`.
    private static var resolvedRevenueCatPublicAPIKey: String {
        let fromPlist = revenueCatPublicAPIKeyFromBundle()
        if !fromPlist.isEmpty { return fromPlist }

        let fromEnv = ProcessInfo.processInfo.environment["REVENUECAT_PUBLIC_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromEnv
    }

    /// Runtime key is **always** `RevenueCatPublicAPIKey` (not the Xcode setting name `REVENUECAT_APP_STORE_PUBLIC_KEY`).
    private static func revenueCatPublicAPIKeyFromBundle() -> String {
        let key = "RevenueCatPublicAPIKey"
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let s = Bundle.main.infoDictionary?[key] as? String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func userFacingRevenueCatKeyError(resolvedKey: String) -> String {
        let trimmed = resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Subscription setup is incomplete. Rebuild the app with a valid RevenueCat App Store key (appl_…)."
        }
        if trimmed.hasPrefix("$(") {
            return "Subscription key didn’t embed in this build. Clean build, re-archive, and try again."
        }
        if trimmed.contains("REPLACE") {
            return "Replace the RevenueCat placeholder key in build settings with your App Store public key (appl_…)."
        }
        if trimmed.hasPrefix("test_") {
            return "Use the App Store public SDK key (appl_…), not a Test Store key, in build settings."
        }
        if !trimmed.hasPrefix("appl_") {
            return "Invalid subscription key. Use the App Store public key from RevenueCat (appl_…)."
        }
        return "Subscriptions couldn’t start. Check the RevenueCat App Store key in Xcode."
    }

    private static func isValidRevenueCatPublicKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        if key.contains("REPLACE") { return false }
        if key.hasPrefix("$(") { return false }
        if key.hasPrefix("test_") { return false }
        if !key.hasPrefix("appl_") { return false }
        return true
    }

    /// Maps RevenueCat / StoreKit errors to short paywall-safe copy (details go to logs).
    private static func userFacingRevenueCatOperationError(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lower = raw.lowercased()

        if lower.contains("missing app store connect api credentials")
            || (lower.contains("app store connect") && lower.contains("credential") && lower.contains("missing")) {
            return "Plans aren’t loading. Finish App Store Connect API setup in RevenueCat, then try again."
        }

        if lower.contains("could not fetch") && lower.contains("app store connect") {
            return "Plans couldn’t load. Check RevenueCat and App Store Connect, then try again."
        }

        if lower.contains("missing_metadata") || lower.contains("missing metadata") {
            return "Plans aren’t ready in App Store Connect yet. Complete subscription metadata, then try again."
        }

        if lower.contains("not found") && (lower.contains("app store") || lower.contains("product")) {
            return "Plans aren’t available. Remove stale products in RevenueCat and match App Store Connect IDs."
        }

        if raw.count > 160 {
            return "Plans couldn’t load. Try again later."
        }

        return raw
    }

    /// Safe for logs: whether the key looks substituted, plus a short prefix (never log full keys).
    private static func keyDiagnosticPrefix(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "(empty)" }
        if trimmed.hasPrefix("$(") { return "(unexpanded $(…) — check Info.plist RevenueCatPublicAPIKey / REVENUECAT_APP_STORE_PUBLIC_KEY)" }
        let prefix = String(trimmed.prefix(6))
        return "\(prefix)…"
    }

    private func startCustomerInfoListenerIfNeeded() {
        guard Purchases.isConfigured else { return }
        guard !hasStartedCustomerInfoListener else { return }
        hasStartedCustomerInfoListener = true

        Task { @MainActor in
            for await customerInfo in Purchases.shared.customerInfoStream {
                hasPro = customerInfo.entitlements[proEntitlementID]?.isActive == true
            }
        }
    }

    func syncAuth(appUserID: String?) async {
        // Pass user into initial configure when possible; RevenueCat truth still comes from logIn + refresh.
        configure(appUserID: appUserID)
        guard Purchases.isConfigured else { return }

        let normalizedID: String? = {
            guard let appUserID, !appUserID.isEmpty else { return nil }
            return appUserID
        }()

        do {
            if let normalizedID {
                // Always log in when we have an app user ID so CustomerInfo stays aligned after dashboard/offering changes.
                let result = try await Purchases.shared.logIn(normalizedID)
                hasPro = result.customerInfo.entitlements[proEntitlementID]?.isActive == true
                lastKnownAppUserID = normalizedID
            } else if lastKnownAppUserID != nil {
                let customerInfo = try await Purchases.shared.logOut()
                hasPro = customerInfo.entitlements[proEntitlementID]?.isActive == true
                lastKnownAppUserID = nil
            }

            await refresh()
        } catch {
            lastErrorMessage = Self.userFacingRevenueCatOperationError(error)
        }
    }

    /// - Parameter showLoading: When false, skips toggling `isLoading` (use after purchase/restore to avoid UI flicker).
    func refresh(showLoading: Bool = true) async {
        guard Purchases.isConfigured else {
            if lastErrorMessage == nil {
                lastErrorMessage = "Subscription options aren’t available until the app finishes setup."
            }
            return
        }

        if showLoading {
            isLoading = true
        }
        defer {
            if showLoading {
                isLoading = false
            }
        }

        do {
            subscriptionLog.notice(
                "refresh start isConfigured=true entitlementID=\(self.proEntitlementID, privacy: .public)"
            )

            let customerInfo = try await Purchases.shared.customerInfo()
            let proActive = customerInfo.entitlements[proEntitlementID]?.isActive == true
            subscriptionLog.notice("refresh customerInfo OK hasPro=\(proActive, privacy: .public)")

            let offerings = try await Purchases.shared.offerings()

            hasPro = proActive
            currentOffering = offerings.current

            if let current = offerings.current {
                let packageIDs = current.availablePackages.map(\.storeProduct.productIdentifier)
                let rcPackageIDs = current.availablePackages.map(\.identifier)
                let count = current.availablePackages.count
                subscriptionLog.notice(
                    "refresh offerings OK current=\(current.identifier, privacy: .public) packageCount=\(count, privacy: .public) storeProductIDs=\(String(describing: packageIDs), privacy: .public) rcPackageIDs=\(String(describing: rcPackageIDs), privacy: .public)"
                )

                if current.availablePackages.isEmpty {
                    subscriptionLog.notice("refresh offerings current has zero packages (check RevenueCat packages / ASC)")
                    lastErrorMessage = "Plans aren’t available yet. Check your default offering and packages in RevenueCat."
                } else {
                    lastErrorMessage = nil
                }
            } else {
                subscriptionLog.notice("refresh offerings OK current=nil (no default offering in RevenueCat)")
                lastErrorMessage = "No default subscription offering in RevenueCat. Set a current offering with packages."
            }
        } catch {
            lastErrorMessage = Self.userFacingRevenueCatOperationError(error)
            let ns = error as NSError
            subscriptionLog.error(
                "RevenueCat refresh failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) description=\(ns.localizedDescription, privacy: .public)"
            )
        }
    }

    func purchase(package: Package) async throws {
        guard Purchases.isConfigured else {
            throw NSError(
                domain: "MoveMark.Subscription",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "RevenueCat is not configured. Check your API key for this build."]
            )
        }

        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        hasPro = result.customerInfo.entitlements[proEntitlementID]?.isActive == true
        lastErrorMessage = nil
        await refresh(showLoading: false)
    }

    func restorePurchases() async throws {
        guard Purchases.isConfigured else {
            throw NSError(
                domain: "MoveMark.Subscription",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "RevenueCat is not configured. Check your API key for this build."]
            )
        }

        isLoading = true
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        hasPro = customerInfo.entitlements[proEntitlementID]?.isActive == true
        lastErrorMessage = nil
        await refresh(showLoading: false)
    }

    func canCreateProperty(currentCount: Int) -> Bool {
        hasPro || currentCount < 1
    }

    func canUseCaseBuilder() -> Bool {
        hasPro
    }

    func canExportMoveOut() -> Bool {
        hasPro
    }

    func currentCountSummary(currentPropertyCount: Int) -> String {
        if hasPro {
            return "Unlimited vaults and exports"
        }

        if currentPropertyCount == 0 {
            return "Free · 1 property included"
        }

        if currentPropertyCount == 1 {
            return "Free · 1 of 1 property used"
        }

        return "Free · property limit reached"
    }
}
