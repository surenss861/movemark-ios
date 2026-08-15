//
//  MoveMarkGrowthCopy.swift
//  movemork
//
//  Positioning, onboarding psychology, paywall, and retention messaging.
//

import Foundation

enum MoveMarkGrowthCopy {
    /// Initial market focus — sharp enough for ads and App Store, broad enough to expand later.
    static let audienceChip = "For Ontario apartment renters"

    static let coreTagline = "Document now. Prove it later."
    static let welcomeHeadline = "Prove what was already there."
    static let welcomeBody = "Document move-in condition before you unpack. Turn photos into a shareable report when you need proof."
    static let welcomePainLine = "Don’t get blamed for damage you didn’t cause."
    static let welcomeCTA = "Start move-in proof"

    struct OnboardingStory {
        let title: String
        let body: String
    }

    /// Pain → proof → report → action (pre-auth education).
    static let onboardingStorySteps: [OnboardingStory] = [
        OnboardingStory(
            title: "Landlords can blame you for damage that was already there.",
            body: "Scratches, stains, and wear from past tenants often show up on move-out inspections."
        ),
        OnboardingStory(
            title: "Take room photos before boxes cover everything.",
            body: "Five minutes now beats arguing about a $900 wall charge later."
        ),
        OnboardingStory(
            title: "MoveMark turns photos into a timestamped report.",
            body: "Room-by-room proof you can share if your deposit is questioned."
        ),
        OnboardingStory(
            title: "Start with Kitchen.",
            body: "Document your first room before you settle in — then finish the rest."
        ),
    ]

    static let firstRunMomentTitle = "What are you documenting today?"
    static let firstRunMomentSubtitle = "MoveMark will guide you based on what’s happening with your rental."
    static let firstRunMomentFootnote = "Takes about 5 minutes for your first room."

    static let firstRunSetupTitle = "Protect this rental."
    static let firstRunSetupSubtitle = "Add your apartment, then document each room before you unpack."

    static let firstRunRoomTitle = "Start with one room."
    static let firstRunRoomSubtitle = "Kitchen works well — save what was already there."

    static let paywallValueLine =
        "Turn rental photos, notes, and receipts into shareable proof — before deposits get questioned."

    static let paywallBenefits: [(title: String, subtitle: String)] = [
        ("Unlimited proof vaults", "Protect more than one rental over time."),
        ("Move-in & move-out reports", "PDF proof when your deposit is questioned."),
        ("Move-out room re-capture", "Before-and-after record when you return keys."),
        ("Dispute-ready packet", "Organize photos and docs for a stronger case."),
    ]

    static let reportPackBenefits: [(title: String, subtitle: String)] = [
        ("One polished move-in report", "Export a timestamped PDF when you need it."),
        ("Shareable proof", "Send records to a landlord, parent, or roommate."),
        ("No subscription required", "Pay once for a single rental moment."),
    ]

    static let freeTierSummary = "Free: 1 proof vault · 1 move-in report"
    static let proPricingQuestion = "Would you pay $4.99–$9.99 to protect a $1,500–$3,000 deposit?"
}
