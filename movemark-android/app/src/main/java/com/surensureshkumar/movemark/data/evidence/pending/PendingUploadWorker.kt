/**
 * @file Finishes, in the background, the uploads a save couldn't complete (offline, or the app stopped mid-upload).
 *       One unique WorkManager job per account: runs only with a network, backs off exponentially, survives process
 *       death and reboot (WorkManager persists it), and is sent at most once per photo by PendingEvidenceSync's
 *       idempotency (client row ids, recorded tickets, abandon-before-retry) plus the center's sync lock.
 * @domain evidence
 * @status wip
 * @see [[PendingUploadPolicy.kt]]
 * @see [[PendingEvidenceCenter.kt]]
 * @tested-by [[PendingUploadWorkerTest.kt]]
 */
package com.surensureshkumar.movemark.data.evidence.pending

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.data.auth.SessionManager
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.TimeUnit

/** What one background run decided (mapped to WorkManager's Result by the worker). */
enum class PendingUploadRunResult { Success, Retry }

object PendingUploadRun {
    const val SESSION_RESTORE_TIMEOUT_MS = 15_000L

    /**
     * [awaitAuth] waits for the stored session to restore (null if it didn't in time); [currentUser] is then the
     * signed-in account. Photos are sent only for the account the job was scheduled for, and only while it is the
     * one signed in: a signed-out phone sends nothing (sign-out also cancels the job and clears the photos).
     */
    suspend fun run(
        requestedUser: String?,
        attempt: Int,
        awaitAuth: suspend () -> AuthState?,
        currentUser: () -> String?,
        send: suspend (String) -> PendingUploadReport,
    ): PendingUploadRunResult {
        val user = requestedUser?.lowercase() ?: return PendingUploadRunResult.Success
        val auth = awaitAuth() ?: return retryOrStop(attempt)
        if (auth != AuthState.SignedIn || currentUser()?.lowercase() != user) return PendingUploadRunResult.Success
        val report = try {
            send(user)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "background upload pass failed: ${e.javaClass.simpleName}")
            return retryOrStop(attempt)
        }
        return when (PendingUploadPolicy.outcome(report.remaining, attempt)) {
            PendingUploadPolicy.Outcome.Done, PendingUploadPolicy.Outcome.GiveUp -> PendingUploadRunResult.Success
            PendingUploadPolicy.Outcome.Retry -> PendingUploadRunResult.Retry
        }
    }

    private fun retryOrStop(attempt: Int) =
        if (attempt + 1 >= PendingUploadPolicy.MAX_ATTEMPTS) PendingUploadRunResult.Success else PendingUploadRunResult.Retry

    private const val TAG = "PendingUpload"
}

@EntryPoint
@InstallIn(SingletonComponent::class)
interface PendingUploadEntryPoint {
    fun sessionManager(): SessionManager
    fun pendingEvidenceCenter(): PendingEvidenceCenter
}

class PendingUploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val deps = EntryPointAccessors.fromApplication(applicationContext, PendingUploadEntryPoint::class.java)
        val session = deps.sessionManager()
        val outcome = PendingUploadRun.run(
            requestedUser = inputData.getString(KEY_USER),
            attempt = runAttemptCount,
            awaitAuth = {
                withTimeoutOrNull(PendingUploadRun.SESSION_RESTORE_TIMEOUT_MS) {
                    session.authState.first { it != AuthState.Loading }
                }
            },
            currentUser = { session.userId.value?.toString() },
            send = { deps.pendingEvidenceCenter().sendAwaiting(it) },
        )
        return if (outcome == PendingUploadRunResult.Retry) Result.retry() else Result.success()
    }

    companion object {
        const val KEY_USER = "user_id"
        fun uniqueName(userId: String) = "pending-upload-${userId.lowercase()}"
    }
}

/** One job per account; a job already waiting or running is kept, so scheduling again never duplicates work. */
class WorkManagerUploadScheduler(private val context: Context) : PendingUploadScheduler {
    override fun schedule(userId: String) {
        runCatching {
            WorkManager.getInstance(context).enqueueUniqueWork(
                PendingUploadWorker.uniqueName(userId),
                ExistingWorkPolicy.KEEP,
                request(userId),
            )
        }.onFailure { Log.w("PendingUpload", "couldn't schedule background upload", it) }
    }

    override fun cancel(userId: String) {
        runCatching { WorkManager.getInstance(context).cancelUniqueWork(PendingUploadWorker.uniqueName(userId)) }
    }

    companion object {
        const val BACKOFF_SECONDS = 30L

        fun request(userId: String): OneTimeWorkRequest =
            OneTimeWorkRequestBuilder<PendingUploadWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, BACKOFF_SECONDS, TimeUnit.SECONDS)
                .setInputData(workDataOf(PendingUploadWorker.KEY_USER to userId.lowercase()))
                .addTag("pending-upload")
                .build()
    }
}
