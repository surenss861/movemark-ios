package com.surensureshkumar.movemark.features.firstrun

import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.UUID

/** iOS 1.4 first run: RentalMoment, FirstRunProofFlowView steps, FirstRunPropertySetupView, FirstRunRoomPickerView. */
class FirstRunFlowTest {

    // --- Moment (RentalMoment.swift, MoveMarkGrowthCopy.swift) ---

    @Test
    fun momentCopyMatchesIosWordForWord() {
        assertEquals("What are you documenting?", MoveMarkGrowthCopy.FIRST_RUN_MOMENT_TITLE)
        assertEquals("We’ll start you in the right proof flow.", MoveMarkGrowthCopy.FIRST_RUN_MOMENT_SUBTITLE)
        assertEquals(listOf(RentalMoment.JustMovedIn, RentalMoment.MovingOut), RentalMoment.entries.toList())
        assertEquals("Moving into a rental", RentalMoment.JustMovedIn.title)
        assertEquals("Record how it looks before you unpack.", RentalMoment.JustMovedIn.blurb)
        assertEquals("Moving out", RentalMoment.MovingOut.title)
        assertEquals("Compare how you’re leaving it.", RentalMoment.MovingOut.blurb)
    }

    @Test
    fun movingOutCapturesMoveOutEvidenceAndMovingInCapturesMoveIn() {
        assertEquals(ProofPhase.MoveIn, RentalMoment.JustMovedIn.proofPhase)
        assertFalse(RentalMoment.JustMovedIn.capturesMoveOutEvidence)
        assertEquals(ProofPhase.MoveOut, RentalMoment.MovingOut.proofPhase)
        assertTrue(RentalMoment.MovingOut.capturesMoveOutEvidence)
    }

    // --- Steps (FirstRunProofFlowView.advanceAfterMomentSelected / room pick onBack) ---

    @Test
    fun momentGoesToSetupForANewAccountAndStraightToTheRoomPickWithARental() {
        assertEquals(FirstRunStep.Setup, FirstRunFlow.stepAfterMoment(hasRental = false))
        assertEquals(FirstRunStep.PickRoom, FirstRunFlow.stepAfterMoment(hasRental = true))
    }

    @Test
    fun backFromTheRoomPickNeverReturnsToSetupOnceARentalExists() {
        assertEquals(FirstRunStep.Moment, FirstRunFlow.backFromRoomPick(hasRental = true))
        assertEquals(FirstRunStep.Setup, FirstRunFlow.backFromRoomPick(hasRental = false))
    }

    // --- Rental setup (FirstRunPropertySetupView.title / createRental) ---

    @Test
    fun titleIsTheStreetThenTheUnit() {
        assertEquals("88 Harbour St", FirstRunRentalSetup.title("  88 Harbour St ", ""))
        assertEquals("88 Harbour St", FirstRunRentalSetup.title("88 Harbour St", "   "))
        assertEquals("88 Harbour St, Unit 1204", FirstRunRentalSetup.title("88 Harbour St", "1204"))
    }

    @Test
    fun aUnitThatNamesItsKindIsKeptAsTyped() {
        assertEquals("88 Harbour St, Unit 1204", FirstRunRentalSetup.title("88 Harbour St", "Unit 1204"))
        assertEquals("88 Harbour St, Apt 3", FirstRunRentalSetup.title("88 Harbour St", "Apt 3"))
        assertEquals("88 Harbour St, Suite 200", FirstRunRentalSetup.title("88 Harbour St", "Suite 200"))
        assertEquals("88 Harbour St, #12", FirstRunRentalSetup.title("88 Harbour St", "#12"))
        assertEquals("88 Harbour St, apt 3", FirstRunRentalSetup.title("88 Harbour St", "apt 3"))
    }

    @Test
    fun setupMapsUnitToAddressLine2AndLeavesTheLeaseUnset() {
        val moveIn = LocalDate.of(2026, 11, 1)
        val input = FirstRunRentalSetup.input(" 88 Harbour St ", " 1204 ", " Toronto ", " ON ", moveIn)
        assertEquals("88 Harbour St, Unit 1204", input.title)
        assertEquals("88 Harbour St, Unit 1204", input.titleValue)
        assertEquals("88 Harbour St", input.addressLine1)
        // PropertyRepository.createProperty writes `unit` as address_line_2 (blank -> null).
        assertEquals("1204", input.unit)
        assertEquals("Toronto", input.city)
        assertEquals("ON", input.region)
        assertEquals("", input.postalCode)
        assertEquals("CA", input.country)
        assertEquals(moveIn, input.moveInDate)
        assertNull(input.leaseStart)
        assertNull(input.leaseEnd)
    }

    @Test
    fun setupWithoutAUnitIsTitledByTheStreetAlone() {
        val input = FirstRunRentalSetup.input("88 Harbour St", "", "", "", LocalDate.of(2026, 11, 1))
        assertEquals("88 Harbour St", input.title)
        assertEquals("", input.unit)
    }

    // --- Room pick (FirstRunRoomPickerView) ---

    @Test
    fun sixOptionsWithOtherLast() {
        assertEquals(
            listOf("Kitchen", "Living room", "Primary bedroom", "Bathroom", "Hallway", "Other"),
            FirstRunRoomOption.entries.map { it.label },
        )
        assertNull(FirstRunRoomOption.Other.defaultRoomName)
        assertEquals(listOf("Office", "Balcony", "Laundry", "Storage"), FirstRunRoomChoice.OTHER_ROOM_SUGGESTIONS)
    }

    @Test
    fun otherWithoutANameOpensTheSheetInsteadOfStarting() {
        assertTrue(FirstRunRoomChoice.needsOtherSheet(FirstRunRoomOption.Other, ""))
        assertTrue(FirstRunRoomChoice.needsOtherSheet(FirstRunRoomOption.Other, "   "))
        assertFalse(FirstRunRoomChoice.needsOtherSheet(FirstRunRoomOption.Other, "Office"))
        assertFalse(FirstRunRoomChoice.needsOtherSheet(FirstRunRoomOption.Kitchen, ""))
        assertNull(FirstRunRoomChoice.targetName(FirstRunRoomOption.Other, " "))
    }

    @Test
    fun targetNameIsTheSeededRoomOrTheTypedOne() {
        assertEquals("Living Room", FirstRunRoomChoice.targetName(FirstRunRoomOption.LivingRoom, "ignored"))
        assertEquals("Primary Bedroom", FirstRunRoomChoice.targetName(FirstRunRoomOption.Bedroom, ""))
        assertEquals("Wine cellar", FirstRunRoomChoice.targetName(FirstRunRoomOption.Other, "  Wine cellar "))
    }

    @Test
    fun anExistingRoomIsReusedCaseInsensitivelySoNoDuplicateIsAdded() {
        val office = RoomRecord(id = UUID.randomUUID(), name = "Office")
        val kitchen = RoomRecord(id = UUID.randomUUID(), name = "Kitchen")
        assertEquals(office, FirstRunRoomChoice.existing(listOf(kitchen, office), "office"))
        assertEquals(kitchen, FirstRunRoomChoice.existing(listOf(kitchen, office), " KITCHEN "))
        assertNull(FirstRunRoomChoice.existing(listOf(kitchen, office), "Balcony"))
    }

    @Test
    fun suggestionChipShowsSelectedWhileTheFieldHoldsItsName() {
        assertTrue(FirstRunRoomChoice.isSuggestionSelected("office ", "Office"))
        assertFalse(FirstRunRoomChoice.isSuggestionSelected("Office 2", "Office"))
    }
}
