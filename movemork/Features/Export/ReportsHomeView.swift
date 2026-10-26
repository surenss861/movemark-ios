//
//  ReportsHomeView.swift
//  movemork
//
//  @file Reports tab — the rental's proof records: one primary report artifact (the move-in report and
//        its state), a quiet history of generated reports, and the other report types below
//  @domain reports
//  @status wip
//  @see [[VISUAL_STANDARD]]
//  @see [[ExportHistoryView.swift]] — loads exports, owns download / preview / share, feeds this view
//

import SwiftUI

/// Everything Reports shows, already computed. Presentational only: no store or network access here.
struct ReportsHomeModel {
    enum Primary: Equatable {
        case loading
        case noRental
        /// Something the report requires is missing: room proof, or one supporting record.
        case needsProof(Need)
        case canGenerate
        case generating
        case ready(generatedAt: Date?)
        /// The newest attempt failed; `lastReadyAt` is set when an earlier report can still be opened.
        case failed(lastReadyAt: Date?)
    }

    enum Need: Equatable { case rooms, record }

    struct HistoryItem: Identifiable {
        enum Status { case ready, generating, failed, unavailable }
        let id: UUID
        let title: String
        let date: Date?
        let status: Status
        /// Retry is offered only on the newest attempt of its type.
        var canRetry: Bool = false
    }

    struct OtherReport: Identifiable {
        let id: String
        let title: String
        let detail: String
        var isProLocked: Bool = false
        var isGenerating: Bool = false
    }

    var rentalName: String
    var documented: Int = 0
    var totalRooms: Int = 0
    var photos: Int = 0
    var records: Int = 0
    var issues: Int = 0
    var primary: Primary
    /// The lime action's label where it varies (needs proof, can generate).
    var primaryTitle: String = "Generate report"
    var history: [HistoryItem] = []
    var others: [OtherReport] = []
    var errorMessage: String?
}

/// The Reports tab: a document control centre for one rental. The move-in report is the artifact at the
/// top — what it covers, whether it's ready, and the one thing to do with it; past reports sit below in
/// a quiet list. Lime marks only the single most important action.
struct ReportsHomeView: View {
    enum HistoryAction { case view, share, retry }

    let model: ReportsHomeModel
    var onPrimary: () -> Void = {}
    var onShare: () -> Void = {}
    var onViewLastReport: () -> Void = {}
    var onHistory: (ReportsHomeModel.HistoryItem, HistoryAction) -> Void = { _, _ in }
    var onOther: (ReportsHomeModel.OtherReport) -> Void = { _ in }
    var onRetry: () -> Void = {}
    /// Snapshot tests open the scroll at its end to check the tail clears the dock.
    var initialScrollAnchor: UnitPoint? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }
    @State private var showAllHistory = false
    /// Composed at 402pt wide; scale with the screen so proportions hold.
    @State private var k: CGFloat = 1

    private static let historyPreviewLimit = 5

    fileprivate enum Ink {
        static let hero = Color(red: 0.086, green: 0.094, blue: 0.090)          // #161817, as the Vault
        static let heroSecondary = Color.white.opacity(0.62)
        static let sheet = Color(red: 0.973, green: 0.973, blue: 0.973)          // #F8F8F8
        static let card = Color.white
        static let cardStroke = Color(red: 0.925, green: 0.925, blue: 0.925)     // #ECECEC
        static let text = Color(red: 0.078, green: 0.078, blue: 0.082)           // #141415
        static let secondary = Color(red: 0.494, green: 0.498, blue: 0.502)      // #7E7F80
        static let separator = Color(red: 0.918, green: 0.918, blue: 0.922)      // #EAEAEB
        static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)           // #CAE36C
        static let limeMark = Color(red: 0.757, green: 0.914, blue: 0.298)       // #C1E94C
        static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)
        static let paper = Color(red: 0.949, green: 0.949, blue: 0.941)          // document tile
        static let danger = Color(red: 0.776, green: 0.243, blue: 0.204)
    }

    /// The header's dark, for a navigation bar that sits on it when Reports is pushed.
    static let headerColor = Ink.hero

    private var inset: CGFloat { 20 * k }
    private var sheetRadius: CGFloat { 22 * k }
    private var cardRadius: CGFloat { 16 * k }
    private var ctaHeight: CGFloat { 46 * k }
    private var rowHeight: CGFloat { 56 * k }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                sheet.padding(.top, -sheetRadius)
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(initialScrollAnchor)
        // A solid band of the header colour under the status bar: scrolled content never runs under the clock.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(Ink.hero.ignoresSafeArea(edges: .top))
        }
        .background(alignment: .top) { Ink.hero.frame(height: 360).ignoresSafeArea(edges: .top) }
        .background(Ink.sheet.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            k = min(max(width / 402, 0.92), 1.12)
        }
    }

    // MARK: - Header

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MoveMark")
                .font(.system(size: 17 * k, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: 44 * k)
            if !isAX {
                Text("REPORTS")
                    .mmFont(11, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.heroSecondary)
                    .padding(.top, 22 * k)
            }
            Text("Your proof records")
                .mmFont(27, .semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, isAX ? 14 * k : 6 * k)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 28 * k + sheetRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.hero)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = model.errorMessage {
                errorRow(error).padding(.bottom, 14 * k)
            }
            artifact
            if !model.history.isEmpty {
                sectionHeader("Report history").padding(.top, 32 * k)
                historyList.padding(.top, 12 * k)
            }
            if !model.others.isEmpty {
                sectionHeader("More reports").padding(.top, 32 * k)
                othersList.padding(.top, 12 * k)
            }
            if rootTabBarVisible {
                MMSignedInScrollTailSpacer(kind: .reportsTab)
            } else {
                Color.clear.frame(height: 32)
            }
        }
        .padding(.horizontal, inset)
        .padding(.top, 20 * k)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: sheetRadius, topTrailingRadius: sheetRadius, style: .continuous)
                .fill(Ink.sheet)
        )
    }

    // MARK: - The primary report

    @ViewBuilder
    private var artifact: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.primary == .noRental {
                noRental
            } else {
                artifactIdentity
                artifactStatus.padding(.top, 16 * k)
                artifactActions
            }
        }
        .padding(18 * k)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cardRadius, style: .continuous).strokeBorder(Ink.cardStroke, lineWidth: 0.75))
    }

    /// What the report is and what it covers.
    private var artifactIdentity: some View {
        HStack(alignment: .top, spacing: 14 * k) {
            VStack(alignment: .leading, spacing: 0) {
                Text("MOVE-IN REPORT")
                    .mmFont(11, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.secondary)
                Text(model.rentalName)
                    .mmFont(22, .semibold)
                    .foregroundStyle(Ink.text)
                    .lineLimit(isAX ? 3 : 2)
                    .minimumScaleFactor(isAX ? 1 : 0.85)
                    .padding(.top, 6 * k)
                if let rooms = roomsLine {
                    Text(rooms)
                        .mmFont(14.5)
                        .foregroundStyle(Ink.text)
                        .padding(.top, 6 * k)
                }
                if let counts = countsLine {
                    Text(counts)
                        .mmFont(13)
                        .monospacedDigit()
                        .foregroundStyle(Ink.secondary)
                        .padding(.top, 3 * k)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isAX { documentTile }
        }
        .accessibilityElement(children: .combine)
    }

    /// A plain document mark. Not a preview: the PDF itself is the artifact, opened with View report.
    private var documentTile: some View {
        RoundedRectangle(cornerRadius: 8 * k, style: .continuous)
            .fill(Ink.paper)
            .frame(width: 44 * k, height: 56 * k)
            .overlay {
                Image(systemName: "doc.text")
                    .font(.system(size: 19 * k, weight: .regular))
                    .foregroundStyle(Ink.text.opacity(0.55))
            }
            .accessibilityHidden(true)
    }

    private var roomsLine: String? {
        guard model.totalRooms > 0 else { return nil }
        if model.documented >= model.totalRooms {
            return "\(model.totalRooms) \(model.totalRooms == 1 ? "room" : "rooms") documented"
        }
        return "\(model.documented) of \(model.totalRooms) rooms documented"
    }

    private var countsLine: String? {
        guard model.totalRooms > 0 || model.photos > 0 else { return nil }
        return [Self.count(model.photos, "photo"), Self.count(model.records, "record"), Self.count(model.issues, "issue")]
            .joined(separator: " · ")
    }

    /// State in one readable line, with one quiet line of support under it.
    private var artifactStatus: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Ink.separator).frame(height: 1)
            HStack(spacing: 8 * k) {
                statusMark
                Text(statusTitle)
                    .mmFont(15, .semibold)
                    .foregroundStyle(Ink.text)
            }
            .padding(.top, 14 * k)
            if let detail = statusDetail {
                Text(detail)
                    .mmFont(13.5)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4 * k)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusMark: some View {
        switch model.primary {
        case .generating, .loading:
            ProgressView().controlSize(.small).tint(Ink.secondary)
        case .ready:
            Circle().fill(Ink.limeMark).frame(width: 9 * k, height: 9 * k)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14 * k, weight: .semibold))
                .foregroundStyle(Ink.danger)
        case .needsProof, .canGenerate, .noRental:
            Circle().strokeBorder(Ink.secondary, lineWidth: 1.5).frame(width: 9 * k, height: 9 * k)
        }
    }

    private var statusTitle: String {
        switch model.primary {
        case .loading: "Checking your records…"
        case .noRental: ""
        case .needsProof(.rooms): "Needs room proof"
        case .needsProof(.record): "Needs one record"
        case .canGenerate: "Not generated yet"
        case .generating: "Generating report…"
        case .ready: "Ready"
        case .failed: "Couldn't generate report"
        }
    }

    private var statusDetail: String? {
        switch model.primary {
        case .loading, .noRental:
            return nil
        case .needsProof(.rooms):
            return "Document your rooms, then generate one dated PDF of your proof."
        case .needsProof(.record):
            return "Add your lease, deposit receipt or listing, then generate one dated PDF of your proof."
        case .canGenerate:
            return "One dated PDF with every room photo, record and issue, ready to send to your landlord."
        case .generating:
            return "We're assembling your evidence into a PDF."
        case .ready(let date):
            return date.map { "Generated \(Self.stamp($0))" }
        case .failed(let lastReady):
            if let lastReady {
                return "Your evidence is safe. Your last report, from \(lastReady.formatted(.dateTime.month(.abbreviated).day()).replacingOccurrences(of: " ", with: "\u{00A0}")), is still available."
            }
            return "Your evidence is safe. Try again in a moment."
        }
    }

    @ViewBuilder
    private var artifactActions: some View {
        switch model.primary {
        case .loading, .generating, .noRental:
            EmptyView()
        case .needsProof, .canGenerate:
            limeButton(model.primaryTitle, icon: primaryIcon, action: onPrimary)
                .padding(.top, 18 * k)
        case .ready:
            VStack(spacing: 4 * k) {
                limeButton("View report", icon: "doc.text.magnifyingglass", action: onPrimary)
                quietButton("Share", icon: "square.and.arrow.up", action: onShare)
            }
            .padding(.top, 18 * k)
        case .failed(let lastReady):
            VStack(spacing: 4 * k) {
                limeButton("Retry", icon: "arrow.clockwise", action: onPrimary)
                if lastReady != nil { quietButton("View last report", icon: nil, action: onViewLastReport) }
            }
            .padding(.top, 18 * k)
        }
    }

    private var primaryIcon: String {
        switch model.primary {
        case .needsProof(.rooms): "camera.fill"
        case .needsProof(.record): "doc.badge.plus"
        default: "doc.text.fill"
        }
    }

    private var noRental: some View {
        VStack(alignment: .leading, spacing: 6 * k) {
            Text("No rental yet")
                .mmFont(20, .semibold)
                .foregroundStyle(Ink.text)
            Text("Reports are built from a rental's saved proof. Add your rental in Proof to start.")
                .mmFont(14)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            limeButton(model.primaryTitle, icon: "house.fill", action: onPrimary).padding(.top, 12 * k)
        }
    }

    private func limeButton(_ title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8 * k) {
                if let icon { Image(systemName: icon).font(.system(size: 14 * k, weight: .semibold)) }
                Text(title)
                    .mmFont(15, .semibold)
                    .lineLimit(isAX ? 3 : 1)
                    .minimumScaleFactor(isAX ? 1 : 0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Ink.onLime)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ctaHeight)
            .padding(.vertical, isAX ? 8 : 0)
            .background(Ink.lime, in: RoundedRectangle(cornerRadius: ctaHeight / 2, style: .continuous))
        }
        .buttonStyle(MMLightPressStyle())
    }

    private func quietButton(_ title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7 * k) {
                if let icon { Image(systemName: icon).font(.system(size: 14 * k, weight: .medium)) }
                Text(title).mmFont(15, .medium)
            }
            .foregroundStyle(Ink.text)
            .frame(maxWidth: .infinity, minHeight: 44 * k)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
    }

    // MARK: - History

    private var historyList: some View {
        let items = showAllHistory ? model.history : Array(model.history.prefix(Self.historyPreviewLimit))
        return VStack(alignment: .leading, spacing: 8 * k) {
            listContainer {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(Ink.separator).padding(.leading, 50 * k) }
                    historyRow(item)
                }
            }
            if model.history.count > Self.historyPreviewLimit {
                Button(showAllHistory ? "Show fewer" : "Show all \(model.history.count)") {
                    withAnimation(MMMotion.quick) { showAllHistory.toggle() }
                }
                .mmFont(13.5, .medium)
                .foregroundStyle(Ink.secondary)
                .frame(minHeight: 44)
                .padding(.leading, 4 * k)
            }
        }
    }

    private func historyRow(_ item: ReportsHomeModel.HistoryItem) -> some View {
        HStack(spacing: 14 * k) {
            Button {
                switch item.status {
                case .ready: onHistory(item, .view)
                case .failed where item.canRetry: onHistory(item, .retry)
                default: break
                }
            } label: {
                HStack(spacing: 14 * k) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16 * k, weight: .regular))
                        .foregroundStyle(Ink.text.opacity(0.75))
                        .frame(width: 22 * k)
                    VStack(alignment: .leading, spacing: 2 * k) {
                        Text(item.title).mmFont(14.5).foregroundStyle(Ink.text).lineLimit(isAX ? 3 : 1)
                        Text(historyCaption(item)).mmFont(12).foregroundStyle(Ink.secondary).lineLimit(isAX ? 3 : 1)
                    }
                    Spacer(minLength: 8 * k)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MMLightPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(item.status == .ready ? "Opens the report" : "")

            historyTrailing(item)
        }
        .padding(.leading, 14 * k)
        .padding(.trailing, 6 * k)
        .frame(maxWidth: .infinity, minHeight: rowHeight)
        .padding(.vertical, isAX ? 8 : 0)
    }

    @ViewBuilder
    private func historyTrailing(_ item: ReportsHomeModel.HistoryItem) -> some View {
        switch item.status {
        case .ready:
            Button { onHistory(item, .share) } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15 * k, weight: .medium))
                    .foregroundStyle(Ink.text.opacity(0.8))
                    .frame(width: 44 * k, height: 44 * k)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share \(item.title)")
        case .generating:
            ProgressView().controlSize(.small).tint(Ink.secondary).frame(width: 44 * k, height: 44 * k)
        case .failed where item.canRetry:
            Button("Retry") { onHistory(item, .retry) }
                .mmFont(14, .semibold)
                .foregroundStyle(Ink.text)
                .frame(minWidth: 44 * k, minHeight: 44 * k)
                .padding(.trailing, 8 * k)
        case .failed, .unavailable:
            EmptyView()
        }
    }

    private func historyCaption(_ item: ReportsHomeModel.HistoryItem) -> String {
        let status = switch item.status {
        case .ready: "Ready"
        case .generating: "Generating…"
        case .failed: "Couldn't generate"
        case .unavailable: "Unavailable"
        }
        guard let date = item.date else { return status }
        return "\(Self.stamp(date)) · \(status)"
    }

    // MARK: - Other report types

    private var othersList: some View {
        listContainer {
            ForEach(Array(model.others.enumerated()), id: \.element.id) { index, other in
                if index > 0 { Divider().overlay(Ink.separator).padding(.leading, 14 * k) }
                Button { onOther(other) } label: {
                    HStack(spacing: 10 * k) {
                        VStack(alignment: .leading, spacing: 2 * k) {
                            Text(other.title).mmFont(14.5).foregroundStyle(Ink.text).lineLimit(isAX ? 3 : 1)
                            Text(other.detail).mmFont(12).foregroundStyle(Ink.secondary).lineLimit(isAX ? 4 : 2)
                        }
                        Spacer(minLength: 8 * k)
                        if other.isGenerating {
                            ProgressView().controlSize(.small).tint(Ink.secondary)
                        } else if other.isProLocked {
                            Text("PRO")
                                .mmFont(10.5, .semibold)
                                .tracking(0.5)
                                .foregroundStyle(Ink.secondary)
                                .padding(.horizontal, 7 * k)
                                .padding(.vertical, 3 * k)
                                .overlay(Capsule().strokeBorder(Ink.cardStroke, lineWidth: 1))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11 * k, weight: .semibold))
                            .foregroundStyle(Ink.secondary.opacity(0.7))
                    }
                    .padding(.horizontal, 14 * k)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
                    .padding(.vertical, isAX ? 8 : 6 * k)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Pieces

    private func listContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Ink.card, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cardRadius, style: .continuous).strokeBorder(Ink.cardStroke, lineWidth: 0.75))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .mmFont(16, .semibold)
            .foregroundStyle(Ink.text)
            .accessibilityAddTraits(.isHeader)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10 * k) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Ink.danger)
            Text(message).mmFont(14).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(MMCopy.tryAgain, action: onRetry).mmFont(14, .semibold).foregroundStyle(Ink.text)
        }
        .padding(12)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12 * k, style: .continuous))
    }

    static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(n == 1 ? noun : noun + "s")"
    }

    /// "Oct 26 · 8:29 PM"
    static func stamp(_ date: Date) -> String {
        "\(date.formatted(.dateTime.month(.abbreviated).day())) · \(date.formatted(date: .omitted, time: .shortened))"
    }
}
