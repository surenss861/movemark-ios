package com.surensureshkumar.movemark.data.export

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/**
 * Realtime replacement for polling export status: subscribes to `postgres_changes` on
 * `public.exports` for a single property (RLS-scoped via the existing `exports_select_own` policy,
 * so this doesn't widen who can see which rows -- see
 * supabase/migrations/20260719000001_property_snapshot_thumbnails_realtime.sql).
 *
 * Deliberately doesn't decode the changed row into an [ExportRow] itself -- the authoritative shape
 * (including `verification`, mapped from the export API's response) already comes from
 * [ExportRepository.loadExports]. This just acts as a low-latency "something changed, re-fetch"
 * signal; [onChange] is expected to call that.
 */
@Singleton
class ExportRealtimeWatcher @Inject constructor(
    private val client: SupabaseClient,
) {
    /**
     * Suspends for as long as the subscription is alive, invoking [onChange] on every insert/update
     * to an `exports` row for [propertyId]. Cancelling the calling coroutine unsubscribes cleanly.
     * Throws on connection failure -- callers should wrap this in their own error handling and keep
     * an existing refresh path (pull-to-refresh, post-action refresh, etc.) as a fallback in case
     * the socket never connects or silently drops; this alone is not a strand-proof mechanism.
     */
    suspend fun watchExportChanges(propertyId: UUID, onChange: () -> Unit) {
        val channel = client.channel("exports-$propertyId")
        try {
            val changes = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
                table = "exports"
                filter("property_id", FilterOperator.EQ, propertyId.toString())
            }
            channel.subscribe()
            changes.collect { onChange() }
        } finally {
            // NonCancellable: this runs during cancellation too (property switch, ViewModel
            // cleared), when the surrounding coroutine's context is already cancelled and would
            // otherwise reject this suspend call immediately.
            withContext(NonCancellable) {
                runCatching { channel.unsubscribe() }
            }
        }
    }
}
