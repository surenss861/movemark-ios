//
//  RentalLocation.swift
//  movemork
//
//  How a rental's city and province are shown. Older builds stored the placeholder "Unknown" when a field
//  was left blank; those rows are left as they are and the placeholder is simply never displayed.
//

import Foundation

enum RentalLocation {
    private static let placeholders: Set<String> = ["unknown", "n/a", "na", "none", "-"]

    /// The stored value, or nil when it's blank or a placeholder.
    static func meaningful(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || placeholders.contains(trimmed.lowercased()) ? nil : trimmed
    }

    /// "Toronto, ON", "Toronto", "ON" or "".
    static func line(city: String?, province: String?) -> String {
        [meaningful(city), meaningful(province)].compactMap { $0 }.joined(separator: ", ")
    }
}
