//
//  AuthErrorMessageTests.swift
//  movemorkTests
//
//  Sign-in failures name what happened — wrong credentials, throttling, no connection — without telling an
//  unknown email apart from a wrong password (that would reveal which addresses have accounts).
//

import Foundation
import Testing
@testable import MoveMark

struct AuthErrorMessageTests {
    @Test func wrongCredentialsAreOneCalmMessage() {
        let message = MoveMarkFlowMessage.authOperationFailed(
            NeonAuthError.rejected(code: "INVALID_EMAIL_OR_PASSWORD", message: "Invalid email or password"))
        #expect(message == "Email or password doesn’t match.")
    }

    @Test func throttlingAndConnectionFailuresAreNamed() {
        #expect(MoveMarkFlowMessage.authOperationFailed(NeonAuthError.rejected(code: "RATE_LIMITED", message: ""))
                == "Too many attempts. Wait a minute, then try again.")
        #expect(MoveMarkFlowMessage.authOperationFailed(URLError(.notConnectedToInternet))
                == "No connection. Check your internet and try again.")
    }

    @Test func existingAccountOnSignUpSaysSignIn() {
        #expect(MoveMarkFlowMessage.authOperationFailed(NeonAuthError.rejected(code: "USER_ALREADY_EXISTS", message: ""))
                == "An account with this email already exists. Sign in instead.")
    }

    /// Found on iPad QA 2026-11-18: "Passwords do not match." and the other local checks surfaced as the
    /// generic "Couldn't complete sign-in. Try again.", which gives the person nothing to fix.
    @Test func localFormChecksKeepTheirOwnMessage() {
        for text in ["Enter your email.", "Password must be at least 8 characters.", "Passwords do not match."] {
            #expect(MoveMarkFlowMessage.authOperationFailed(SessionManager.AuthError.validation(text)) == text)
        }
    }
}
