//
//  SupabaseConfig.swift
//  movemork
//
//  MoveMark — Supabase singleton client.
//
//  Configure via `Config/Secrets.xcconfig` (gitignored; copy from Secrets.xcconfig.example),
//  which sets `SUPABASE_URL` and `SUPABASE_ANON_KEY` for Info.plist substitution.
//  In .xcconfig, `https://…` is truncated at `//` (comment) unless split — see example file.
//  Do not commit production secrets in Swift source or project.pbxproj.
//
//  OAuth: add `movemark://auth-callback` in Supabase Dashboard → Auth → Redirect URLs.
//

import Foundation
import Supabase

let supabaseOAuthRedirectURL = URL(string: "movemark://auth-callback")!

private struct SupabaseAppConfig {
    let url: URL
    let anonKey: String
    let isValid: Bool
}

/// Placeholder client when plist keys are missing or unusable (e.g. empty or truncated xcconfig `https:`). Avoids launch-time `fatalError`; UI should gate on `isSupabaseConfigured`.
private let supabasePlaceholderURL = URL(string: "https://invalid.movemark.app")!
private let supabasePlaceholderAnonKey = "invalid"

private let supabaseAppConfig: SupabaseAppConfig = {
    let urlString = (Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let key = (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !key.isEmpty, let url = URL(string: urlString) else {
        return SupabaseAppConfig(url: supabasePlaceholderURL, anonKey: supabasePlaceholderAnonKey, isValid: false)
    }
    let scheme = url.scheme?.lowercased()
    guard scheme == "https" || scheme == "http", let host = url.host, !host.isEmpty else {
        return SupabaseAppConfig(url: supabasePlaceholderURL, anonKey: supabasePlaceholderAnonKey, isValid: false)
    }

    return SupabaseAppConfig(url: url, anonKey: key, isValid: true)
}()

/// `false` when `SupabaseURL` / `SupabaseAnonKey` are missing, empty, or not a usable HTTP(S) URL with a host (catches truncated `https:` from .xcconfig).
var isSupabaseConfigured: Bool { supabaseAppConfig.isValid }

let supabase = SupabaseClient(
    supabaseURL: supabaseAppConfig.url,
    supabaseKey: supabaseAppConfig.anonKey,
    options: SupabaseClientOptions(
        auth: .init(
            redirectToURL: supabaseOAuthRedirectURL,
            emitLocalSessionAsInitialSession: true
        )
    )
)
