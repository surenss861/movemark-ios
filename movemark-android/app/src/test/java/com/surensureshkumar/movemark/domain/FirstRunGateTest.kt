package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.models.StageTotals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class FirstRunGateTest {
    private fun property(kitchenPhotos: Int) = PropertyRecord(
        id = UUID.randomUUID(), title = "My Apartment", addressLine1 = "", city = "", provinceState = "",
        rooms = listOf(
            RoomRecord(
                id = UUID.randomUUID(), name = "Kitchen",
                moveInUnloaded = if (kitchenPhotos > 0) StageTotals(entries = 1, photos = kitchenPhotos) else null,
            ),
            RoomRecord(id = UUID.randomUUID(), name = "Living Room"),
        ),
    )

    @Test
    fun existingVaultWithProofSkipsFirstRunOnANewDevice() {
        // Device QA: an account with a documented Kitchen signed in on a fresh phone and got "Start with one room".
        assertTrue(RoomProofMetrics.isFirstRunComplete(localFlag = false, property = property(kitchenPhotos = 1)))
    }

    @Test
    fun emptyVaultStillGetsFirstRun() {
        assertFalse(RoomProofMetrics.isFirstRunComplete(localFlag = false, property = property(kitchenPhotos = 0)))
        assertFalse(RoomProofMetrics.isFirstRunComplete(localFlag = false, property = null))
    }

    @Test
    fun localFlagAlwaysWins() {
        assertTrue(RoomProofMetrics.isFirstRunComplete(localFlag = true, property = property(kitchenPhotos = 0)))
    }
}
