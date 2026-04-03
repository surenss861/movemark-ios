//
//  SupabaseConfig.swift
//  movemork
//
//  MoveMark — Supabase singleton client.
//
//  Configure via `Config/Secrets.xcconfig` (gitignored; copy from Secrets.xcconfig.example),
//  which sets `SUPABASE_URL` and `SUPABASE_ANON_KEY` for Info.plist substitution.
//  Do not commit production secrets in Swift source or project.pbxproj.
//
//  OAuth: add `movemark://auth-callback` in Supabase Dashboard → Auth → Redirect URLs.
//

import Foundation
import Supabase

let supabaseOAuthRedirectURL = URL(string: "movemark://auth-callback")!

private func loadSupabaseConfig() -> (url: URL, anonKey: String) {
    let urlString = (Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let key = (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard let url = URL(string: urlString), !urlString.isEmpty, !key.isEmpty else {
        fatalError(
            "SupabaseURL / SupabaseAnonKey missing or empty. Set SUPABASE_URL and SUPABASE_ANON_KEY in the app target’s Build Settings (same pattern as MoveMarkAPIBaseURL)."
        )
    }
    return (url, key)
}

private let supabaseConfig = loadSupabaseConfig()

let supabase = SupabaseClient(
    supabaseURL: supabaseConfig.url,
    supabaseKey: supabaseConfig.anonKey,
    options: SupabaseClientOptions(
        auth: .init(
            redirectToURL: supabaseOAuthRedirectURL,
            emitLocalSessionAsInitialSession: true
        )
    )
)
