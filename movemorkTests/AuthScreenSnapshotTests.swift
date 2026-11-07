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
    /// A fixed move-in date so the setup goldens don't change with the calendar.
    private static let moveIn = DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 4, day: 14).date!

    // MARK: Welcome

    /// Reduce Motion: the poster path (no video, no entrance animation), which is also what a snapshot can see.
    func testWelcome() {
        assertScreen(WelcomeScreen(previewSettled: ()), devices: all, inNavigation: false)
    }

    /// With the Apple / Google block (Debug + probe builds until the sign-in security gates pass).
    func testWelcomeWithSocial() {
        assertScreen(WelcomeScreen(previewSettled: (), showsSocial: true), devices: all, inNavigation: false)
    }

    /// The system Reduce Motion setting: no video, no entrance movement — the composition must not change.
    func testWelcomeReduceMotion() {
        assertScreen(WelcomeScreen(previewSettled: (), reduceMotion: true), devices: [("pro", ScreenSnapshot.pro)],
                     inNavigation: false)
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
        assertScreen(AuthContainerView(previewMode: .signIn, error: "Email or password doesn’t match."),
                     devices: all, inNavigation: false)
    }

    /// "Forgot password?" absent: builds without a reset page (Debug, and Release before 1.4).
    func testAuthSignInNoReset() {
        assertScreen(AuthContainerView(previewMode: .signIn, passwordResetAvailable: false), inNavigation: false)
    }

    /// The request step: email only, one lime action, back to sign in below.
    func testAuthResetRequest() {
        assertScreen(AuthContainerView(previewMode: .resetPassword), devices: all, inNavigation: false)
    }

    func testAuthResetRequestOffline() {
        assertScreen(AuthContainerView(previewMode: .resetPassword, error: "No connection. Check your internet and try again."),
                     inNavigation: false)
    }

    /// Neutral confirmation (never says whether the address has an account), resend waiting out its cooldown.
    func testAuthResetSent() {
        assertScreen(AuthContainerView(previewMode: .resetPassword, resetSentTo: "alex@example.com", resendCooldown: 42),
                     devices: all, inNavigation: false)
    }

    /// Sign-up needs the address confirmed: the form is replaced by "Check your email", not a banner in it.
    func testAuthSignUpConfirmEmail() {
        assertScreen(AuthContainerView(previewMode: .signUp, confirmationEmail: "alex@example.com"),
                     devices: all, inNavigation: false)
    }

    // MARK: Password reset

    func testPasswordReset() {
        assertScreen(PasswordResetView(link: .token("t")) { _ in }, devices: all, inNavigation: false)
    }

    func testPasswordResetError() {
        assertScreen(PasswordResetView(token: "t", previewDidReset: false,
                                       previewError: "No connection. Check your internet and try again."),
                     inNavigation: false)
    }

    /// Expired, used or malformed link (from the link itself or refused on save): request a new one.
    func testPasswordResetExpired() {
        assertScreen(PasswordResetView(link: .invalid) { _ in }, devices: all, inNavigation: false)
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
        assertScreen(PropertyLoadFailureView(isRetrying: false, onRetry: {}), devices: all, inNavigation: false)
    }

    func testPropertyLoadFailureRetrying() {
        assertScreen(PropertyLoadFailureView(isRetrying: true, onRetry: {}), inNavigation: false)
    }

    // MARK: First run

    func testFirstRunMoment() {
        assertScreen(FirstRunMomentPickerView(isPreparing: false, onSelect: { _ in }, onSignOut: {}), devices: all, inNavigation: false)
    }

    func testFirstRunMomentPreparing() {
        assertScreen(FirstRunMomentPickerView(isPreparing: true, onSelect: { _ in }, onSignOut: {}), inNavigation: false)
    }

    func testFirstRunSetup() {
        assertScreen(FirstRunPropertySetupView(previewMoveIn: Self.moveIn), devices: all, inNavigation: false)
    }

    func testFirstRunSetupFilled() {
        assertScreen(FirstRunPropertySetupView(previewStreet: "88 Harbour St", previewUnit: "1204",
                                               previewCity: "Toronto", previewProvince: "ON", previewMoveIn: Self.moveIn),
                     devices: all, inNavigation: false)
    }

    func testFirstRunSetupError() {
        assertScreen(FirstRunPropertySetupView(previewStreet: "88 Harbour St", previewCity: "Toronto",
                                               previewMoveIn: Self.moveIn, previewError: "No connection. Check your internet and try again."),
                     inNavigation: false)
    }

    func testLegalGate() {
        let screen = LegalAcceptanceScreen(termsURL: URL(string: "https://movemark.ca/terms"),
                                           privacyURL: URL(string: "https://movemark.ca/privacy"))
        assertScreen(screen, devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testFirstRunRoom() {
        assertScreen(FirstRunRoomPickerView(propertyId: UUID(), onStartProof: { _, _ in }, onBack: {}), devices: all, inNavigation: false)
    }

    func testFirstRunRoomError() {
        assertScreen(FirstRunRoomPickerView(propertyId: UUID(), previewSelection: .bathroom,
                                            previewError: "Couldn’t open your rental record. Try again."),
                     inNavigation: false)
    }

    func testFirstRunOtherRoomSheet() {
        assertScreen(FirstRunOtherRoomSheet(otherRoomName: .constant(""), onUse: {}), devices: all)
    }

    func testFirstRunOtherRoomSheetFilled() {
        assertScreen(FirstRunOtherRoomSheet(otherRoomName: .constant("Laundry"), onUse: {}))
    }
}
