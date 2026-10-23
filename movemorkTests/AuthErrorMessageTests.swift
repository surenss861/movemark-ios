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
    @Test func wrongCredentialsPointNewUsersToSignUp() {
        let message = MoveMarkFlowMessage.authOperationFailed(
            NeonAuthError.rejected(code: "INVALID_EMAIL_OR_PASSWORD", message: "Invalid email or password"))
        #expect(message == "Email or password is incorrect. New to MoveMark? Create a private vault instead.")
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
}
