/**
 * @file MoveMark's own pages open in a Custom Tab, which keeps its open-in-browser option. Falls back to the default
 *       browser on a device with none.
 * @domain onboarding-auth
 * @status wip
 * @see [[MMInAppLegalBrowser.swift]] — iOS counterpart
 */
package com.surensureshkumar.movemark.core.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent

fun openInAppBrowser(context: Context, url: String) {
    val uri = Uri.parse(url)
    try {
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, uri)
    } catch (_: ActivityNotFoundException) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, uri)) }
    }
}
