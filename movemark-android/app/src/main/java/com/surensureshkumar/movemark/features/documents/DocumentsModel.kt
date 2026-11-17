package com.surensureshkumar.movemark.features.documents

import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * The records list as a model (iOS `PropertyVaultModel.records` + `PropertyVaultContent.recordsSection`):
 * every record slot in display order; the first [priorityCount] (lease, deposit receipt, listing proof) always
 * show, present or missing; the other records show once added, or while the list is expanded.
 */
data class DocumentsModel(
    val records: List<Record>,
    val priorityCount: Int = VaultDocumentKind.priority.size,
) {
    data class Record(
        val kind: VaultDocumentKind,
        val isPresent: Boolean,
        /** Present: when it was added ("Oct 19, 2025"), when known. */
        val addedOn: String? = null,
        /** Present: what the file is ("lease-2025.pdf", or "Image" for photos stored under generated names). */
        val file: String? = null,
    ) {
        /** "Added Oct 19, 2025" / "Added" / "Needed · Ties your proof to this rental" (iOS `MMRecordRow.statusLine`). */
        val statusLead: String get() = if (isPresent) "Added" else "Needed"
        val statusDetail: String? get() = if (isPresent) addedOn?.takeIf { it.isNotBlank() }?.let { " $it" } else " · ${kind.reason}"
        val statusLine: String get() = statusLead + statusDetail.orEmpty()
    }

    val priorityRecords: List<Record> get() = records.take(priorityCount)
    val otherRecords: List<Record> get() = records.drop(priorityCount)

    /** Priority records on file, of the priority count. */
    val addedCount: Int get() = priorityRecords.count { it.isPresent }

    /** "2 of 3 added". */
    val countLine: String get() = "$addedCount of ${priorityRecords.size} added"

    /** The three priority records always; other records when added, or when the list is expanded. */
    fun visibleRecords(showAll: Boolean): List<Record> =
        priorityRecords + otherRecords.filter { showAll || it.isPresent }

    /** Other records not on file: what the toggle row reveals. */
    val hiddenRecordCount: Int get() = otherRecords.count { !it.isPresent }

    /** "Other records" / "Fewer records" shows only when there is something to reveal. */
    val showsToggle: Boolean get() = hiddenRecordCount > 0

    /** The long-press hint shows once any record is on file. */
    val footer: String? get() = if (records.any { it.isPresent }) FOOTER else null

    companion object {
        const val FOOTER = "Touch and hold an added record to replace or delete it."
        const val TOGGLE_MORE = "Other records"
        const val TOGGLE_FEWER = "Fewer records"
        const val TOGGLE_DETAIL = "Receipts, invoices"

        /** iOS `PropertyVaultView.documentTypeOrder`: priority first, then the other kinds. */
        val order: List<VaultDocumentKind> = VaultDocumentKind.priority + (VaultDocumentKind.all - VaultDocumentKind.priority.toSet())

        fun from(
            rows: List<PropertyDocumentRow>,
            locale: Locale = Locale.getDefault(),
            zone: ZoneId = ZoneId.systemDefault(),
        ): DocumentsModel = DocumentsModel(
            records = order.map { kind ->
                val row = rows.firstOrNull { it.documentType in kind.queryKeys() }
                Record(
                    kind = kind,
                    isPresent = row != null,
                    addedOn = row?.uploadedAt?.let { recordDate(it, locale, zone) },
                    file = row?.let { fileLabel(kind, it.fileName) },
                )
            },
        )

        /** Photos are stored under generated names, so they read as "Image"; a blank name reads "PDF". */
        fun fileLabel(kind: VaultDocumentKind, fileName: String): String =
            if (kind.acceptsImage) "Image" else fileName.trim().ifEmpty { "PDF" }

        /** Stored ISO timestamp (or date-only) as "Oct 19, 2025" (iOS `MMRecordDate`); null when unreadable. */
        fun recordDate(raw: String, locale: Locale = Locale.getDefault(), zone: ZoneId = ZoneId.systemDefault()): String? {
            val trimmed = raw.trim()
            if (trimmed.isEmpty()) return null
            val date = runCatching { OffsetDateTime.parse(trimmed).atZoneSameInstant(zone).toLocalDate() }.getOrNull()
                ?: runCatching { LocalDate.parse(trimmed.take(10)) }.getOrNull()
                ?: return null
            return date.format(DateTimeFormatter.ofPattern("MMM d, yyyy", locale))
        }
    }
}
