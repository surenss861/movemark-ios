package com.surensureshkumar.movemark.features.documents

import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneOffset
import java.util.Locale

class DocumentsModelTest {
    private fun row(type: String, name: String = "file.pdf", at: String? = "2025-10-19T14:00:00Z") =
        PropertyDocumentRow(id = type, propertyId = "p", userId = "u", documentType = type, filePath = "u/$name", fileName = name, uploadedAt = at)

    private fun model(vararg rows: PropertyDocumentRow) =
        DocumentsModel.from(rows.toList(), Locale.US, ZoneOffset.UTC)

    @Test
    fun countsOnlyThePriorityRecordsOfThree() {
        assertEquals("0 of 3 added", model().countLine)
        // Other records don't count toward "of 3".
        assertEquals("0 of 3 added", model(row("cleaning_receipt"), row("other")).countLine)
        assertEquals("2 of 3 added", model(row("lease"), row("deposit-receipt")).countLine)
        assertEquals("3 of 3 added", model(row("lease"), row("deposit_receipt"), row("listing_screenshot")).countLine)
    }

    @Test
    fun theThreePriorityRecordsAlwaysShowPresentOrMissing() {
        val empty = model().visibleRecords(showAll = false)
        assertEquals(VaultDocumentKind.priority, empty.map { it.kind })
        assertTrue(empty.none { it.isPresent })

        val full = model(row("lease"), row("deposit_receipt"), row("listing_screenshot")).visibleRecords(showAll = false)
        assertEquals(VaultDocumentKind.priority, full.map { it.kind })
        assertTrue(full.all { it.isPresent })
    }

    @Test
    fun addedOtherRecordsShowWithoutExpanding() {
        val m = model(row("lease"), row("utility_record"))
        assertEquals(
            listOf(VaultDocumentKind.Lease, VaultDocumentKind.DepositReceipt, VaultDocumentKind.ListingScreenshot, VaultDocumentKind.UtilityProof),
            m.visibleRecords(showAll = false).map { it.kind },
        )
        assertEquals(DocumentsModel.order, m.visibleRecords(showAll = true).map { it.kind })
    }

    @Test
    fun toggleShowsOnlyWhenSomethingIsHidden() {
        assertTrue(model().showsToggle)
        assertEquals(4, model().hiddenRecordCount)
        val allOthers = model(row("cleaning_receipt"), row("utility_record"), row("move_out_invoice"), row("other"))
        assertFalse(allOthers.showsToggle)
        assertEquals(0, allOthers.hiddenRecordCount)
    }

    @Test
    fun footerShowsOnceAnyRecordIsOnFile() {
        assertNull(model().footer)
        assertEquals("Touch and hold an added record to replace or delete it.", model(row("other")).footer)
    }

    @Test
    fun rowStatusFileAndReason() {
        val m = model(row("lease", name = "Harbour-lease.pdf"), row("listing_screenshot", name = "abc123.jpg"))
        val lease = m.records.first { it.kind == VaultDocumentKind.Lease }
        assertEquals("Added Oct 19, 2025", lease.statusLine)
        assertEquals("Harbour-lease.pdf", lease.file)
        // Photos are stored under generated names.
        assertEquals("Image", m.records.first { it.kind == VaultDocumentKind.ListingScreenshot }.file)
        val deposit = m.records.first { it.kind == VaultDocumentKind.DepositReceipt }
        assertEquals("Needed · Shows what you paid, and when", deposit.statusLine)
        assertNull(deposit.file)
        assertEquals("Needed · Ties your proof to this rental", model().records.first().statusLine)
    }

    @Test
    fun datesReadAsStoredAndBlankNamesReadPdf() {
        assertEquals("Oct 19, 2025", DocumentsModel.recordDate("2025-10-19", Locale.US, ZoneOffset.UTC))
        assertEquals("Oct 19, 2025", DocumentsModel.recordDate("2025-10-19 08:00:00+00", Locale.US, ZoneOffset.UTC))
        assertNull(DocumentsModel.recordDate("soon", Locale.US, ZoneOffset.UTC))
        assertEquals("Added", model(row("lease", at = null)).records.first().statusLine)
        assertEquals("PDF", DocumentsModel.fileLabel(VaultDocumentKind.Lease, "  "))
    }
}
