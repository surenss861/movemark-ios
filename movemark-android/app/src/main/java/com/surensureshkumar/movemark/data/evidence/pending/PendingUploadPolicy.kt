/**
 * @file Which photos on this phone the app may upload by itself, and when the background retry stops. Only photos the
 *       renter asked to save (a save that couldn't finish: offline, killed mid-upload) are sent automatically; photos
 *       only taken, or moved to a new entry that needs its own Save, wait for the renter.
 * @domain evidence
 * @status wip
 * @see [[PendingUploadWorker.kt]]
 * @tested-by [[PendingUploadPolicyTest.kt]]
 */
package com.surensureshkumar.movemark.data.evidence.pending

object PendingUploadPolicy {
    /** Background attempts before the retry stops; the photos stay on this phone with "Retry upload" in the room. */
    const val MAX_ATTEMPTS = 10

    fun awaitingUpload(manifest: PendingEvidenceManifest): Boolean {
        if (manifest.items.isEmpty()) return false
        // Manifests from before saveRequested: a save had chosen the entry and touched the photos.
        return manifest.saveRequested
            ?: (manifest.entryId != null && manifest.items.any { it.status != PendingEvidenceItem.Status.Pending })
    }

    enum class Outcome { Done, Retry, GiveUp }

    /** [remaining]: photos still awaiting upload after this run; [attempt]: WorkManager's runAttemptCount (from 0). */
    fun outcome(remaining: Int, attempt: Int): Outcome = when {
        remaining == 0 -> Outcome.Done
        attempt + 1 >= MAX_ATTEMPTS -> Outcome.GiveUp
        else -> Outcome.Retry
    }
}
