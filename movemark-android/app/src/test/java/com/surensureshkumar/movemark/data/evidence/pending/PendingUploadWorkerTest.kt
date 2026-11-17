package com.surensureshkumar.movemark.data.evidence.pending

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.BackoffPolicy
import androidx.work.Configuration
import androidx.work.NetworkType
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.testing.SynchronousExecutor
import androidx.work.testing.WorkManagerTestInitHelper
import com.surensureshkumar.movemark.data.auth.AuthState
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.IOException

@RunWith(AndroidJUnit4::class)
class PendingUploadWorkerTest {
    private val user = "11111111-1111-1111-1111-111111111111"
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        WorkManagerTestInitHelper.initializeTestWorkManager(
            context,
            Configuration.Builder().setExecutor(SynchronousExecutor()).build(),
        )
    }

    private suspend fun run(
        attempt: Int = 0,
        auth: AuthState? = AuthState.SignedIn,
        current: String? = user,
        requested: String? = user,
        send: suspend (String) -> PendingUploadReport = { PendingUploadReport(1, 2, 0) },
    ) = PendingUploadRun.run(requested, attempt, { auth }, { current }, send)

    // --- One run ---

    @Test
    fun everythingUploadedEndsTheJob() = runTest {
        assertEquals(PendingUploadRunResult.Success, run())
    }

    @Test
    fun photosLeftRetryWithBackoffUntilTheCap() = runTest {
        val left = { _: String -> PendingUploadReport(1, 0, 2) }
        assertEquals(PendingUploadRunResult.Retry, run(attempt = 0, send = left))
        assertEquals(PendingUploadRunResult.Success, run(attempt = PendingUploadPolicy.MAX_ATTEMPTS - 1, send = left))
    }

    @Test
    fun aFailedPassRetries() = runTest {
        assertEquals(PendingUploadRunResult.Retry, run(send = { throw IOException("offline") }))
    }

    @Test
    fun sessionNotRestoredInTimeRetries() = runTest {
        assertEquals(PendingUploadRunResult.Retry, run(auth = null))
    }

    @Test
    fun signedOutOrAnotherAccountSendsNothing() = runTest {
        var sent = 0
        val send: suspend (String) -> PendingUploadReport = { sent++; PendingUploadReport(0, 0, 0) }
        assertEquals(PendingUploadRunResult.Success, run(auth = AuthState.SignedOut, current = null, send = send))
        assertEquals(PendingUploadRunResult.Success, run(current = "22222222-2222-2222-2222-222222222222", send = send))
        assertEquals(PendingUploadRunResult.Success, run(requested = null, send = send))
        assertEquals(0, sent)
    }

    @Test
    fun accountIdsCompareCaseInsensitively() = runTest {
        var sentFor: String? = null
        run(current = user.uppercase(), send = { sentFor = it; PendingUploadReport(1, 1, 0) })
        assertEquals(user, sentFor)
    }

    // --- Scheduling ---

    @Test
    fun schedulingTwiceKeepsOneNetworkConstrainedJob() {
        val scheduler = WorkManagerUploadScheduler(context)
        scheduler.schedule(user)
        scheduler.schedule(user.uppercase())
        val infos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(PendingUploadWorker.uniqueName(user)).get()
        assertEquals(1, infos.size)
        assertEquals(WorkInfo.State.ENQUEUED, infos.single().state)
    }

    @Test
    fun theJobWaitsForANetworkAndBacksOffExponentially() {
        val spec = WorkManagerUploadScheduler.request(user).workSpec
        assertEquals(NetworkType.CONNECTED, spec.constraints.requiredNetworkType)
        assertEquals(BackoffPolicy.EXPONENTIAL, spec.backoffPolicy)
        assertEquals(WorkManagerUploadScheduler.BACKOFF_SECONDS * 1000, spec.backoffDelayDuration)
        assertEquals(user, spec.input.getString(PendingUploadWorker.KEY_USER))
        assertEquals(PendingUploadWorker::class.java.name, spec.workerClassName)
    }

    @Test
    fun signOutCancelsTheJob() {
        val scheduler = WorkManagerUploadScheduler(context)
        scheduler.schedule(user)
        scheduler.cancel(user)
        val infos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(PendingUploadWorker.uniqueName(user)).get()
        assertTrue(infos.all { it.state == WorkInfo.State.CANCELLED })
    }
}
