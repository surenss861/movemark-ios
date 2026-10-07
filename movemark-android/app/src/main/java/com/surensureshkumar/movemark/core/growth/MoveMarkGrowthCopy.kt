package com.surensureshkumar.movemark.core.growth

object MoveMarkGrowthCopy {
    const val AUDIENCE_CHIP = "For Ontario apartment renters"

    const val WELCOME_HEADLINE = "Prove what was already there."
    const val WELCOME_BODY =
        "Take room photos before you unpack. Turn them into a report when you need it."
    const val WELCOME_PAIN_LINE =
        "Old damage can cost you your deposit — unless you have proof."
    const val WELCOME_CTA = "Start move-in proof"

    data class OnboardingStory(val title: String, val body: String)

    val ONBOARDING_STORY_STEPS = listOf(
        OnboardingStory(
            "Landlords can blame you for damage that was already there.",
            "Scratches, stains, and wear from past tenants often show up on move-out inspections.",
        ),
        OnboardingStory(
            "Take room photos before boxes cover everything.",
            "Five minutes now beats arguing about a $900 wall charge later.",
        ),
        OnboardingStory(
            "MoveMark turns photos into a timestamped report.",
            "Room-by-room proof you can share if your deposit is questioned.",
        ),
        OnboardingStory(
            "Start with Kitchen.",
            "Document your first room before you settle in — then finish the rest.",
        ),
    )

    const val FIRST_RUN_SETUP_TITLE = "Protect this rental."
    const val FIRST_RUN_SETUP_SUBTITLE =
        "Add your apartment, then document each room before you unpack."

    const val FIRST_RUN_ROOM_TITLE = "Start with one room."
    const val FIRST_RUN_ROOM_SUBTITLE = "Kitchen works well — save what was already there."

    // Pro is sold by its outcome; the benefits list underneath is evidence for it.
    const val PRO_OUTCOME_LINE = "Keep a complete rental record from move-in to move-out."
    const val PAYWALL_VALUE_LINE = PRO_OUTCOME_LINE
    const val PAYWALL_SUPPORT_LINE = "MoveMark Pro keeps your proof organized across the full rental lifecycle."
    const val PRO_ACTIVE_SUMMARY = "Complete rental record, move-in to move-out."

    const val MOVE_IN_RECORD_READY = "Your move-in record is ready."
    const val MOVE_IN_RECORD_READY_DETAIL = "A dated record of the condition you documented at move-in."
    const val MOVE_OUT_RECORD_READY = "Your move-out record is ready."
    const val MOVE_OUT_RECORD_READY_DETAIL = "A dated record of the condition you documented before returning the keys."
    const val DISPUTE_PACKET_READY = "Your evidence packet is ready."
    const val DISPUTE_PACKET_READY_DETAIL = "Your saved rental evidence organized into one shareable record."

    val PAYWALL_BENEFITS = listOf(
        "Unlimited proof vaults" to "Protect more than one rental over time.",
        "Move-in & move-out reports" to "PDF proof when your deposit is questioned.",
        "Move-out room re-capture" to "Before-and-after record when you return keys.",
        "Dispute-ready packet" to "Organize photos and docs for a stronger case.",
    )
}
