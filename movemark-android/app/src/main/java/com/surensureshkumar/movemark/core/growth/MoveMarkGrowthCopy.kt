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

    const val PAYWALL_VALUE_LINE =
        "Turn move-in and move-out proof into reports — unlimited vaults, move-out capture, and dispute tools."

    val PAYWALL_BENEFITS = listOf(
        "Unlimited proof vaults" to "Protect more than one rental over time.",
        "Move-in & move-out reports" to "PDF proof when your deposit is questioned.",
        "Move-out room re-capture" to "Before-and-after record when you return keys.",
        "Dispute-ready packet" to "Organize photos and docs for a stronger case.",
    )
}
