/**
 * @file Whether the phone has a validated internet connection, and a signal each time it comes back, so launch gates
 *       that couldn't be checked offline are re-checked without a relaunch.
 * @domain platform
 * @status wip
 * @see [[StartupCoordinator.kt]]
 */
package com.surensureshkumar.movemark.core.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ConnectivityMonitor @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val manager = context.getSystemService(ConnectivityManager::class.java)

    private val _isOnline = MutableStateFlow(currentlyOnline())
    val isOnline: StateFlow<Boolean> = _isOnline.asStateFlow()

    private val _reconnected = MutableSharedFlow<Unit>(extraBufferCapacity = 1, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    /** Emits when the connection goes from offline to online. */
    val reconnected: SharedFlow<Unit> = _reconnected.asSharedFlow()

    init {
        runCatching {
            manager?.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = update(caps.isUsable())
                override fun onLost(network: Network) = update(false)
                override fun onUnavailable() = update(false)
            })
        }.onFailure { Log.w(TAG, "network callback unavailable", it) }
    }

    private fun update(online: Boolean) {
        val was = _isOnline.value
        _isOnline.value = online
        if (online && !was) _reconnected.tryEmit(Unit)
    }

    private fun currentlyOnline(): Boolean = runCatching {
        manager?.getNetworkCapabilities(manager.activeNetwork)?.isUsable() == true
    }.getOrDefault(true)

    private fun NetworkCapabilities.isUsable() =
        hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

    private companion object {
        const val TAG = "Connectivity"
    }
}
