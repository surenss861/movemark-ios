//
//  SubscriptionManager.swift
//  movemork
//
//  Single source of truth for Pro / paywalled features. Do not duplicate entitlement logic elsewhere.
//  `hasPro` follows RevenueCat entitlement id `movemark_pro` only (dashboard must map products to it).
//

import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    var hasPro: Bool = false
    var isLoading: Bool = false
    var lastErrorMessage: String? = nil
    var currentOffering: Offering? = nil

    private let proEntitlementID = "movemark_pro"
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
                lastErrorMessage =
                    "Release build: set User-Defined setting REVENUECAT_APP_STORE_PUBLIC_KEY to your RevenueCat App Store public SDK key (appl_…). See docs/REVENUECAT_RELEASE.md."
                #if !DEBUG
                print("MoveMark: RevenueCat API key missing or invalid for Release. TestFlight needs appl_… from RevenueCat → API keys → App Store.")
                #endif
                return
            }

            var builder = Configuration.Builder(withAPIKey: apiKey)

            if let appUserID, !appUserID.isEmpty {
                builder = builder.with(appUserID: appUserID)
                lastKnownAppUserID = appUserID
            }

            Purchases.configure(with: builder.build())
        }

        // Never touch Purchases.shared before configure — that crashes at runtime.
        guard Purchases.isConfigured else { return }
        startCustomerInfoListenerIfNeeded()
    }

    /// Debug: RevenueCat **Test Store** key (simulator / local). Release: **App Store public SDK** key from Info.plist (injected at build time).
    private static var resolvedRevenueCatPublicAPIKey: String {
        #if DEBUG
        "test_rLVyLbkyJnzJsUyYSfldfttiiWQ"
        #else
        // Populated from target Release build setting → INFOPLIST_KEY_RevenueCatPublicAPIKey → merged Info.plist.
        let fromPlist = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !fromPlist.isEmpty { return fromPlist }

        // Optional: Xcode Scheme → Run/Archive → Environment Variables (CI or local overrides).
        let fromEnv = ProcessInfo.processInfo.environment["REVENUECAT_PUBLIC_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromEnv
        #endif
    }

    private static func isValidRevenueCatPublicKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        if key.contains("REPLACE") { return false }
        if key.hasPrefix("$(") { return false }
        #if !DEBUG
        // TestFlight / App Store builds must use the Apple public SDK key, not the Test Store key.
        if key.hasPrefix("test_") { return false }
        if !key.hasPrefix("appl_") { return false }
        #endif
        return true
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
            lastErrorMessage = error.localizedDescription
        }
    }

    /// - Parameter showLoading: When false, skips toggling `isLoading` (use after purchase/restore to avoid UI flicker).
    func refresh(showLoading: Bool = true) async {
        guard Purchases.isConfigured else {
            if lastErrorMessage == nil {
                lastErrorMessage = "Subscriptions unavailable until RevenueCat is configured."
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
            let customerInfo = try await Purchases.shared.customerInfo()
            let offerings = try await Purchases.shared.offerings()

            hasPro = customerInfo.entitlements[proEntitlementID]?.isActive == true
            currentOffering = offerings.current
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
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
