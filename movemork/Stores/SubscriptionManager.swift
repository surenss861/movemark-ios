//
//  SubscriptionManager.swift
//  movemork
//
//  Single source of truth for Pro / paywalled features. Do not duplicate entitlement logic elsewhere.
//  `hasPro` follows `movemark_pro1`; in Debug only, entitlement `test` is also accepted as a Test Store dashboard bridge.
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

    /// Canonical RevenueCat entitlement (App Store + aligned Test Store).
    private let proEntitlementID = "movemark_pro1"
    /// Some Test Store dashboards grant `test` before products attach to `movemark_pro1`; honored only when Test Store SDK use is allowed.
    private static let testStoreProEntitlementFallbackID = "test"

    private var hasStartedCustomerInfoListener = false
    private var lastKnownAppUserID: String? = nil

    /// Test Store keys (`test_…`) and the `test` entitlement bridge are **Debug-only**. Release / TestFlight / App Store always use `appl_…` and `movemark_pro1` only.
    /// To experiment with Test Store in a custom Release-like configuration, add Swift flag `REVENUECAT_ALLOW_TEST_STORE_KEY` to that configuration only (not shipped App Store archives).
    private static var allowsRevenueCatTestStoreKey: Bool {
        #if DEBUG
        true
        #elseif REVENUECAT_ALLOW_TEST_STORE_KEY
        true
        #else
        false
        #endif
    }

    /// Pre–per-user builds stored the count under this key; migrated once per signed-in user.
    private static let legacyFreeMoveInExportCountKey = "MoveMark.freeMoveInExportCount"

    private static func freeMoveInExportCountKey(userId: UUID) -> String {
        "MoveMark.freeMoveInExportCount.\(userId.uuidString)"
    }

    /// Copies legacy global counter into a per-user key the first time we read for that user.
    private static func migrateLegacyFreeExportCountIfNeeded(userId: UUID) {
        let key = freeMoveInExportCountKey(userId: userId)
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        let legacy = UserDefaults.standard.integer(forKey: legacyFreeMoveInExportCountKey)
        UserDefaults.standard.set(legacy, forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyFreeMoveInExportCountKey)
    }

    func freeMoveInExportCount(forUser userId: UUID?) -> Int {
        guard let userId else { return 0 }
        Self.migrateLegacyFreeExportCountIfNeeded(userId: userId)
        return UserDefaults.standard.integer(forKey: Self.freeMoveInExportCountKey(userId: userId))
    }

    func incrementFreeMoveInExportCount(forUser userId: UUID) {
        Self.migrateLegacyFreeExportCountIfNeeded(userId: userId)
        let key = Self.freeMoveInExportCountKey(userId: userId)
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
    }

    func canExportMoveIn(forUser userId: UUID?) -> Bool {
        if hasPro { return true }
        guard let userId else { return false }
        return freeMoveInExportCount(forUser: userId) < 1
    }

    func remainingFreeMoveInExportsText(forUser userId: UUID?) -> String {
        if hasPro {
            return "Unlimited move-in exports with Pro"
        }

        guard let userId else {
            return "Sign in to use your free move-in export"
        }

        let count = freeMoveInExportCount(forUser: userId)
        let remaining = max(0, 1 - count)
        if remaining == 1 {
            return "1 free move-in export remaining"
        }
        return "Free move-in export used"
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

            if Self.allowsRevenueCatTestStoreKey, apiKey.hasPrefix("appl_") {
                let envT = ProcessInfo.processInfo.environment["REVENUECAT_TEST_STORE_PUBLIC_KEY"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let envUsable = !envT.isEmpty && !envT.hasPrefix("$(")
                let plistT = Self.revenueCatTestStoreAPIKeyFromBundle()
                if !envUsable && plistT.isEmpty {
                    subscriptionLog.notice(
                        "RevenueCat: Test Store allowed but no test key — set user-defined REVENUECAT_TEST_STORE_PUBLIC_KEY on the MoveMark app target for Debug and Release (not only the project), then Clean Build Folder. Using appl_… fallback."
                    )
                }
            }

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
            let keyKind = apiKey.hasPrefix("test_") ? "Test Store" : "App Store"
            subscriptionLog.notice(
                "RevenueCat configured (\(keyKind, privacy: .public) key prefix \(Self.keyDiagnosticPrefix(apiKey), privacy: .public))"
            )
            #endif
        }

        // Never touch Purchases.shared before configure — that crashes at runtime.
        guard Purchases.isConfigured else { return }
        startCustomerInfoListenerIfNeeded()
    }

    /// When Test Store is allowed (Debug or `REVENUECAT_ALLOW_TEST_STORE_KEY`), prefers `REVENUECAT_TEST_STORE_PUBLIC_KEY` / `RevenueCatTestStorePublicAPIKey` so you can keep `appl_…` in `REVENUECAT_APP_STORE_PUBLIC_KEY` for App Store archives.
    private static var resolvedRevenueCatPublicAPIKey: String {
        if allowsRevenueCatTestStoreKey {
            let envTest = ProcessInfo.processInfo.environment["REVENUECAT_TEST_STORE_PUBLIC_KEY"]?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !envTest.isEmpty, !envTest.hasPrefix("$(") { return envTest }

            let plistTest = revenueCatTestStoreAPIKeyFromBundle()
            if !plistTest.isEmpty { return plistTest }
        }

        let fromPlist = revenueCatPublicAPIKeyFromBundle()
        if !fromPlist.isEmpty { return fromPlist }

        let fromEnv = ProcessInfo.processInfo.environment["REVENUECAT_PUBLIC_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fromEnv
    }

    private static func revenueCatTestStoreAPIKeyFromBundle() -> String {
        let key = "RevenueCatTestStorePublicAPIKey"
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, !t.hasPrefix("$(") { return t }
        }
        if let s = Bundle.main.infoDictionary?[key] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, !t.hasPrefix("$(") { return t }
        }
        return ""
    }

    private static func hasActiveProEntitlement(_ customerInfo: CustomerInfo) -> Bool {
        if customerInfo.entitlements["movemark_pro1"]?.isActive == true { return true }
        if allowsRevenueCatTestStoreKey,
           customerInfo.entitlements[testStoreProEntitlementFallbackID]?.isActive == true {
            return true
        }
        return false
    }

    private static func logEntitlementSnapshot(_ customerInfo: CustomerInfo, primaryEntitlementID: String, hasPro: Bool) {
        let activeKeys = customerInfo.entitlements.active.keys.sorted()
        let allKeys = customerInfo.entitlements.all.keys.sorted()
        let matched: String = {
            if customerInfo.entitlements["movemark_pro1"]?.isActive == true { return "movemark_pro1" }
            if allowsRevenueCatTestStoreKey,
               customerInfo.entitlements[testStoreProEntitlementFallbackID]?.isActive == true {
                return "\(testStoreProEntitlementFallbackID) (Test Store fallback)"
            }
            return "—"
        }()
        subscriptionLog.notice(
            "entitlements active=[\(activeKeys.joined(separator: ","), privacy: .public)] all=[\(allKeys.joined(separator: ","), privacy: .public)] primary=\(primaryEntitlementID, privacy: .public) matched=\(matched, privacy: .public) hasPro=\(hasPro, privacy: .public)"
        )
    }

    /// Runtime App Store key: `RevenueCatPublicAPIKey` ← `$(REVENUECAT_APP_STORE_PUBLIC_KEY)`.
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
        if trimmed.hasPrefix("test_") && !allowsRevenueCatTestStoreKey {
            return "Test Store keys only work in Debug or builds with REVENUECAT_ALLOW_TEST_STORE_KEY. Use appl_… for App Store / default Release."
        }
        if trimmed.hasPrefix("test_") && allowsRevenueCatTestStoreKey {
            return "Subscriptions couldn’t start. Check REVENUECAT_TEST_STORE_PUBLIC_KEY or RevenueCat Test Store setup."
        }
        if !trimmed.hasPrefix("appl_") && !(trimmed.hasPrefix("test_") && allowsRevenueCatTestStoreKey) {
            return "Invalid subscription key. Use appl_… or (when allowed) test_… from RevenueCat."
        }
        return "Subscriptions couldn’t start. Check the RevenueCat App Store key in Xcode."
    }

    private static func isValidRevenueCatPublicKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        if key.contains("REPLACE") { return false }
        if key.hasPrefix("$(") { return false }
        if key.hasPrefix("test_") { return allowsRevenueCatTestStoreKey }
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

    /// Debug-only plist override for a specific offering id. Ignored in Release so TestFlight/App Store always use `offerings.current` from the dashboard.
    private static func revenueCatOfferingIdentifierOverride() -> String? {
        #if DEBUG
        for key in ["RevenueCatOfferingOverride", "MoveMarkRevenueCatOfferingOverride"] {
            guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { continue }
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.hasPrefix("$(") { continue }
            return t
        }
        return nil
        #else
        return nil
        #endif
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
                hasPro = Self.hasActiveProEntitlement(customerInfo)
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
                hasPro = Self.hasActiveProEntitlement(result.customerInfo)
                lastKnownAppUserID = normalizedID
            } else if lastKnownAppUserID != nil {
                let customerInfo = try await Purchases.shared.logOut()
                hasPro = Self.hasActiveProEntitlement(customerInfo)
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
                "refresh start isConfigured=true entitlementID=\(self.proEntitlementID, privacy: .public) keyPrefix=\(Self.keyDiagnosticPrefix(Self.resolvedRevenueCatPublicAPIKey), privacy: .public)"
            )

            let customerInfo = try await Purchases.shared.customerInfo()
            let proActive = Self.hasActiveProEntitlement(customerInfo)
            subscriptionLog.notice("refresh customerInfo OK hasPro=\(proActive, privacy: .public)")
            #if DEBUG
            Self.logEntitlementSnapshot(customerInfo, primaryEntitlementID: proEntitlementID, hasPro: proActive)
            #endif

            let offerings = try await Purchases.shared.offerings()

            hasPro = proActive

            #if DEBUG
            let catalogIds = offerings.all.keys.sorted()
            subscriptionLog.notice("offerings catalog ids=\(String(describing: catalogIds), privacy: .public) sdkCurrent=\(offerings.current?.identifier ?? "nil", privacy: .public)")

            for oid in catalogIds {
                guard let off = offerings.all[oid] else { continue }
                let pids = off.availablePackages.map(\.storeProduct.productIdentifier)
                let rcIds = off.availablePackages.map(\.identifier)
                subscriptionLog.notice(
                    "offering id=\(oid, privacy: .public) packageCount=\(off.availablePackages.count, privacy: .public) storeProductIDs=\(String(describing: pids), privacy: .public) rcPackageIDs=\(String(describing: rcIds), privacy: .public)"
                )
            }
            #endif

            let resolvedOffering: Offering? = {
                if let oid = Self.revenueCatOfferingIdentifierOverride() {
                    if let off = offerings.all[oid] {
                        subscriptionLog.notice(
                            "RevenueCatOfferingOverride using id=\(oid, privacy: .public) (sdk current=\(offerings.current?.identifier ?? "nil", privacy: .public))"
                        )
                        return off
                    }
                    subscriptionLog.error(
                        "RevenueCatOfferingOverride id=\(oid, privacy: .public) missing from catalog keys=\(String(describing: offerings.all.keys.sorted()), privacy: .public)"
                    )
                }
                return offerings.current
            }()

            currentOffering = resolvedOffering

            if let current = resolvedOffering {
                let count = current.availablePackages.count
                #if DEBUG
                let packageIDs = current.availablePackages.map(\.storeProduct.productIdentifier)
                let rcPackageIDs = current.availablePackages.map(\.identifier)
                subscriptionLog.notice(
                    "refresh resolved offering=\(current.identifier, privacy: .public) packageCount=\(count, privacy: .public) storeProductIDs=\(String(describing: packageIDs), privacy: .public) rcPackageIDs=\(String(describing: rcPackageIDs), privacy: .public)"
                )
                #else
                subscriptionLog.notice(
                    "refresh resolved offering=\(current.identifier, privacy: .public) packageCount=\(count, privacy: .public)"
                )
                #endif

                if current.availablePackages.isEmpty {
                    subscriptionLog.notice("refresh resolved offering has zero packages (check RevenueCat packages / StoreKit config on simulator)")
                    lastErrorMessage = "Plans aren’t available yet. Check your default offering and packages in RevenueCat."
                } else {
                    lastErrorMessage = nil
                }
            } else {
                subscriptionLog.notice("refresh resolved offering=nil (no current offering in RevenueCat)")
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
        hasPro = Self.hasActiveProEntitlement(result.customerInfo)
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
        hasPro = Self.hasActiveProEntitlement(customerInfo)
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
