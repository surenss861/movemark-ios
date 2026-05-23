package com.surensureshkumar.movemark.core.util

import android.content.Context
import android.content.Intent
import android.net.Uri

object PlaySubscriptionIntents {
    fun openManageSubscriptions(context: Context) {
        val pkg = context.packageName
        val playSubscriptions = Uri.parse(
            "https://play.google.com/store/account/subscriptions?package=$pkg",
        )
        val intent = Intent(Intent.ACTION_VIEW, playSubscriptions).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
            .onFailure {
                val fallback = Uri.parse("https://play.google.com/store/apps/details?id=$pkg")
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, fallback).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }
    }
}
