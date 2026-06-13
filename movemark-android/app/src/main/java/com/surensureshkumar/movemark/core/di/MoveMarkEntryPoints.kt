package com.surensureshkumar.movemark.core.di

import com.surensureshkumar.movemark.core.navigation.MainTabRequest
import com.surensureshkumar.movemark.data.firstrun.FirstRunProofPreferences
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@EntryPoint
@InstallIn(SingletonComponent::class)
interface MoveMarkEntryPoints {
    fun mainTabRequest(): MainTabRequest
    fun firstRunProofPreferences(): FirstRunProofPreferences
}
