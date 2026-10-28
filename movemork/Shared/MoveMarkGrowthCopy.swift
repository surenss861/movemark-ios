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
    /// Set as two lines on Welcome — the break is editorial, not a consequence of device width.
    /// `welcomeHeadline` stays the spoken form for VoiceOver.
    static let welcomeHeadlineLead = "Prove what was"
    static let welcomeHeadlineTail = "already there."
    static let welcomeBody = "Photograph your rental before you unpack. MoveMark keeps the photos, dates and records together so you can show how the place looked when you arrived."
    static let welcomeSecondaryCTA = "I already have a vault"
    static let welcomeTrustLine = "Private evidence"
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

    static let firstRunMomentTitle = "What are you documenting?"
    static let firstRunMomentSubtitle = "We’ll start you in the right proof flow."

    static let firstRunSetupTitle = "Where are you documenting?"
    static let firstRunSetupSubtitle = "This address appears on your proof record and reports."
    static let firstRunSetupCTA = "Create rental record"

    static let firstRunRoomTitle = "Start with the first room"
    static let firstRunRoomSubtitle = "Photograph each room before boxes and furniture cover anything."

    /// Pro is sold by its outcome; the benefits list underneath is evidence for it.
    static let proOutcomeLine = "Keep a complete rental record from move-in to move-out."
    static let paywallValueLine = proOutcomeLine
    static let paywallSupportLine = "MoveMark Pro keeps your proof organized across the full rental lifecycle."
    static let proActiveSummary = "Complete rental record, move-in to move-out."

    static let moveInRecordReady = "Your move-in record is ready."
    static let moveInRecordReadyDetail = "A dated record of the condition you documented at move-in."
    static let moveOutRecordReady = "Your move-out record is ready."
    static let moveOutRecordReadyDetail = "A dated record of the condition you documented before returning the keys."
    static let disputePacketReady = "Your evidence packet is ready."
    static let disputePacketReadyDetail = "Your saved rental evidence organized into one shareable record."

    static let paywallBenefits: [(title: String, subtitle: String)] = [
        ("Unlimited proof vaults", "Protect more than one rental over time."),
        ("Move-in & move-out reports", "PDF proof when your deposit is questioned."),
        ("Move-out comparison report", "Move-in and move-out proof side by side, dated."),
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
