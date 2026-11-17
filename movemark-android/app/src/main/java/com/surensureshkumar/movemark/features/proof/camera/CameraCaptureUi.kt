package com.surensureshkumar.movemark.features.proof.camera

/**
 * A transient line over the camera preview (iOS `EvidenceCameraViewController.flash(message:)`): "Photo added"
 * after a kept shot, or the failure. [serial] changes on every shot, so the same message shown twice still
 * replays (two successful shots in a row each flash).
 */
data class CameraNotice(val message: String, val serial: Long)

/** Presentation-only rules for the camera screen, kept pure so they can be unit-tested without CameraX. */
object CameraCaptureUi {
    const val PHOTO_ADDED = "Photo added"
    const val PHOTO_FAILED = "Couldn’t keep that photo. Try again."
    const val CAMERA_UNAVAILABLE = "Camera unavailable"
    const val ANYTHING_ELSE = "Anything else worth recording"

    /** iOS: the capsule stays fully visible for 1.1 s, then fades out over 0.3 s. */
    const val NOTICE_HOLD_MILLIS = 1_100L
    const val NOTICE_FADE_MILLIS = 300

    /** The next notice after [previous]; always a new serial so it replays. */
    fun nextNotice(previous: CameraNotice?, message: String): CameraNotice =
        CameraNotice(message, (previous?.serial ?: 0L) + 1L)

    /** iOS `refreshProgress`: "Next: {prompt}" while prompts remain, then a closing line. */
    fun suggestion(count: Int, prompts: List<String>): String =
        if (count in prompts.indices) "Next: ${prompts[count]}" else ANYTHING_ELSE

    /** iOS: Cancel beside the shutter until a photo is taken, then the latest-photo thumbnail instead. */
    fun showsCancel(photoCount: Int): Boolean = photoCount <= 0

    /** The single thumbnail beside the shutter: the most recent photo (replaces the old filmstrip). */
    fun <T> latestThumbnail(photos: List<T>): T? = photos.lastOrNull()
}
