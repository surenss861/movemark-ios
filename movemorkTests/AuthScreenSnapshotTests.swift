//
//  AuthScreenSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the entry screens (area A): Welcome, sign in / sign up, password reset, launch and
//        load-failure states, and the first-run steps — default, empty / loading / error, on the Pro phone,
//        the small phone and AX3.
//  @domain design-system
//  @see [[MMSystem.swift]]
//  @see [[ScreenSnapshotTests.swift]] — devices, strategy and hosting
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class AuthScreenSnapshotTests: XCTestCase {
    private let all = ScreenSnapshot.allDevices

    // MARK: Welcome

    /// Reduce Motion: the poster path (no video, no entrance animation), which is also what a snapshot can see.
    func testWelcome() {
        assertScreen(WelcomeScreen(previewSettled: ()), devices: all, inNavigation: false)
    }

    // MARK: Auth

    func testAuthSignUp() {
        assertScreen(AuthContainerView(previewMode: .signUp),
                     devices: all, inNavigation: false)
    }

    func testAuthSignIn() {
        assertScreen(AuthContainerView(previewMode: .signIn),
                     devices: all, inNavigation: false)
    }

    func testAuthSignInError() {
        assertScreen(AuthContainerView(previewMode: .signIn, error: "Email or password is incorrect."), inNavigation: false)
    }

    func testAuthSignUpConfirmEmail() {
        assertScreen(AuthContainerView(previewMode: .signUp, info: "Check your email to confirm your account, then sign in."), inNavigation: false)
    }

    // MARK: Password reset

    func testPasswordReset() {
        assertScreen(PasswordResetView(token: "t") {}, devices: all, inNavigation: false)
    }

    func testPasswordResetError() {
        assertScreen(PasswordResetView(token: "t", previewDidReset: false,
                                       previewError: "This reset link has expired. Request a new one."),
                     inNavigation: false)
    }

    func testPasswordResetDone() {
        assertScreen(PasswordResetView(token: "t", previewDidReset: true), inNavigation: false)
    }

    // MARK: Launch & failure

    func testLaunchWait() {
        assertScreen(MMLaunchWait(), inNavigation: false)
    }

    func testBackendMisconfigured() {
        assertScreen(BackendMisconfigurationView(), devices: all, inNavigation: false)
    }

    func testPropertyLoadFailure() {
        assertScreen(PropertyLoadFailureView(message: nil, isRetrying: false, onRetry: {}), devices: all, inNavigation: false)
    }

    func testPropertyLoadFailureRetrying() {
        assertScreen(PropertyLoadFailureView(message: "You appear to be offline. Your proof is safe on MoveMark.",
                                             isRetrying: true, onRetry: {}), inNavigation: false)
    }

    // MARK: First run

    func testFirstRunMoment() {
        assertScreen(FirstRunMomentPickerView(isPreparing: false) { _ in }, devices: all, inNavigation: false)
    }

    func testFirstRunMomentPreparing() {
        assertScreen(FirstRunMomentPickerView(isPreparing: true) { _ in }, inNavigation: false)
    }

    func testFirstRunSetup() {
        assertScreen(FirstRunPropertySetupView(requiresOnboarding: true, onCreated: { _ in }), devices: all, inNavigation: false)
    }

    func testFirstRunSetupError() {
        assertScreen(FirstRunPropertySetupView(requiresOnboarding: false, moment: .foundDamage,
                                               previewError: "Couldn’t open your new vault. Try again."),
                     inNavigation: false)
    }

    func testFirstRunRoom() {
        assertScreen(FirstRunRoomPickerView(propertyId: UUID(), onStartProof: { _, _ in }), devices: all, inNavigation: false)
    }

    func testFirstRunRoomError() {
        assertScreen(FirstRunRoomPickerView(propertyId: UUID(), moment: .depositQuestioned, previewSelection: .bathroom,
                                            previewError: "Couldn’t load your vault. Try again."),
                     inNavigation: false)
    }

    func testFirstRunOtherRoomSheet() {
        assertScreen(FirstRunOtherRoomSheet(otherRoomName: .constant(""), onUse: {}), devices: all)
    }
}
