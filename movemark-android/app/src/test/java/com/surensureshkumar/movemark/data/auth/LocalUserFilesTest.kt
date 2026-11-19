package com.surensureshkumar.movemark.data.auth

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class LocalUserFilesTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test
    fun clearRemovesReportsDocumentsAndCapturesButNothingElse() {
        val cache = tmp.newFolder("cache")
        val folders = LocalUserFiles.FOLDERS.map { File(cache, it).apply { mkdirs(); File(this, "x.pdf").writeText("x") } }
        val other = File(cache, "coil_image_cache").apply { mkdirs() }
        LocalUserFiles(folders).clear()
        folders.forEach { assertFalse(it.exists()) }
        assertTrue(other.exists())
    }

    @Test
    fun foldersMatchTheFileProviderPaths() {
        val xml = listOf("src/main/res/xml/file_paths.xml", "app/src/main/res/xml/file_paths.xml")
            .map(::File).first { it.exists() }.readText()
        LocalUserFiles.FOLDERS.forEach { assertTrue("$it in file_paths.xml", xml.contains("path=\"$it/\"")) }
    }
}
