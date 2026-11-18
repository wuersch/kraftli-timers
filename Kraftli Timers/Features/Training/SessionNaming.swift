//
//  SessionNaming.swift
//  Kraftli Timers
//
//  The rules for session names (UC-0013): unique, and how a copy is named.
//

import Foundation

enum SessionNaming {
    /// The form names are compared in: without surrounding whitespace and without
    /// regard to case, so "Legs" and " legs " are the same name.
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Whether one of `others` already has `name`. The caller leaves the session being
    /// edited out of `others`.
    static func isTaken(_ name: String, by others: [String]) -> Bool {
        let wanted = normalized(name)
        return others.contains { normalized($0) == wanted }
    }

    /// The name for a copy: "Legs" → "Legs 2", and "Legs 2" → "Legs 3", taking the first
    /// number that is free.
    static func copyName(of name: String, existing: [String]) -> String {
        let base = baseName(of: name)
        var number = 2
        while isTaken("\(base) \(number)", by: existing) {
            number += 1
        }
        return "\(base) \(number)"
    }

    /// The name without a trailing copy number: "Legs 2" → "Legs".
    private static func baseName(of name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ")
        guard words.count > 1, let last = words.last, Int(last) != nil else {
            return trimmed
        }
        return words.dropLast().joined(separator: " ")
    }
}
