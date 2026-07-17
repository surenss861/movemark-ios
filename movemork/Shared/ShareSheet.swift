//
//  ShareSheet.swift
//  movemork
//
//  MoveMark — Plain UIActivityViewController wrapper for ad-hoc shares (e.g. in-memory PDF Data).
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
