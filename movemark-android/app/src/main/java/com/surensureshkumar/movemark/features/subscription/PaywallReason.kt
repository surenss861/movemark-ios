package com.surensureshkumar.movemark.features.subscription

enum class PaywallReason {
    ExtraProperty,
    UnlimitedExports,
    DisputePacket,
    MoveOutExport,
    MoveOutProof,
    MoveOutReport,
    ;

    val headline: String
        get() = when (this) {
            ExtraProperty -> "Protect more than one rental."
            UnlimitedExports -> "Make more move-in reports."
            DisputePacket -> "Dispute tools need Pro."
            MoveOutExport -> "Document move-out proof."
            MoveOutProof -> "Move-out proof needs Pro."
            MoveOutReport -> "Move-out reports need Pro."
        }

    val subheadline: String
        get() = when (this) {
            ExtraProperty -> "Free includes 1 proof vault."
            UnlimitedExports -> "You've used your free move-in report on this account."
            DisputePacket -> "Organize proof into a stronger dispute workflow."
            MoveOutExport -> "Re-capture rooms and export move-out reports with Pro."
            MoveOutProof -> "Re-capture each room before you return the keys."
            MoveOutReport -> "Make and share a move-out PDF from saved room proof."
        }

    val valueProp: String
        get() = "Unlock unlimited proof vaults, reports, move-out proof, and dispute tools."
}
