//
//  PasswordResetLinkTests.swift
//  movemorkTests
//
//  Reset links reach the app two ways: the HTTPS Universal Link on the reset domain, and the
//  `movemark://` scheme from the reset page's "Open in the app" button. Anything else is ignored.
//

import Foundation
import Testing
@testable import MoveMark

struct PasswordResetLinkTests {
    private let page = URL(string: "https://auth.movemark.example/reset")!

    @Test func universalLinkOnTheResetPageCarriesTheToken() {
        let url = URL(string: "https://auth.movemark.example/reset?token=abc123")!
        #expect(PasswordResetLink.token(from: url, resetPage: page) == "abc123")
    }

    @Test func schemeLinkStillWorks() {
        let url = URL(string: "movemark://reset-password?token=abc123")!
        #expect(PasswordResetLink.token(from: url, resetPage: page) == "abc123")
        #expect(PasswordResetLink.token(from: url, resetPage: nil) == "abc123")
    }

    @Test func otherHostsPathsAndSchemesAreIgnored() {
        for raw in ["https://evil.example/reset?token=abc", "https://auth.movemark.example/other?token=abc",
                    "http://auth.movemark.example/reset?token=abc", "https://auth.movemark.example/reset",
                    "https://auth.movemark.example/reset?token="] {
            #expect(PasswordResetLink.token(from: URL(string: raw)!, resetPage: page) == nil, "\(raw)")
        }
        #expect(PasswordResetLink.token(from: URL(string: "https://auth.movemark.example/reset?token=abc")!,
                                        resetPage: nil) == nil)
    }
}

struct RentalLocationTests {
    @Test func placeholdersAndBlanksAreNeverShown() {
        #expect(RentalLocation.line(city: "Toronto", province: "Unknown") == "Toronto")
        #expect(RentalLocation.line(city: "Toronto", province: "  ") == "Toronto")
        #expect(RentalLocation.line(city: "Toronto", province: "ON") == "Toronto, ON")
        #expect(RentalLocation.line(city: "unknown", province: "ON") == "ON")
        #expect(RentalLocation.line(city: "", province: "") == "")
    }
}
