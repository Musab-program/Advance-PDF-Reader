package com.example.pdf_reader

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

/**
 * A dedicated, isolated Activity for opening PDF files shared from
 * external apps (File Manager, WhatsApp, Telegram, etc.).
 *
 * Runs a completely separate Flutter engine so it NEVER conflicts with
 * the GlobalKey / Navigator state of the main app.
 * Same pattern used by Google Drive, WPS Office, Adobe Acrobat.
 */
class ViewerActivity : FlutterActivity() {

    private val CHANNEL = "com.example.pdf_reader/content_resolver"
    private val VIEWER_CHANNEL = "com.example.pdf_reader/viewer_init"

    // Resolved path is stored here as soon as onCreate runs,
    // before Flutter engine even starts — ensures content:// permission is valid.
    private var resolvedFilePath: String? = null

    override fun getDartEntrypointFunctionName(): String = "viewerMain"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Resolve the URI immediately — Android grants temporary read permission
        // only during this window. Must happen before super.onCreate() which
        // starts the Flutter engine.
        val uri = intent?.data
        if (uri != null) {
            resolvedFilePath = when (uri.scheme) {
                "content" -> resolveContentUri(this, uri.toString())
                "file"    -> uri.path
                else      -> uri.toString()
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel 1: lets Flutter ask for the resolved file path
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIEWER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFilePath" -> result.success(resolvedFilePath)
                    else                -> result.notImplemented()
                }
            }

        // Channel 2: content URI resolver (kept for compatibility)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "resolveContentUri") {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        try {
                            val filePath = resolveContentUri(this, uriString)
                            if (filePath != null) result.success(filePath)
                            else result.error("UNABLE_TO_RESOLVE", "Could not resolve URI", null)
                        } catch (e: Exception) {
                            result.error("EXCEPTION", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "URI is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun resolveContentUri(context: Context, uriString: String): String? {
        val uri = Uri.parse(uriString)
        var inputStream: InputStream? = null
        try {
            inputStream = context.contentResolver.openInputStream(uri)
            if (inputStream != null) {
                var fileName = "temp_external_file.pdf"
                context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1 && cursor.moveToFirst()) {
                        val displayName = cursor.getString(nameIndex)
                        if (!displayName.isNullOrEmpty()) fileName = displayName
                    }
                }

                val cacheDir = context.cacheDir
                if (!cacheDir.exists()) cacheDir.mkdirs()

                val tempFile = File(cacheDir, fileName)
                FileOutputStream(tempFile).use { outputStream ->
                    val buffer = ByteArray(64 * 1024)
                    var read: Int
                    while (inputStream.read(buffer).also { read = it } != -1) {
                        outputStream.write(buffer, 0, read)
                    }
                    outputStream.flush()
                }
                return tempFile.absolutePath
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            try { inputStream?.close() } catch (_: Exception) {}
        }
        return null
    }
}
