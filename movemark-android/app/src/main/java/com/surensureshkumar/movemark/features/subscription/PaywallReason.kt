package com.surensureshkumar.movemark.features.subscription

enum class PaywallReason {
    ExtraProperty,
    UnlimitedExports,
    DisputePacket,
    MoveOutExport,
    MoveOutProof,
    MoveOutReport,
    /** Opened from Account: nothing was blocked (iOS `.account`). */
    Account,
    ;

    /** Why this paywall opened, stated as a fact (iOS `contextLine`); null when nothing was blocked. */
    val contextLine: String?
        get() = when (this) {
            ExtraProperty -> "Free includes one rental. Pro adds more."
            UnlimitedExports -> "You’ve used your free move-in report."
            DisputePacket -> "The evidence packet is part of Pro."
            MoveOutExport, MoveOutProof, MoveOutReport -> "The move-out report is part of Pro."
            Account -> null
        }

    val headline: String
        get() = when (this) {
            ExtraProperty -> "Protect more than one rental."
            UnlimitedExports -> "Turn proof into more reports."
            DisputePacket -> "Build a dispute-ready packet."
            MoveOutExport -> "Document move-out proof."
            MoveOutProof -> "Document move-out proof."
            MoveOutReport -> "Document move-out proof."
            Account -> "Protect the full rental timeline."
        }

    val subheadline: String
        get() = when (this) {
            ExtraProperty -> "Free includes 1 proof vault."
            UnlimitedExports -> "You've used your free move-in report on this account."
            DisputePacket -> "Organize photos and docs when your deposit is questioned."
            MoveOutExport -> "Re-capture rooms and export move-out reports with Pro."
            MoveOutProof -> "Re-capture each room before you return the keys."
            MoveOutReport -> "Make and share a move-out PDF from saved room proof."
            Account -> "Keep the record from move-in through move-out."
        }

    val valueProp: String
        get() = com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy.PAYWALL_VALUE_LINE
}
