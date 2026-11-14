//
//  MMInAppLegalBrowser.swift
//  movemork
//
//  @file MoveMark's own pages open in the system's in-app browser, from anywhere in the app. Safari View keeps its
//        open-in-Safari button. Every other link behaves as it did.
//  @domain onboarding-auth
//  @status wip
//  @see [[LegalAcceptanceScreen.swift]]
//

import SafariServices
import SwiftUI

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct InAppLegalBrowser: ViewModifier {
    private struct Page: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    @State private var page: Page?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "https", url.host() == "movemark.ca" else { return .systemAction }
                page = Page(url: url)
                return .handled
            })
            .sheet(item: $page) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}

extension View {
    func mmInAppLegalBrowser() -> some View { modifier(InAppLegalBrowser()) }
}
