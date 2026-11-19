//
//  PasswordResetLinkTests.swift
//  movemorkTests
//
//  Reset links reach the app two ways: the HTTPS Universal Link on the reset domain, and the
//  `movemark://` scheme from the reset page's "Open MoveMark" button. Anything else is ignored. Also the
//  rules behind "Forgot password?" (gating, email check, neutral answers, refused tokens).
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

@MainActor
struct PasswordResetLinkParsingTests {
    private let page = URL(string: "https://account.movemark.ca/reset")!

    @Test func tokenIsReadFromQueryOrFragmentOnBothEntries() {
        for raw in ["https://account.movemark.ca/reset?token=abc123",
                    "https://account.movemark.ca/reset#token=abc123",
                    "movemark://reset-password?token=abc123",
                    "movemark://reset-password#token=abc123",
                    "MOVEMARK://Reset-Password?token=abc123",
                    "https://ACCOUNT.movemark.ca/reset?foo=1&token=abc123"] {
            #expect(PasswordResetLink.payload(from: URL(string: raw)!, resetPage: page) == .token("abc123"), "\(raw)")
        }
    }

    @Test func percentEncodedTokensAreDecoded() {
        let url = URL(string: "movemark://reset-password?token=a%2Bb%3D")!
        #expect(PasswordResetLink.token(from: url, resetPage: page) == "a+b=")
    }

    @Test func neonAuthErrorRedirectOpensTheExpiredState() {
        for raw in ["https://account.movemark.ca/reset?error=INVALID_TOKEN",
                    "movemark://reset-password?error=INVALID_TOKEN",
                    "movemark://reset-password#error=INVALID_TOKEN"] {
            #expect(PasswordResetLink.payload(from: URL(string: raw)!, resetPage: page) == .invalid, "\(raw)")
            #expect(PasswordResetLink.token(from: URL(string: raw)!, resetPage: page) == nil)
        }
        // A token wins over a stray error parameter.
        #expect(PasswordResetLink.payload(from: URL(string: "movemark://reset-password?error=x&token=t")!,
                                          resetPage: page) == .token("t"))
    }

    @Test func linksWithoutAPayloadOrOnOtherPathsAreIgnored() {
        for raw in ["movemark://reset-password", "movemark://reset-password?token=&error=",
                    "movemark://other?token=abc", "https://account.movemark.ca/reset/extra?token=abc",
                    "https://account.movemark.ca.evil.example/reset?token=abc"] {
            #expect(PasswordResetLink.payload(from: URL(string: raw)!, resetPage: page) == nil, "\(raw)")
        }
    }
}

@MainActor
struct PasswordResetRequestTests {
    @Test func forgotPasswordShowsOnlyWithAResetPage() {
        #expect(PasswordResetRequest.isAvailable(resetPage: URL(string: "https://account.movemark.ca/reset")!))
        #expect(!PasswordResetRequest.isAvailable(resetPage: nil))
    }

    /// The unit-test host is a Debug build without the fixture: no reset page, so no "Forgot password?".
    @Test func debugBuildWithoutAResetPageHidesIt() {
        #expect(MoveMarkBackendConfig.passwordResetURL == nil)
        #expect(!PasswordResetRequest.isAvailable())
    }

    @Test func emailIsCheckedBeforeSending() {
        #expect(PasswordResetRequest.validationMessage(forEmail: "  ") == "Enter your email.")
        for bad in ["alex", "alex@", "@example.com", "alex@example", "alex@.com", "alex@example.", "a b@example.com", "a@b@c.com"] {
            #expect(PasswordResetRequest.validationMessage(forEmail: bad) == "Enter a valid email.", "\(bad)")
        }
        #expect(PasswordResetRequest.validationMessage(forEmail: " alex@example.com ") == nil)
    }

    @Test func sendAnswersTheSameWhetherOrNotTheAccountExists() {
        #expect(PasswordResetRequest.outcome(for: nil) == .sent)
        for code in ["USER_NOT_FOUND", "USER_EMAIL_NOT_FOUND", "EMAIL_NOT_FOUND"] {
            #expect(PasswordResetRequest.outcome(for: NeonAuthError.rejected(code: code, message: "User not found")) == .sent)
        }
    }

    @Test func everySendTakesTheSameMinimumTime() async {
        let clock = ContinuousClock()
        let fast = await clock.measure {
            let error = await PasswordResetRequest.send(minimum: .milliseconds(300)) {}
            #expect(error == nil)
        }
        let failing = await clock.measure {
            let error = await PasswordResetRequest.send(minimum: .milliseconds(300)) { throw URLError(.timedOut) }
            #expect(error is URLError)
        }
        #expect(fast >= .milliseconds(300))
        #expect(failing >= .milliseconds(300))
    }

    @Test func sendFailuresAreNamedWithoutLeakingServerText() {
        #expect(PasswordResetRequest.outcome(for: URLError(.notConnectedToInternet))
                == .failed("No connection. Check your internet and try again."))
        #expect(PasswordResetRequest.outcome(for: NeonAuthError.rejected(code: "RATE_LIMITED", message: ""))
                == .failed("Too many attempts. Wait a minute, then try again."))
        #expect(PasswordResetRequest.outcome(for: NeonAuthError.rejected(code: "INVALID_EMAIL", message: ""))
                == .failed("Enter a valid email."))
        #expect(PasswordResetRequest.outcome(for: NeonAuthError.rejected(code: "INTERNAL", message: "smtp exploded at host x"))
                == .failed(PasswordResetRequest.genericFailure))
        #expect(PasswordResetRequest.outcome(for: NeonAuthError.invalidResponse) == .failed(PasswordResetRequest.genericFailure))
        #expect(PasswordResetRequest.outcome(for: SessionManager.AuthError.validation("Enter your email."))
                == .failed("Enter your email."))
    }

    @Test func refusedTokensAreToldApartFromOtherSaveFailures() {
        #expect(PasswordResetRequest.isRejectedToken(NeonAuthError.rejected(code: "INVALID_TOKEN", message: "")))
        #expect(PasswordResetRequest.isRejectedToken(NeonAuthError.rejected(code: "TOKEN_EXPIRED", message: "")))
        #expect(!PasswordResetRequest.isRejectedToken(NeonAuthError.rejected(code: "PASSWORD_TOO_SHORT", message: "")))
        #expect(!PasswordResetRequest.isRejectedToken(URLError(.notConnectedToInternet)))
        #expect(MoveMarkFlowMessage.authOperationFailed(NeonAuthError.rejected(code: "INVALID_TOKEN", message: ""))
                == "This reset link is invalid or has expired. Request a new one.")
        #expect(MoveMarkFlowMessage.authOperationFailed(URLError(.timedOut))
                == "No connection. Check your internet and try again.")
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
