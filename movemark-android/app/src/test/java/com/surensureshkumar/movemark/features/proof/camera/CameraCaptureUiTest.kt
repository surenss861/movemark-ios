package com.surensureshkumar.movemark.features.proof.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS `EvidenceCameraViewController` presentation rules (strings, timing, Cancel vs thumbnail, suggestion). */
class CameraCaptureUiTest {
    @Test fun noticeStringsAndTimingMatchIos() {
        assertEquals("Photo added", CameraCaptureUi.PHOTO_ADDED)
        assertEquals("Couldn’t keep that photo. Try again.", CameraCaptureUi.PHOTO_FAILED)
        assertEquals("Camera unavailable", CameraCaptureUi.CAMERA_UNAVAILABLE)
        assertEquals(1_100L, CameraCaptureUi.NOTICE_HOLD_MILLIS)
        assertEquals(300, CameraCaptureUi.NOTICE_FADE_MILLIS)
    }

    @Test fun everyNoticeGetsANewSerialSoRepeatsReplay() {
        val first = CameraCaptureUi.nextNotice(null, CameraCaptureUi.PHOTO_ADDED)
        val second = CameraCaptureUi.nextNotice(first, CameraCaptureUi.PHOTO_ADDED)
        assertEquals(CameraCaptureUi.PHOTO_ADDED, second.message)
        assertNotEquals(first, second)
        assertEquals(first.serial + 1, second.serial)
        val failed = CameraCaptureUi.nextNotice(second, CameraCaptureUi.PHOTO_FAILED)
        assertEquals(CameraCaptureUi.PHOTO_FAILED, failed.message)
        assertEquals(second.serial + 1, failed.serial)
    }

    @Test fun cancelUntilAPhotoThenTheThumbnail() {
        assertTrue(CameraCaptureUi.showsCancel(0))
        assertFalse(CameraCaptureUi.showsCancel(1))
        assertFalse(CameraCaptureUi.showsCancel(5))
    }

    @Test fun thumbnailIsTheLatestPhoto() {
        assertNull(CameraCaptureUi.latestThumbnail(emptyList<String>()))
        assertEquals("c", CameraCaptureUi.latestThumbnail(listOf("a", "b", "c")))
    }

    @Test fun suggestionWalksThePromptsThenCloses() {
        val prompts = listOf("A wide shot from the doorway", "Floors")
        assertEquals("Next: A wide shot from the doorway", CameraCaptureUi.suggestion(0, prompts))
        assertEquals("Next: Floors", CameraCaptureUi.suggestion(1, prompts))
        assertEquals("Anything else worth recording", CameraCaptureUi.suggestion(2, prompts))
        assertEquals("Anything else worth recording", CameraCaptureUi.suggestion(0, emptyList()))
    }
}
