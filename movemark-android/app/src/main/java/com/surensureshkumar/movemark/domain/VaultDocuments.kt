package com.surensureshkumar.movemark.domain

/**
 * Supporting records. Raw values match `property_documents.document_type`, including the
 * hyphenated spellings older builds wrote.
 */
enum class VaultDocumentKind(
    val raw: String,
    val title: String,
    val missingSubtitle: String,
    val presentSubtitle: String,
    val acceptsImage: Boolean,
) {
    Lease("lease", "lease", "Tenancy agreement", "Tenancy agreement attached", false),
    DepositReceipt("deposit_receipt", "Deposit receipt", "Payment proof", "Payment proof attached", false),
    ListingScreenshot("listing_screenshot", "Listing proof", "Original listing", "Original listing attached", true),
    CleaningReceipt("cleaning_receipt", "Cleaning receipt", "Cleaning proof", "Cleaning proof attached", false),
    UtilityProof("utility_record", "Utility proof", "Utility record", "Utility record attached", false),
    MoveOutInvoice("move_out_invoice", "Move-out invoice", "Move-out cost", "Move-out cost attached", false),
    Other("other", "Other", "Additional proof", "Additional proof attached", false),
    ;

    fun queryKeys(): Set<String> = when (this) {
        DepositReceipt -> setOf(raw, "deposit-receipt")
        ListingScreenshot -> setOf(raw, "listing-screenshot")
        else -> setOf(raw)
    }

    fun storageBucket(): String = when (this) {
        Lease -> "leases"
        DepositReceipt -> "deposit-receipts"
        ListingScreenshot -> "listing-screenshots"
        else -> "documents"
    }

    companion object {
        val priority = listOf(Lease, DepositReceipt, ListingScreenshot)
        val all = entries
        private val required = priority

        fun isPresent(kind: VaultDocumentKind, types: Collection<String>): Boolean =
            kind.queryKeys().any { it in types }

        fun supportingRecordCount(types: Collection<String>): Int =
            required.count { isPresent(it, types) }

        fun leaseAndDepositCount(types: Collection<String>): Int =
            listOf(Lease, DepositReceipt).count { isPresent(it, types) }
    }
}
