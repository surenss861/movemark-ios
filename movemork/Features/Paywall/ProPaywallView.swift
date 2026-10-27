//
//  ProPaywallView.swift
//  movemork
//
//  MoveMark — RevenueCat-backed Pro paywall: a dark, full-bleed conversion screen — the outcome, the rental
//  timeline with only the genuinely-Pro parts marked (SubscriptionManager: canExportMoveOut, canUseCaseBuilder,
//  unlimited reports, more rentals), App Store prices, one lime purchase action, restore / not now and legal.
//  StoreKit's own purchase sheet stays native.
//

import SwiftUI
import RevenueCat

struct ProPaywallView: View {
    let reason: PaywallReason
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var localErrorMessage: String? = nil
    @State private var selectedPackageID: String? = nil
    @State private var restoreOutcomeMessage: String? = nil
    /// False until the first `refresh()` tied to this paywall presentation finishes (avoids a one-frame “fake” plan placeholder).
    @State private var initialOfferingsFetchCompleted = false
    private let startsWithFetchedOfferings: Bool
    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var showPurchaseSuccess = false
    @State private var purchaseSuccessWasReportPack = false

    /// Store product IDs — must match RevenueCat package products (App Store: monthly/yearly_subscription; Test Store mirror: testmonthly/testyearly).
    private static let monthlyProductIDs = ["monthly_subscription", "testmonthly"]
    private static let yearlyProductIDs = ["yearly_subscription", "testyearly"]
    private static let reportPackProductIDs = ["report_pack", "movemark_report_pack", "test_report_pack"]

    @Environment(SessionManager.self) private var sessionManager

    init(
        reason: PaywallReason,
        onClose: @escaping () -> Void,
        initialOfferingsFetchCompleted: Bool = false,
        showPurchaseSuccess: Bool = false,
        purchaseSuccessWasReportPack: Bool = false,
        restoreOutcomeMessage: String? = nil,
        localErrorMessage: String? = nil,
        toast: MMProofToastMessage? = nil
    ) {
        self.reason = reason
        self.onClose = onClose
        _initialOfferingsFetchCompleted = State(initialValue: initialOfferingsFetchCompleted)
        // Only snapshot seams start with a finished fetch; the app always presents with the default (false).
        self.startsWithFetchedOfferings = initialOfferingsFetchCompleted
        _showPurchaseSuccess = State(initialValue: showPurchaseSuccess)
        _purchaseSuccessWasReportPack = State(initialValue: purchaseSuccessWasReportPack)
        _restoreOutcomeMessage = State(initialValue: restoreOutcomeMessage)
        _localErrorMessage = State(initialValue: localErrorMessage)
        _proofToast = State(initialValue: toast)
        _proofToastVisible = State(initialValue: toast != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    // Came for one report: the Report Pack is the first answer, before the Pro story.
                    if reason == .reportPack {
                        reportPackSection
                            .padding(.top, 26)
                    }

                    timeline
                        .padding(.top, 30)

                    truthLines
                        .padding(.top, 4)

                    if reason.prefersReportPackFirst, reason != .reportPack {
                        reportPackSection
                            .padding(.top, 30)
                    }

                    plansLoadSection
                        .padding(.top, 30)

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 0) { quietActions }
                            .padding(.top, 22)
                    }

                    legalSection
                        .padding(.top, 26)
                }
                .padding(.horizontal, MMMetrics.inset)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchaseFooter
            }
            .background(Self.surface.ignoresSafeArea())
            .allowsHitTesting(!showPurchaseSuccess)
            .overlay {
                if showPurchaseSuccess {
                    purchaseSuccessOverlay
                }
            }
            .task {
                MoveMarkAnalytics.track(
                    .paywallViewed,
                    properties: ["reason": String(describing: reason)]
                )
                // A seeded state (snapshot goldens) keeps its offering: no store round trip piling up across tests.
                guard !startsWithFetchedOfferings else { return }
                initialOfferingsFetchCompleted = false
                await subscriptionManager.refresh()
                initialOfferingsFetchCompleted = true
            }
            .overlay(alignment: .top) {
                // The proof toast as a calm, opaque notice on the dark surface (same message and presenter).
                if proofToastVisible, let proofToast {
                    MMEvidenceNotice(message: [proofToast.title, proofToast.message].compactMap { $0 }.joined(separator: ". "),
                                     tone: proofToast.kind.lightTone)
                        .background(Self.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                        .padding(.horizontal, MMMetrics.inset)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: paywallPlansUnavailable) { wasUnavailable, isUnavailable in
                guard isUnavailable, !wasUnavailable else { return }
                MMProofToastPresenter.show(
                    .plansDidNotLoad(),
                    message: $proofToast,
                    isVisible: $proofToastVisible
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close")
                    .disabled(subscriptionManager.isStoreKitBusy)
                }
            }
            .toolbarBackground(Self.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
            .interactiveDismissDisabled(subscriptionManager.isStoreKitBusy || showPurchaseSuccess)
        }
    }

    /// The paywall is a dark, full-bleed screen on the archival header colour.
    private static let surface = MMInk.hero

    // MARK: - Outcome

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMDarkEyebrow(text: "MoveMark Pro")

            Text("Protect the full rental timeline.")
                .mmFont(30, .semibold)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 10)

            Text("Keep the record from move-in through move-out, and turn your evidence into reports when you need it.")
                .mmFont(16)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            if let contextLine {
                Text(contextLine)
                    .mmFont(14)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }

    /// Why this paywall opened, stated as a fact (SubscriptionManager is the source of truth for each line).
    private var contextLine: String? {
        switch reason {
        case .extraProperty: "Free includes one rental. Pro adds more."
        case .unlimitedExports: "You’ve used your free move-in report."
        case .disputePacket: "The evidence packet is part of Pro."
        case .moveOutExport: "The move-out report is part of Pro."
        case .reportPack: nil   // the Report Pack row right below says it
        }
    }

    /// The rental timeline. Free keeps every step's record; only the move-out report and the evidence packet
    /// are Pro (`canExportMoveOut`, `canUseCaseBuilder`).
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMDarkTimelineStep(phase: "Move-in", title: "Recorded", isRecorded: true)
            MMDarkTimelineStep(phase: "During rental", title: "Maintenance cases")
            MMDarkTimelineStep(phase: "Move-out", title: "Compare before and after", proPart: "Move-out report")
            MMDarkTimelineStep(phase: "If questioned", title: "Build the evidence packet", proPart: "Evidence packet", isLast: true)
        }
    }

    private var truthLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Free keeps the record. Pro turns it into the reports and evidence packet you’d use.")
                .mmFont(15, .medium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Pro also includes unlimited reports and more than one rental.")
                .mmFont(13.5)
                .foregroundStyle(MMInk.heroSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
        .overlay(alignment: .top) { Rectangle().fill(MMInk.evidenceStroke).frame(height: 0.5) }
    }

    // MARK: - Success

    private var purchaseSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MMInk.onLime)
                    .frame(width: 44, height: 44)
                    .background(MMInk.limeMark, in: Circle())

                Text(purchaseSuccessWasReportPack ? "Report Pack unlocked" : "Pro unlocked")
                    .mmFont(19, .semibold)
                    .foregroundStyle(.white)

                Text(purchaseSuccessWasReportPack
                     ? "One more move-in report is ready to make."
                     : "Your move-out report and evidence packet are ready when you need them.")
                    .mmFont(14)
                    .foregroundStyle(MMInk.heroSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: 320)
            .background(Self.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75))
            .padding(.horizontal, MMMetrics.inset)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(purchaseSuccessWasReportPack ? "Report Pack unlocked" : "Pro unlocked")
    }

    // MARK: - Purchase

    private var planGroupTitle: String {
        reason == .reportPack ? "Or choose Pro" : "Choose your plan"
    }

    /// One lime action, the Apple line, then the quiet ways out. Pinned so the purchase is always in reach.
    private var purchaseFooter: some View {
        VStack(spacing: 10) {
            if let local = localErrorMessage, !displayPackages.isEmpty {
                MMEvidenceNotice(message: paywallBannerMessage(local))
            }
            if let restoreOutcomeMessage {
                MMEvidenceNotice(message: restoreOutcomeMessage, tone: .info)
            }

            if paywallPlansUnavailable {
                // What failed sits right above its recovery, not below the fold.
                plansUnavailableNotice
                MMPrimaryButton(
                    title: subscriptionManager.isRefreshingOfferings
                        ? "Trying…"
                        : MMNextBestActionMapper.paywallPlansUnavailable().title,
                    isLoading: subscriptionManager.isRefreshingOfferings,
                    isDisabled: subscriptionManager.isRefreshingOfferings || subscriptionManager.isStoreKitBusy,
                    action: {
                        localErrorMessage = nil
                        restoreOutcomeMessage = nil
                        Task { @MainActor in
                            await subscriptionManager.refresh()
                        }
                    }
                )
            } else {
                MMPrimaryButton(
                    title: selectedPackage.map { primaryPurchaseButtonTitle(for: $0) } ?? "Continue with Pro",
                    isLoading: subscriptionManager.isStoreKitBusy && !showPurchaseSuccess,
                    isDisabled: selectedPackage == nil
                        || subscriptionManager.isStoreKitBusy
                        || subscriptionManager.isRefreshingOfferings
                        || showPurchaseSuccess,
                    action: { if let selectedPackage { startPurchase(selectedPackage) } }
                )

                // The chosen plan's App Store price stays beside the action even when the plan rows are below.
                Text([selectedPackage.map { priceCaption(for: $0, product: $0.storeProduct) },
                      "Cancel anytime · Managed by Apple"].compactMap { $0 }.joined(separator: " · "))
                    .mmFont(12.5)
                    .monospacedDigit()
                    .foregroundStyle(MMInk.heroSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // At accessibility sizes the quiet actions move to the end of the page so the pinned bar stays small.
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 0) { quietActions }
            }
        }
        .padding(.horizontal, MMMetrics.inset)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Self.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(MMInk.evidenceStroke).frame(height: 0.5) }
    }

    @ViewBuilder
    private var quietActions: some View {
        MMSecondaryButton(
            title: subscriptionManager.isStoreKitBusy ? "Restoring purchases…" : "Restore purchases",
            tint: .white,
            isDisabled: subscriptionManager.isStoreKitBusy,
            action: { restorePurchases() }
        )
        MMSecondaryButton(
            title: paywallPlansUnavailable ? "Continue on Free" : "Not now",
            tint: MMInk.heroSecondary,
            isDisabled: subscriptionManager.isStoreKitBusy,
            action: { onClose() }
        )
    }

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("MoveMark Pro is an auto-renewing subscription. Prices come from the App Store; Apple handles payment and renewal. Manage or cancel in Settings › Apple ID › Subscriptions.")
                .mmFont(12.5)
                .foregroundStyle(MMInk.heroSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            paywallLegalLinks
        }
    }

    /// Empty catalog after at least one paywall fetch finished — never show silent placeholders.
    private var paywallPlansUnavailable: Bool {
        displayPackages.isEmpty
            && !subscriptionManager.isRefreshingOfferings
            && initialOfferingsFetchCompleted
    }

    private var plansUnavailableTechnicalDetail: String {
        if let local = localErrorMessage, !local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return paywallBannerMessage(local)
        }
        let server = subscriptionManager.offeringsLoadErrorMessage ?? ""
        if !server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return paywallBannerMessage(server)
        }
        return "If this persists, confirm the Paid Apps Agreement is active in App Store Connect and that subscription products are attached to your RevenueCat offering."
    }

    private var privacyPolicyURL: URL? { legalURL(forInfoKey: "LegalPrivacyPolicyURL") }

    private var termsOfUseURL: URL? { legalURL(forInfoKey: "LegalTermsURL") }

    private func legalURL(forInfoKey key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), let url = URL(string: trimmed) else { return nil }
        return url
    }

    @ViewBuilder
    private var paywallLegalLinks: some View {
        if termsOfUseURL != nil || privacyPolicyURL != nil {
            HStack(spacing: 18) {
                if let u = termsOfUseURL {
                    Button {
                        openURL(u)
                    } label: {
                        Text("Terms of Use").mmFont(13, .medium).foregroundStyle(.white).underline()
                    }
                    .buttonStyle(.plain)
                }
                if let p = privacyPolicyURL {
                    Button {
                        openURL(p)
                    } label: {
                        Text("Privacy Policy").mmFont(13, .medium).foregroundStyle(.white).underline()
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Legal")
        }
    }

    private var plansUnavailableNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(MMEvidenceNotice.warningOnDark)
            VStack(alignment: .leading, spacing: 4) {
                Text("Plans didn’t load")
                    .mmFont(16, .semibold)
                    .foregroundStyle(.white)
                Text("Try again in a minute. You can keep using Free for now.")
                    .mmFont(14)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
        .accessibilityElement(children: .combine)
    }

    private var plansLoadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !paywallPlansUnavailable {
                MMEvidenceSectionLabel(title: planGroupTitle)
                if !displayPackages.isEmpty {
                    ForEach(displayPackages, id: \.identifier) { package in
                        pricingOption(package)
                    }
                } else {
                    // Loading keeps the plan layout; prices only ever come from the App Store.
                    VStack(spacing: 10) {
                        MMDarkPlanRow(title: "Yearly", price: "$00.00 / year", detail: "Billed yearly")
                        MMDarkPlanRow(title: "Monthly", price: "$0.00 / month", detail: "Billed monthly")
                    }
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(MMInk.heroSecondary)
                        Text("Getting prices from the App Store…").mmFont(13).foregroundStyle(MMInk.heroSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                #if DEBUG
                // Diagnostics for builders only; the renter sees the notice above the recovery action.
                Text(plansUnavailableTechnicalDetail)
                    .mmFont(12)
                    .foregroundStyle(MMInk.heroSecondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
        }
    }

    private func paywallBannerMessage(_ raw: String) -> String {
        SubscriptionManager.sanitizedPlansErrorMessage(raw)
    }

    private func primaryPurchaseButtonTitle(for package: Package) -> String {
        if showPurchaseSuccess {
            return purchaseSuccessWasReportPack ? "Report Pack unlocked" : "Pro unlocked"
        }
        if subscriptionManager.isStoreKitBusy { return "Starting…" }
        // The plan is chosen above (and named in its row); the action itself is always the same.
        return "Continue with Pro"
    }

    private enum PlanKind {
        case monthly, yearly, other
    }

    private func planKind(for package: Package) -> PlanKind {
        let pid = package.storeProduct.productIdentifier
        if Self.yearlyProductIDs.contains(pid) || Self.infersAnnualBilling(package) { return .yearly }
        if Self.monthlyProductIDs.contains(pid) || Self.infersMonthlyBilling(package) { return .monthly }
        return .other
    }

    private func planDisplayTitle(for package: Package) -> String {
        switch planKind(for: package) {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .other:
            let t = package.storeProduct.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Pro" : t
        }
    }

    private var displayPackages: [Package] {
        let raw = subscriptionManager.currentOffering?.availablePackages ?? []
        let proOnly = raw.filter { !Self.isReportPackProduct($0.storeProduct.productIdentifier) }
        return Self.sortedPackagesForDisplay(proOnly)
    }

    private var reportPackPackages: [Package] {
        let raw = subscriptionManager.currentOffering?.availablePackages ?? []
        return raw.filter { Self.isReportPackProduct($0.storeProduct.productIdentifier) }
    }

    private static func isReportPackProduct(_ productID: String) -> Bool {
        reportPackProductIDs.contains(productID)
            || productID.localizedCaseInsensitiveContains("report_pack")
    }

    /// One report, no subscription — offered first when the renter only needs a single move-in report.
    private var reportPackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMEvidenceSectionLabel(title: "One report only")
            if let pack = reportPackPackages.first {
                Button {
                    startPurchase(pack, isReportPack: true)
                } label: {
                    let price = Text(pack.storeProduct.localizedPriceString)
                        .mmFont(16, .semibold)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    let copy = VStack(alignment: .leading, spacing: 2) {
                        Text("Report Pack").mmFont(16, .semibold).foregroundStyle(.white)
                        Text("One move-in report · no subscription")
                            .mmFont(13)
                            .foregroundStyle(MMInk.heroSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) { copy; price }
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                    .frame(width: 24)
                                copy
                                Spacer(minLength: 8)
                                price.layoutPriority(1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .disabled(subscriptionManager.isStoreKitBusy || showPurchaseSuccess)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Buy Report Pack, one move-in report, no subscription, \(pack.storeProduct.localizedPriceString)")
                .accessibilityAddTraits(.isButton)

                Text("The move-out report and evidence packet stay on Pro.")
                    .mmFont(12.5)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                #if DEBUG
                MMEvidenceNotice(
                    message: "Report Pack unavailable. Add product IDs report_pack / movemark_report_pack in RevenueCat to enable one-time purchase here. Pro still unlocks unlimited reports.",
                    tone: .info
                )
                #else
                MMEvidenceNotice(message: "Report Pack isn’t available right now. Pro still unlocks unlimited reports.", tone: .info)
                #endif
            }
        }
    }

    private static func sortedPackagesForDisplay(_ packages: [Package]) -> [Package] {
        packages.sorted { lhs, rhs in
            func rank(_ p: Package) -> Int {
                let pid = p.storeProduct.productIdentifier
                if yearlyProductIDs.contains(pid) { return 0 }
                if monthlyProductIDs.contains(pid) { return 1 }
                if p.packageType == .annual { return 0 }
                if p.packageType == .monthly { return 1 }
                if Self.infersAnnualBilling(p) { return 0 }
                if Self.infersMonthlyBilling(p) { return 1 }
                return 2
            }

            let delta = rank(lhs) - rank(rhs)
            if delta != 0 { return delta < 0 }
            return lhs.identifier < rhs.identifier
        }
    }

    private static func infersAnnualBilling(_ package: Package) -> Bool {
        guard let period = package.storeProduct.subscriptionPeriod else { return false }
        return period.unit == .year && period.value >= 1
    }

    private static func infersMonthlyBilling(_ package: Package) -> Bool {
        guard let period = package.storeProduct.subscriptionPeriod else { return false }
        return period.unit == .month && period.value == 1
    }

    private var selectedPackage: Package? {
        let packages = displayPackages
        guard !packages.isEmpty else { return nil }

        if let selectedPackageID,
           let explicit = packages.first(where: { $0.identifier == selectedPackageID }) {
            return explicit
        }

        return packages.first(where: { Self.yearlyProductIDs.contains($0.storeProduct.productIdentifier) })
            ?? packages.first(where: { Self.monthlyProductIDs.contains($0.storeProduct.productIdentifier) })
            ?? packages.first(where: { $0.packageType == .annual })
            ?? packages.first(where: { Self.infersAnnualBilling($0) })
            ?? packages.first(where: { $0.packageType == .monthly })
            ?? packages.first(where: { Self.infersMonthlyBilling($0) })
            ?? packages.first
    }

    private func pricingOption(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let product = package.storeProduct
        return Button {
            selectedPackageID = package.identifier
        } label: {
            MMDarkPlanRow(
                title: planDisplayTitle(for: package),
                price: priceCaption(for: package, product: product),
                detail: storeProductListingTitle(for: package, product: product) ?? planSubtitle(for: package),
                isSelected: isSelected
            )
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "MoveMark Pro, \(planDisplayTitle(for: package)), \(priceCaption(for: package, product: product))"
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Shown when App Store localized title adds detail beyond our Monthly/Yearly label.
    private func storeProductListingTitle(for package: Package, product: StoreProduct) -> String? {
        let raw = product.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let plan = planDisplayTitle(for: package)
        if raw.caseInsensitiveCompare(plan) == .orderedSame { return nil }
        if raw.caseInsensitiveCompare("MoveMark Pro") == .orderedSame { return nil }
        return raw
    }

    private func priceCaption(for package: Package, product: StoreProduct) -> String {
        let period = periodLabel(for: package)
        return "\(product.localizedPriceString) / \(period)"
    }

    private func periodLabel(for package: Package) -> String {
        switch package.packageType {
        case .monthly:
            return "month"
        case .annual:
            return "year"
        case .weekly:
            return "week"
        case .twoMonth:
            return "2 months"
        case .threeMonth:
            return "3 months"
        case .sixMonth:
            return "6 months"
        default:
            break
        }

        guard let sub = package.storeProduct.subscriptionPeriod else {
            return "billing period"
        }

        let value = sub.value
        switch sub.unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return "billing period"
        }
    }

    /// A plain billing fact under the plan name — no "best value" claims.
    private func planSubtitle(for package: Package) -> String {
        switch package.packageType {
        case .monthly:
            return "Billed monthly"
        case .annual:
            return "Billed yearly"
        default:
            if Self.infersAnnualBilling(package) {
                return "Billed yearly"
            }
            if Self.infersMonthlyBilling(package) {
                return "Billed monthly"
            }
            return "Billed every \(periodLabel(for: package))"
        }
    }

    private func startPurchase(_ package: Package, isReportPack: Bool = false) {
        guard !subscriptionManager.isStoreKitBusy, !showPurchaseSuccess else { return }

        localErrorMessage = nil
        restoreOutcomeMessage = nil
        MoveMarkAnalytics.track(
            .purchaseStarted,
            properties: [
                "product": package.storeProduct.productIdentifier,
                "report_pack": isReportPack ? "1" : "0",
            ]
        )

        Task { @MainActor in
            let completed = await subscriptionManager.purchase(package: package)
            guard completed else {
                if let message = subscriptionManager.lastPurchaseErrorMessage {
                    localErrorMessage = paywallBannerMessage(message)
                }
                return
            }

            if isReportPack || Self.isReportPackProduct(package.storeProduct.productIdentifier) {
                if let userId = sessionManager.userId {
                    subscriptionManager.addReportPackCredit(forUser: userId)
                }
                MoveMarkAnalytics.track(.purchaseCompleted, properties: ["product": "report_pack"])
                await completePurchaseSuccess(isReportPack: true)
                return
            }

            guard subscriptionManager.hasPro else {
                localErrorMessage = "Purchase finished, but Pro isn’t active yet. Try Restore purchases."
                return
            }

            MoveMarkAnalytics.track(.purchaseCompleted, properties: ["product": "pro"])
            await completePurchaseSuccess(isReportPack: false)
        }
    }

    private func restorePurchases() {
        guard !subscriptionManager.isStoreKitBusy, !showPurchaseSuccess else { return }

        localErrorMessage = nil
        restoreOutcomeMessage = nil

        Task { @MainActor in
            let restored = await subscriptionManager.restorePurchases(forUser: sessionManager.userId)
            if restored, subscriptionManager.hasPro {
                await completePurchaseSuccess(isReportPack: false)
            } else if restored, subscriptionManager.reportPackCredits(forUser: sessionManager.userId) > 0 {
                await completePurchaseSuccess(isReportPack: true)
            } else if let err = subscriptionManager.lastRestoreErrorMessage {
                restoreOutcomeMessage = err
            } else {
                restoreOutcomeMessage = "No active subscription or Report Pack was found for this Apple ID."
            }
        }
    }

    @MainActor
    private func completePurchaseSuccess(isReportPack: Bool = false) async {
        purchaseSuccessWasReportPack = isReportPack
        withAnimation(.easeOut(duration: 0.22)) {
            showPurchaseSuccess = true
        }
        MMHaptics.success()
        try? await Task.sleep(for: .milliseconds(750))
        onClose()
    }

    private func userFacingPaywallError(from error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "MoveMark.Subscription" {
            return paywallBannerMessage(ns.localizedDescription)
        }

        let raw = error.localizedDescription.lowercased()

        if raw.contains("cancel") {
            return "Purchase cancelled."
        }

        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }

        if raw.contains("metadata")
            || (raw.contains("product") && raw.contains("unavailable"))
            || raw.contains("configuration")
            || (raw.contains("store") && raw.contains("problem")) {
            return "Plans aren’t available right now. Try again later."
        }

        return "Purchase didn’t go through. Try again."
    }
}
