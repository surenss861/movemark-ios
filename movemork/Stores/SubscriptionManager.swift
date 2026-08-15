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

/// Holds the RevenueCat `customerInfoStream` task so `SubscriptionManager.deinit` can cancel without actor violations.
private final class SubscriptionCustomerInfoListenerBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var task: Task<Void, Never>?

    nonisolated init() {}

    nonisolated func store(_ newTask: Task<Void, Never>?) {
        lock.lock()
        let previous = task
        task = newTask
        lock.unlock()
        previous?.cancel()
    }

    nonisolated func cancel() {
        lock.lock()
        let current = task
        task = nil
        lock.unlock()
        current?.cancel()
    }
}

@MainActor
@Observable
final class SubscriptionManager {
    deinit {
        customerInfoListenerBox.cancel()
    }

    var hasPro: Bool = false
    /// True while refetching offerings from RevenueCat (initial load, pull-to-refresh style paths).
    var isRefreshingOfferings: Bool = false
    /// True during an in-flight purchase or restore (StoreKit / RevenueCat transaction).
    var isStoreKitBusy: Bool = false
    /// Paywall-only: offerings/catalog fetch failed or returned no packages.
    var offeringsLoadErrorMessage: String? = nil
    /// Last purchase attempt error (paywall), cleared on the next purchase.
    var lastPurchaseErrorMessage: String? = nil
    /// Last restore attempt error (paywall / account), cleared on the next restore.
    var lastRestoreErrorMessage: String? = nil
    /// Startup/configure failure (invalid API key, etc.).
    var configurationErrorMessage: String? = nil
    var currentOffering: Offering? = nil

    /// Whether the paywall can show purchasable packages (after at least one refresh attempt).
    var hasPaywallPackages: Bool {
        guard let packages = currentOffering?.availablePackages else { return false }
        return !packages.isEmpty
    }

    /// Aggregate for screens that only need a single “busy” flag (e.g. Account restore while offerings also refresh).
    var isLoading: Bool { isRefreshingOfferings || isStoreKitBusy }

    /// Canonical RevenueCat entitlements (dashboard may use either identifier).
    private static let proEntitlementIDs = ["movemark_pro", "movemark_pro1"]
    private let proEntitlementID = "movemark_pro1"
    /// Some Test Store dashboards grant `test` before products attach to `movemark_pro1`; honored only when Test Store SDK use is allowed.
    private static let testStoreProEntitlementFallbackID = "test"

    /// False while no listener is running, or after the stream task exits (including cancellation).
    private var isCustomerInfoListenerActive = false
    private let customerInfoListenerBox = SubscriptionCustomerInfoListenerBox()
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

    /// One-time Report Pack product IDs — must match App Store / RevenueCat.
    private static let reportPackProductIDs: Set<String> = [
        "report_pack",
        "movemark_report_pack",
        "test_report_pack",
    ]

    /// One-time Report Pack credits purchased (each credit unlocks one additional move-in export).
    private static func reportPackCreditKey(userId: UUID) -> String {
        "MoveMark.reportPackCredits.\(userId.uuidString)"
    }

    func reportPackCredits(forUser userId: UUID?) -> Int {
        guard let userId else { return 0 }
        return max(0, UserDefaults.standard.integer(forKey: Self.reportPackCreditKey(userId: userId)))
    }

    func addReportPackCredit(forUser userId: UUID, amount: Int = 1) {
        let key = Self.reportPackCreditKey(userId: userId)
        let next = reportPackCredits(forUser: userId) + max(1, amount)
        UserDefaults.standard.set(next, forKey: key)
    }

    /// Rehydrates local Report Pack credits from RevenueCat non-subscription purchases (restore / reinstall).
    @discardableResult
    func syncReportPackCredits(from customerInfo: CustomerInfo, userId: UUID?) -> Int {
        guard let userId else { return 0 }
        let remote = Self.reportPackPurchaseCount(in: customerInfo)
        let local = reportPackCredits(forUser: userId)
        let merged = max(local, remote)
        UserDefaults.standard.set(merged, forKey: Self.reportPackCreditKey(userId: userId))
        return merged
    }

    private static func reportPackPurchaseCount(in customerInfo: CustomerInfo) -> Int {
        customerInfo.nonSubscriptions.filter { transaction in
            reportPackProductIDs.contains(transaction.productIdentifier)
                || transaction.productIdentifier.localizedCaseInsensitiveContains("report_pack")
        }.count
    }

    /// Total move-in exports allowed on free tier (1 included) plus any Report Pack credits.
    func moveInExportAllowance(forUser userId: UUID?) -> Int {
        if hasPro { return .max }
        guard let userId else { return 0 }
        return 1 + reportPackCredits(forUser: userId)
    }

    func canExportMoveIn(forUser userId: UUID?) -> Bool {
        if hasPro { return true }
        guard let userId else { return false }
        return freeMoveInExportCount(forUser: userId) < moveInExportAllowance(forUser: userId)
    }

    func remainingFreeMoveInExportsText(forUser userId: UUID?) -> String {
        if hasPro {
            return "Unlimited move-in reports with Pro"
        }

        guard let userId else {
            return "Sign in to use your free move-in report"
        }

        let used = freeMoveInExportCount(forUser: userId)
        let allowance = moveInExportAllowance(forUser: userId)
        let remaining = max(0, allowance - used)
        if remaining == 1 {
            return "1 move-in report left"
        }
        if remaining > 1 {
            return "\(remaining) move-in reports left"
        }
        return "Move-in report used — buy a Report Pack or start Pro"
    }

    /// Short copy for Paywall only — Account stays on Free/Pro summary when plans fail to load.
    var userFacingPlansErrorMessage: String? {
        guard let offeringsLoadErrorMessage else { return nil }
        let trimmed = offeringsLoadErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Self.sanitizedPlansErrorMessage(trimmed)
    }

    /// Free-tier plan line for Account (never blocked by offerings fetch).
    var accountPlanSummaryLine: String {
        if hasPro {
            return "Unlimited vaults, reports, move-out proof, and dispute tools."
        }
        return "1 property · 1 move-in report"
    }

    nonisolated static func sanitizedPlansErrorMessage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("revenuecat")
            || lower.contains("offering")
            || lower.contains("app store connect")
            || lower.contains("appl_")
            || lower.contains("test_")
            || lower.contains("entitlement")
            || lower.contains("package")
            || lower.contains("metadata")
            || lower.contains("credential") {
            return "Plans didn't load. Try again."
        }
        if raw.count > 120 {
            return "Plans didn't load. Try again."
        }
        return raw
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
            Self.logRevenueCatKeyResolution(apiKey: apiKey)

            if Self.allowsRevenueCatTestStoreKey, apiKey.hasPrefix("appl_") {
                let envT = ProcessInfo.processInfo.environment["REVENUECAT_TEST_STORE_PUBLIC_KEY"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let envUsable = !envT.isEmpty && !envT.hasPrefix("$(")
                let plistT = Self.revenueCatTestStoreAPIKeyFromBundle()
                if !envUsable && plistT.isEmpty {
                    subscriptionLog.notice(
                        "RevenueCat: Debug allows Test Store but no test key found — set REVENUECAT_TEST_STORE_PUBLIC_KEY in a local ignored xcconfig or scheme env, or the app uses appl_… only."
                    )
                }
            }

            #if DEBUG
            if !Self.allowsRevenueCatTestStoreKey, Self.isRevenueCatTestStoreSDKKey(apiKey) {
                assertionFailure("Shipping build must not resolve RevenueCat Test Store (test_…) key. Use Release + appl_… for Archive/TestFlight.")
            }
            #endif

            if !Self.allowsRevenueCatTestStoreKey, Self.isRevenueCatTestStoreSDKKey(apiKey) {
                subscriptionLog.error(
                    "RevenueCat configure blocked: test_… key in a build that only allows appl_… (Archive/TestFlight/App Store). Remove Test Store overrides from Release."
                )
            }

            guard Self.isValidRevenueCatPublicKey(apiKey) else {
                configurationErrorMessage = Self.userFacingRevenueCatKeyError(resolvedKey: apiKey)
                offeringsLoadErrorMessage = "Plans didn't load. Try again."
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

    /// When Test Store is allowed (Debug or `REVENUECAT_ALLOW_TEST_STORE_KEY`), prefers `REVENUECAT_TEST_STORE_PUBLIC_KEY` / `RevenueCatTestStorePublicAPIKey` so you can keep `appl_…` in `REVENUECAT_APP_STORE_PUBLIC_KEY` for App Store archives.
    /// Release/TestFlight (default) never reads Test Store plist/env paths — only `appl_…` via `RevenueCatPublicAPIKey` / `REVENUECAT_PUBLIC_API_KEY` fallback.
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

    private static func isRevenueCatTestStoreSDKKey(_ key: String) -> Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("test_")
    }

    /// One-line diagnostics for Console: build channel, resolved key shape, masked prefix. Call before `Purchases.configure`.
    private static func logRevenueCatKeyResolution(apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyKind: String
        if trimmed.isEmpty {
            keyKind = "missing"
        } else if isRevenueCatTestStoreSDKKey(trimmed) {
            keyKind = "test_store"
        } else if trimmed.hasPrefix("appl_") {
            keyKind = "app_store"
        } else {
            keyKind = "other"
        }

        let buildChannel: String
        #if DEBUG
        buildChannel = "DEBUG"
        #elseif REVENUECAT_ALLOW_TEST_STORE_KEY
        buildChannel = "RELEASE_allow_test_store"
        #else
        buildChannel = "RELEASE"
        #endif

        subscriptionLog.notice(
            "RevenueCat startup build=\(buildChannel, privacy: .public) keyKind=\(keyKind, privacy: .public) prefix=\(keyDiagnosticPrefix(apiKey), privacy: .public) testStorePathAllowed=\(allowsRevenueCatTestStoreKey, privacy: .public)"
        )
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
        for id in proEntitlementIDs where customerInfo.entitlements[id]?.isActive == true {
            return true
        }
        if allowsRevenueCatTestStoreKey,
           customerInfo.entitlements[testStoreProEntitlementFallbackID]?.isActive == true {
            return true
        }
        return false
    }

    private static func matchedProEntitlementID(_ customerInfo: CustomerInfo) -> String {
        for id in proEntitlementIDs where customerInfo.entitlements[id]?.isActive == true {
            return id
        }
        if allowsRevenueCatTestStoreKey,
           customerInfo.entitlements[testStoreProEntitlementFallbackID]?.isActive == true {
            return "\(testStoreProEntitlementFallbackID) (Test Store fallback)"
        }
        return "—"
    }

    private static func logEntitlementSnapshot(_ customerInfo: CustomerInfo, primaryEntitlementID: String, hasPro: Bool) {
        let activeKeys = customerInfo.entitlements.active.keys.sorted()
        let allKeys = customerInfo.entitlements.all.keys.sorted()
        let matched = matchedProEntitlementID(customerInfo)
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
        "Plans didn't load. Try again."
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
        guard !isCustomerInfoListenerActive else { return }
        isCustomerInfoListenerActive = true

        customerInfoListenerBox.store(Task { @MainActor [weak self] in
            defer { self?.markCustomerInfoListenerFinished() }
            guard let self else { return }
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self.hasPro = Self.hasActiveProEntitlement(customerInfo)
            }
        })
    }

    private func markCustomerInfoListenerFinished() {
        isCustomerInfoListenerActive = false
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
            offeringsLoadErrorMessage = Self.userFacingRevenueCatOperationError(error)
        }
    }

    /// - Parameter showLoading: When false, skips toggling `isRefreshingOfferings` (use after purchase/restore to avoid UI flicker).
    func refresh(showLoading: Bool = true) async {
        guard Purchases.isConfigured else {
            if offeringsLoadErrorMessage == nil {
                offeringsLoadErrorMessage = configurationErrorMessage
                    ?? "Subscription options aren’t available until the app finishes setup."
            }
            return
        }

        if showLoading {
            isRefreshingOfferings = true
        }
        defer {
            if showLoading {
                isRefreshingOfferings = false
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
            #else
            subscriptionLog.notice(
                "offerings fetched catalogOfferingCount=\(offerings.all.count, privacy: .public) sdkCurrent=\(offerings.current?.identifier ?? "nil", privacy: .public)"
            )
            #endif

            let resolvedOffering = Self.resolveOffering(from: offerings)

            currentOffering = resolvedOffering

            if let current = resolvedOffering {
                let count = current.availablePackages.count
                let packageIDs = current.availablePackages.map(\.storeProduct.productIdentifier)
                let rcPackageIDs = current.availablePackages.map(\.identifier)
                subscriptionLog.notice(
                    "refresh resolved offering=\(current.identifier, privacy: .public) packageCount=\(count, privacy: .public) storeProductIDs=\(String(describing: packageIDs), privacy: .public) rcPackageIDs=\(String(describing: rcPackageIDs), privacy: .public) proEntitlement=\(self.proEntitlementID, privacy: .public)"
                )

                if current.availablePackages.isEmpty {
                    subscriptionLog.notice("refresh resolved offering has zero packages (check RevenueCat packages / App Store Connect / Paid Apps Agreement)")
                    offeringsLoadErrorMessage = "Plans didn't load. Try again."
                } else {
                    offeringsLoadErrorMessage = nil
                }
            } else {
                subscriptionLog.notice("refresh resolved offering=nil (no offering with packages in RevenueCat)")
                offeringsLoadErrorMessage = "Plans didn't load. Try again."
            }
        } catch {
            offeringsLoadErrorMessage = Self.userFacingRevenueCatOperationError(error)
            let ns = error as NSError
            subscriptionLog.error(
                "RevenueCat offerings fetch failed proEntitlement=\(self.proEntitlementID, privacy: .public) domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public) description=\(ns.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Completes purchase, updates `hasPro`, and refreshes offerings in the background.
    /// Returns whether the StoreKit purchase finished successfully (not cancelled).
    /// Callers that need Pro specifically should also check `hasPro`.
    @discardableResult
    func purchase(package: Package) async -> Bool {
        lastPurchaseErrorMessage = nil

        guard Purchases.isConfigured else {
            lastPurchaseErrorMessage = "Subscriptions aren’t available in this build yet."
            return false
        }

        isStoreKitBusy = true
        defer { isStoreKitBusy = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                return false
            }
            hasPro = Self.hasActiveProEntitlement(result.customerInfo)
            Task { @MainActor in
                await self.refresh(showLoading: false)
            }
            return true
        } catch {
            if !Self.isPurchaseCancelled(error) {
                lastPurchaseErrorMessage = Self.userFacingPurchaseError(error)
            }
            return false
        }
    }

    /// Restores purchases, updates `hasPro`, rehydrates Report Pack credits, and refreshes offerings.
    /// Returns true when Pro is active or at least one Report Pack credit is available after restore.
    @discardableResult
    func restorePurchases(forUser userId: UUID? = nil) async -> Bool {
        lastRestoreErrorMessage = nil

        guard Purchases.isConfigured else {
            lastRestoreErrorMessage = configurationErrorMessage
                ?? "Subscriptions aren’t available in this build yet."
            return false
        }

        isStoreKitBusy = true
        defer { isStoreKitBusy = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            hasPro = Self.hasActiveProEntitlement(customerInfo)
            let packCredits = syncReportPackCredits(from: customerInfo, userId: userId)
            offeringsLoadErrorMessage = nil
            Task { @MainActor in
                await self.refresh(showLoading: false)
            }
            return hasPro || packCredits > 0
        } catch {
            lastRestoreErrorMessage = Self.userFacingRestoreError(error)
            return false
        }
    }

    private static func userFacingRestoreError(_ error: Error) -> String {
        if isPurchaseCancelled(error) {
            return "Restore cancelled."
        }
        let lower = error.localizedDescription.lowercased()
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return "Couldn’t restore purchases. Try again in a moment."
    }

    private static func isPurchaseCancelled(_ error: Error) -> Bool {
        if let code = error as? ErrorCode {
            return code == .purchaseCancelledError
        }
        let ns = error as NSError
        if ns.domain == ErrorCode.errorDomain,
           let code = ErrorCode(rawValue: ns.code),
           code == .purchaseCancelledError {
            return true
        }
        return error.localizedDescription.lowercased().contains("cancel")
    }

    private static func userFacingPurchaseError(_ error: Error) -> String {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return "Purchase didn’t go through. Try again."
    }

    /// Picks the best offering when `offerings.current` is unset or empty.
    private static func resolveOffering(from offerings: Offerings) -> Offering? {
        if let oid = revenueCatOfferingIdentifierOverride(),
           let off = offerings.all[oid],
           !off.availablePackages.isEmpty {
            return off
        }

        if let current = offerings.current, !current.availablePackages.isEmpty {
            return current
        }

        for preferredID in ["default", "current", "pro", "standard"] {
            if let off = offerings.all[preferredID], !off.availablePackages.isEmpty {
                return off
            }
        }

        return offerings.all.values.first { !$0.availablePackages.isEmpty }
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
