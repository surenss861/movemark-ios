//
//  MMDeviceNoun.swift
//  movemork
//
//  "this iPhone" in copy about photos kept on the device. The app also runs on iPad (UIDeviceFamily 1,2), where
//  "Saved on this iPhone" was simply untrue. iPhone copy is unchanged.
//

import UIKit

@MainActor
enum MMDeviceNoun {
    /// "iPhone" or "iPad", for the device the app is running on.
    static var current: String { noun(isPad: UIDevice.current.userInterfaceIdiom == .pad) }

    nonisolated static func noun(isPad: Bool) -> String { isPad ? "iPad" : "iPhone" }
}
