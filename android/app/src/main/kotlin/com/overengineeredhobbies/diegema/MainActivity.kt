package com.overengineeredhobbies.diegema

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// AudioServiceActivity (a FlutterActivity subclass provided by audio_service)
// links this activity to the plugin's shared FlutterEngine so the
// background playback service and the app's own UI can share one Dart
// isolate. See the audio_service README's "Custom Android activity" section.
class MainActivity : AudioServiceActivity() {
    private var pendingDelete: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // See lib/services/downloads_location_io.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "diegema/downloads_location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "audiobooksDirectory" -> result.success(audiobooksDirectory())
                    "deleteMedia" -> deleteMedia(call.arguments as List<*>, result)
                    else -> result.notImplemented()
                }
            }
    }

    // Shared Audiobooks/Diegema, from Android 11: apps may then create audio
    // files in standard media folders through plain file paths. Older
    // versions keep downloads app-private (null).
    private fun audiobooksDirectory(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        @Suppress("DEPRECATION")
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_AUDIOBOOKS)
        return File(dir, "Diegema").path
    }

    // Files an earlier install wrote are no longer this app's; deleting them
    // needs the user's consent through the system dialog.
    private fun deleteMedia(paths: List<*>, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || pendingDelete != null) {
            result.success(false)
            return
        }
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val uris = paths.filterIsInstance<String>().mapNotNull { path ->
            @Suppress("DEPRECATION")
            contentResolver.query(
                collection, arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DATA} = ?", arrayOf(path), null
            )?.use { c -> if (c.moveToFirst()) ContentUris.withAppendedId(collection, c.getLong(0)) else null }
        }
        if (uris.isEmpty()) {
            result.success(false)
            return
        }
        try {
            val request = MediaStore.createDeleteRequest(contentResolver, uris)
            pendingDelete = result
            startIntentSenderForResult(request.intentSender, DELETE_REQUEST, null, 0, 0, 0)
        } catch (e: Exception) {
            pendingDelete = null
            result.error("delete_failed", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == DELETE_REQUEST) {
            pendingDelete?.success(resultCode == Activity.RESULT_OK)
            pendingDelete = null
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private companion object {
        const val DELETE_REQUEST = 4207
    }
}
