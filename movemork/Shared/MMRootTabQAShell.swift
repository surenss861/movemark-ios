//
//  MMRootTabQAShell.swift
//  movemork
//
//  DEBUG only: `-MMRichQA tabs` mounts the three root pages with fixture data inside the production root-tab
//  container (MMRootTabHost + MMRootTabSwitcher + MMRootDock), each page in its own NavigationStack as in
//  AuthenticatedTabShellView, so tab switching can be recorded and UI-tested without a signed-in account.
//
//  Launch arguments (DEBUG):
//  - `-MMTabAutoplay` runs every ordered pair of tabs with pauses, then rapid / mid-transition bursts, for
//    simulator recordings (see scripts/ios-nav-frame-scan.swift).
//  Reduce Motion follows the simulator setting (Settings › Accessibility › Motion).
//  - In `MM_NAV_LAB` builds, `-MMNavVariant A|B|C` and `-MMNavDock classic|pill` pick the variant / dock.
//  Account's "Contact support" row pushes a fixture screen, so navigation state can be checked across tabs.
//

#if DEBUG
import SwiftUI

struct MMRootTabQAShell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tabs = MMRootTabSwitcher()
    @State private var scrollToTopTokens: [RootTab: Int] = [:]
    @State private var reportsPath = NavigationPath()
    @State private var accountPath = NavigationPath()

    private static let args = ProcessInfo.processInfo.arguments

    var body: some View {
        MMRootTabHost(switcher: tabs, scrollToTopTokens: scrollToTopTokens, showsDock: true) { tab in
            page(tab)
        } dock: {
            MMRootDock(selectedTab: Binding(get: { tabs.selected }, set: { select($0) }), onReselect: reselect)
        }
        .task { await autoCycle() }
        .preferredColorScheme(.dark)
        .task { await autoplay() }
    }

    /// `-MMNavAutoCycle YES`: switches tabs on a timer, so motion can be recorded with no test harness stalling frames.
    private func autoCycle() async {
        guard UserDefaults.standard.bool(forKey: "MMNavAutoCycle") else { return }
        let order: [RootTab] = [.exports, .account, .vaults]
        try? await Task.sleep(for: .seconds(3))
        for round in 0..<6 {
            for tab in order {
                select(tab)
                try? await Task.sleep(for: round < 4 ? .milliseconds(1500) : .milliseconds(120))
            }
        }
    }

    private func select(_ tab: RootTab) {
        tabs.select(tab, reduceMotion: reduceMotion)
    }

    /// Same as the production shell: a pushed tab pops to its root, a tab at its root scrolls to the top.
    private func reselect(_ tab: RootTab) {
        switch tab {
        case .exports where !reportsPath.isEmpty: reportsPath = NavigationPath()
        case .account where !accountPath.isEmpty: accountPath = NavigationPath()
        default: scrollToTopTokens[tab, default: 0] += 1
        }
    }

    // MARK: - Autoplay (recordings)

    /// Every ordered pair with settles between, then a rapid burst (90–120 ms apart, i.e. mid-transition), a
    /// single interrupted switch (60 ms), and a final settle. Times are in the recording's frame log.
    private func autoplay() async {
        guard Self.args.contains("-MMTabAutoplay") else { return }
        func wait(_ ms: UInt64) async { try? await Task.sleep(nanoseconds: ms * 1_000_000) }
        func tap(_ tab: RootTab) {
            print("MMTabAutoplay t=\(Date().timeIntervalSince1970) tap=\(tab)")
            select(tab)
        }
        await wait(3000)
        // Pairs: P→R, R→A, A→P, P→A, A→R, R→P.
        for tab in [RootTab.exports, .account, .vaults, .account, .exports, .vaults] {
            tap(tab); await wait(1400)
        }
        // Rapid burst, latest wins: ends on Reports.
        for (tab, gap) in [(RootTab.exports, 100), (.account, 90), (.vaults, 120), (.exports, 110), (.vaults, 95), (.account, 100)] as [(RootTab, UInt64)] {
            tap(tab); await wait(gap)
        }
        tap(.exports); await wait(1500)
        // Interrupted: Account, then Proof 60 ms later.
        tap(.account); await wait(60)
        tap(.vaults); await wait(1500)
        print("MMTabAutoplay done")
    }

    // MARK: - Fixture pages

    @ViewBuilder
    private func page(_ tab: RootTab) -> some View {
        switch tab {
        case .vaults:
            NavigationStack {
                ProofHomeView(model: Self.proof, resolvePhotoURL: { _ in nil })
                    .toolbar(.hidden, for: .navigationBar)
                    .mmRootTabAccessibilityGate()
            }
        case .exports:
            NavigationStack(path: $reportsPath) {
                ReportsHomeView(model: Self.reports)
                    .toolbar(.hidden, for: .navigationBar)
                    .mmRootTabAccessibilityGate()
            }
        case .account:
            NavigationStack(path: $accountPath) {
                AccountHomeView(model: Self.account, onAction: { action in
                    if action == .support { accountPath.append("support") }
                })
                .toolbar(.hidden, for: .navigationBar)
                .mmRootTabAccessibilityGate()
                .navigationDestination(for: String.self) { _ in
                    Text("Support fixture")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(white: 0.97))
                        .navigationTitle("Support")
                        .accessibilityIdentifier("qa.supportFixture")
                        .mmRootTabAccessibilityGate()
                }
            }
        }
    }

    private static let account = AccountHomeModel(email: "renter@example.com", name: "Alex", isPro: false, appVersion: "1.4.1 (QA)")

    private static let proof = ProofHomeModel(
        propertyName: "My apartment", addressLine: "Toronto, ON",
        documented: 6, totalRooms: 10,
        nextRoomName: "Primary Bedroom", primaryTitle: "Capture Primary Bedroom",
        photos: 18, records: 2, issues: 1,
        recent: [
            .init(id: UUID(), roomName: "Living Room", photoCount: 4, photoPath: "fixture/a.jpg"),
            .init(id: UUID(), roomName: "Kitchen", photoCount: 3, photoPath: "fixture/b.jpg"),
            .init(id: UUID(), roomName: "Bathroom", photoCount: 2, photoPath: "fixture/c.jpg"),
        ],
        upcoming: ["Primary Bedroom", "Bedroom 2", "Hallway", "Balcony"].map { .init(id: UUID(), roomName: $0) },
        actions: [
            .init(id: "lease", kind: .document(.lease), title: "Lease", subtitle: "Add your lease agreement", icon: "doc.text", needed: true),
            .init(id: "maintenance", kind: .maintenance, title: "Maintenance issue", subtitle: "1 open issue", icon: "wrench.adjustable"),
        ],
        otherRentals: []
    )

    private static var reports: ReportsHomeModel {
        var m = ReportsHomeModel(rentalName: "My apartment", documented: 6, totalRooms: 10, photos: 18, records: 2, issues: 1,
                                 primary: .needsProof(.rooms))
        m.primaryTitle = "Continue room proof"
        m.history = [.init(id: UUID(), title: "Move-in report", date: Date(timeIntervalSince1970: 1_761_510_540), status: .ready)]
        m.others = [.init(id: "move_out", title: "Move-out report", detail: "Not started"),
                    .init(id: "dispute", title: "Dispute packet", detail: "Needs move-in proof")]
        return m
    }
}
#endif
