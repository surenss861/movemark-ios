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

/** What happens when a free account asks for a move-in report. */
enum class MoveInGate {
    /** Send the request; the server decides (and may still answer 402). */
    Allowed,

    /** Nothing left by the server's numbers: open the paywall. */
    Paywall,

    /**
     * Nothing left by the server's numbers, but a purchase finished in the last 10 minutes and its webhook may not
     * have reached the server yet: say so instead of offering a second purchase. No credit is assumed.
     */
    StillSyncing,
}

/**
 * The allowance rule, pure. Report Pack credits come from the server balance alone (`GET api/account/report-credits`,
 * granted once per RevenueCat event by the webhook); nothing on the phone ever adds a credit. The free move-in report
 * is the only local counter, and it can only hold a request back, never grant one.
 */
object ReportCreditPolicy {
    /** How long after a purchase a refusal reads "still syncing" rather than "buy again". Copy only. */
    const val PURCHASE_SYNC_WINDOW_MS = 10 * 60 * 1000L

    const val PURCHASE_STILL_SYNCING = "Your purchase is still syncing. Try again in a minute."

    /**
     * The one Report Pack product: `report_pack`, a consumable one-time product. It is the id the API's webhook
     * falls back to and its smoke tests send, and the id iOS's paywall tests use. Matched exactly.
     */
    const val REPORT_PACK_PRODUCT_ID = "report_pack"

    fun isReportPackProduct(productId: String): Boolean = productId.trim().lowercase() == REPORT_PACK_PRODUCT_ID

    fun isPurchaseLikelySyncing(lastPurchaseAtMs: Long?, nowMs: Long): Boolean =
        lastPurchaseAtMs != null && nowMs in lastPurchaseAtMs until lastPurchaseAtMs + PURCHASE_SYNC_WINDOW_MS

    /**
     * Move-in reports a free account may request: the unused free one plus the server's balance. An unknown balance
     * (not fetched, or the fetch failed) counts as nothing extra: the request may still go to the server, which
     * decides. The sync window is deliberately not an input.
     */
    fun remainingMoveInExports(freeUsed: Int, serverBalance: Int?): Int =
        (if (freeUsed < 1) 1 else 0) + maxOf(0, serverBalance ?: 0)

    fun moveInGate(freeUsed: Int, serverBalance: Int?, syncing: Boolean): MoveInGate = when {
        remainingMoveInExports(freeUsed, serverBalance) > 0 -> MoveInGate.Allowed
        // Unknown balance: let the server decide rather than guess either way.
        serverBalance == null -> MoveInGate.Allowed
        syncing -> MoveInGate.StillSyncing
        else -> MoveInGate.Paywall
    }

    /** A restore restored a Report Pack only when the server holds an unspent credit. */
    fun hasUsablePackCredit(serverBalance: Int?): Boolean = (serverBalance ?: 0) > 0
}

/** The free move-in report, per user, on this device (an advisory pre-check; the server enforces it too). */
@Singleton
class ReportCreditsStore @Inject constructor(private val dataStore: DataStore<Preferences>) {
    private fun freeKey(userId: UUID) = intPreferencesKey("free_move_in_exports_${userId.toString().lowercase()}")

    suspend fun freeUsed(userId: UUID): Int = dataStore.data.first()[freeKey(userId)] ?: 0

    suspend fun incrementFreeUsed(userId: UUID) {
        dataStore.edit { it[freeKey(userId)] = (it[freeKey(userId)] ?: 0) + 1 }
    }
}

/** App-wide report credits: the server balance, the free-report counter, the purchase sync window (copy only). */
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

    suspend fun moveInGate(userId: UUID?, hasPro: Boolean): MoveInGate {
        if (hasPro) return MoveInGate.Allowed
        userId ?: return MoveInGate.Paywall
        return ReportCreditPolicy.moveInGate(store.freeUsed(userId), balanceFor(userId), isPurchaseLikelySyncing)
    }

    fun hasUsablePackCredit(userId: UUID?): Boolean =
        userId != null && ReportCreditPolicy.hasUsablePackCredit(balanceFor(userId))

    /** A free (non-Pro) move-in report was queued. */
    suspend fun recordMoveInExport(userId: UUID) = store.incrementFreeUsed(userId)

    /** A purchase (Pro or Report Pack) finished on this device: start the copy window and ask the server. */
    suspend fun purchaseCompleted(userId: UUID?) {
        lastPurchaseAt = clock()
        refresh(userId)
    }

    /** After a restore: the server's balance says whether a pack is still unspent. */
    suspend fun restored(userId: UUID?) {
        refresh(userId)
    }
}
