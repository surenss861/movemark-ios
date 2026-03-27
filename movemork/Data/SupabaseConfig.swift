//
//  SupabaseConfig.swift
//  movemork
//
//  MoveMark — Supabase singleton client.
//
//  If you see "Invalid API key" on sign-up/sign-in:
//  - Use the anon (public) key only — never the service_role key.
//  - URL and key must be from the same project.
//  - Get fresh values: Supabase Dashboard → Project Settings → API
//    → Project URL and anon public key.
//
//  Initial session / bootstrap:
//  - `emitLocalSessionAsInitialSession: true` below opts into stable local-session-as-initial behavior.
//  - SessionManager treats `.initialSession` only until first resolution, then ignores duplicate emissions.
//  See: https://github.com/supabase/supabase-swift/pull/822
//

import Foundation
import Supabase

/// OAuth callback for Supabase auth (Google / Apple).
/// Add this exact URL in Supabase Dashboard → Auth → URL Configuration → Redirect URLs.
let supabaseOAuthRedirectURL = URL(string: "movemark://auth-callback")!

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://cxegmojxcstxinhuexjj.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4ZWdtb2p4Y3N0eGluaHVleGpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTUxMTIsImV4cCI6MjA4ODM5MTExMn0.VKLuYWh9DIROf2BmEucS08e5lAMGPp9L_byHrdkfra8",
    options: SupabaseClientOptions(
        auth: .init(
            redirectToURL: supabaseOAuthRedirectURL,
            emitLocalSessionAsInitialSession: true
        )
    )
)
