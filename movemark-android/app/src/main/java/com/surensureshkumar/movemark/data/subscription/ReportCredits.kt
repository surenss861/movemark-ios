package com.surensureshkumar.movemark.data.subscription

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import android.util.Log
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/*
 * MoveMark — move-in report allowance for free accounts (iOS SubscriptionManager report credits): one free
 * move-in report, plus one per Report Pack (a one-time purchase). The server's balance
 * (`GET /api/account/report-credits`) wins once fetched; local counters are the fallback. Pro is unlimited.
 */

/** The allowance rule, pure (iOS `remainingMoveInExports` / `hasUsableReportPackCredit`). */
object ReportCreditPolicy {
    /** How long after a purchase a server 402 is treated as "still syncing" rather than "buy again". */
    const val PURCHASE_SYNC_WINDOW_MS = 10 * 60 * 1000L

    const val PURCHASE_STILL_SYNCING = "Your purchase is still syncing. Try again in a minute."

    /** One-time Report Pack product ids — must match Play Console / RevenueCat. */
    private val PRODUCT_IDS = setOf("report_pack", "movemark_report_pack", "test_report_pack")

    fun isReportPackProduct(productId: String): Boolean =
        productId.substringBefore(':') in PRODUCT_IDS || productId.contains("report_pack", ignoreCase = true)

    fun isPurchaseLikelySyncing(lastPurchaseAtMs: Long?, nowMs: Long): Boolean =
        lastPurchaseAtMs != null && nowMs - lastPurchaseAtMs < PURCHASE_SYNC_WINDOW_MS

    /** Move-in reports still available to a free user. */
    fun remainingMoveInExports(freeUsed: Int, localPackCredits: Int, serverBalance: Int?, syncing: Boolean): Int {
        val localRemaining = maxOf(0, 1 + localPackCredits - freeUsed)
        serverBalance ?: return localRemaining
        val serverRemaining = (if (freeUsed < 1) 1 else 0) + maxOf(0, serverBalance)
        // Right after a purchase the webhook may lag; don't bounce the renter back to the paywall to buy twice.
        return if (syncing) maxOf(serverRemaining, localRemaining) else serverRemaining
    }

    /** A Report Pack credit that can still be spent (decides whether a restore restored anything). */
    fun hasUsablePackCredit(freeUsed: Int, localPackCredits: Int, serverBalance: Int?): Boolean =
        if (serverBalance != null) serverBalance > 0 else localPackCredits > 0 && freeUsed < 1 + localPackCredits
}

/** Per-user counters on this device. */
@Singleton
class ReportCreditsStore @Inject constructor(private val dataStore: DataStore<Preferences>) {
    private fun freeKey(userId: UUID) = intPreferencesKey("free_move_in_exports_${userId.toString().lowercase()}")
    private fun packKey(userId: UUID) = intPreferencesKey("report_pack_credits_${userId.toString().lowercase()}")

    suspend fun freeUsed(userId: UUID): Int = dataStore.data.first()[freeKey(userId)] ?: 0
    suspend fun packCredits(userId: UUID): Int = maxOf(0, dataStore.data.first()[packKey(userId)] ?: 0)

    suspend fun incrementFreeUsed(userId: UUID) {
        dataStore.edit { it[freeKey(userId)] = (it[freeKey(userId)] ?: 0) + 1 }
    }

    /** Local credits never go below what RevenueCat says was bought (restore / reinstall). */
    suspend fun mergePackPurchases(userId: UUID, purchased: Int): Int {
        var merged = 0
        dataStore.edit {
            merged = maxOf(it[packKey(userId)] ?: 0, purchased)
            it[packKey(userId)] = merged
        }
        return merged
    }
}

/** App-wide report credits: server balance, local counters, purchase sync window. */
@Singleton
class ReportCreditsManager @Inject constructor(
    private val store: ReportCreditsStore,
    private val api: ExportApiClient,
) {
    internal var clock: () -> Long = System::currentTimeMillis

    private var serverBalance: Int? = null
    private var serverUser: UUID? = null
    private var lastPurchaseAt: Long? = null

    private val _balance = MutableStateFlow<Int?>(null)
    /** The server's Report Pack balance for the signed-in user; null until fetched. */
    val balance: StateFlow<Int?> = _balance.asStateFlow()

    val isPurchaseLikelySyncing: Boolean get() = ReportCreditPolicy.isPurchaseLikelySyncing(lastPurchaseAt, clock())

    private fun balanceFor(userId: UUID) = serverBalance.takeIf { serverUser == userId }

    /** Call on sign-in, after purchase / restore, on paywall and Reports, and after a 402. Null when it failed. */
    suspend fun refresh(userId: UUID?): Int? {
        if (userId == null) {
            // Signed out: nothing cached may leak into the next account.
            serverBalance = null
            serverUser = null
            lastPurchaseAt = null
            _balance.value = null
            return null
        }
        return try {
            val value = maxOf(0, api.fetchReportCredits().balance)
            serverBalance = value
            serverUser = userId
            _balance.value = value
            value
        } catch (e: Exception) {
            Log.e("MoveMarkCredits", "report credits fetch failed: ${e.javaClass.simpleName}")
            null
        }
    }

    suspend fun canExportMoveIn(userId: UUID?, hasPro: Boolean): Boolean {
        if (hasPro) return true
        userId ?: return false
        return ReportCreditPolicy.remainingMoveInExports(
            store.freeUsed(userId), store.packCredits(userId), balanceFor(userId), isPurchaseLikelySyncing,
        ) > 0
    }

    suspend fun hasUsablePackCredit(userId: UUID?): Boolean {
        userId ?: return false
        return ReportCreditPolicy.hasUsablePackCredit(store.freeUsed(userId), store.packCredits(userId), balanceFor(userId))
    }

    /** A free (non-Pro) move-in report was queued. */
    suspend fun recordMoveInExport(userId: UUID) = store.incrementFreeUsed(userId)

    /** A purchase (Pro or Report Pack) finished on this device. */
    suspend fun purchaseCompleted(userId: UUID?, reportPackPurchases: Int) {
        lastPurchaseAt = clock()
        userId?.let { store.mergePackPurchases(it, reportPackPurchases) }
        refresh(userId)
    }

    /** After a restore: merge the packs RevenueCat knows about, then ask the server. */
    suspend fun restored(userId: UUID?, reportPackPurchases: Int) {
        userId?.let { store.mergePackPurchases(it, reportPackPurchases) }
        refresh(userId)
    }
}
