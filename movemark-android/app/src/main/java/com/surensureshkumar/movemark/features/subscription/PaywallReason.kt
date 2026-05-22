package com.surensureshkumar.movemark.features.subscription

enum class PaywallReason {
    ExtraProperty,
    UnlimitedExports,
    DisputePacket,
    MoveOutExport,
    ;

    val headline: String
        get() = when (this) {
            ExtraProperty -> "Protect more than one rental."
            UnlimitedExports -> "Make more move-in reports."
            DisputePacket -> "Build a dispute-ready packet."
            MoveOutExport -> "Document move-out proof."
        }

    val subheadline: String
        get() = when (this) {
            ExtraProperty -> "Free includes 1 proof vault."
            UnlimitedExports -> "You've used your free move-in report on this account."
            DisputePacket -> "Organize proof into a stronger dispute workflow."
            MoveOutExport -> "Re-capture rooms and export move-out reports with Pro."
        }

    val valueProp: String
        get() = "Unlock unlimited proof vaults, reports, move-out proof, and dispute tools."
}
