package com.example.pdf_reader

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * MainActivity handles both:
 * 1. Normal app launches from launcher (shows home/library)
 * 2. External PDF opening from WhatsApp, Telegram, File Managers, etc. in the single main window.
 *
 * Uses `launchMode="singleTask"` so opening a new PDF from outside while the app
 * (or another PDF) is already open immediately switches to the new PDF without
 * spinning up a second FlutterEngine or freezing on a black/white screen.
 */
class MainActivity : FlutterActivity() {

    private val TAG = "PdfMainActivity"
    private val CHANNEL = "com.example.pdf_reader/content_resolver"
    private val OFFICE_CHANNEL = "com.example.pdf_reader/office_intent"

    private val bgExecutor = Executors.newSingleThreadExecutor()

    @Volatile
    private var initialPdfPath: String? = null

    @Volatile
    private var isResolvingInitial: Boolean = false

    private var pendingInitialResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null

    // Separate state for external Office files (Word, Excel, PowerPoint, CSV)
    @Volatile
    private var initialOfficePath: String? = null

    @Volatile
    private var isResolvingInitialOffice: Boolean = false

    private var pendingInitialOfficeResult: MethodChannel.Result? = null
    private var officeMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val uri = extractUri(intent)
        if (uri != null) {
            tryTakePersistablePermission(uri)
            if (isOfficeIntent(intent, uri)) {
                // Separate Office pipeline (never touches PDF state)
                val directOfficePath = tryGetDirectFilePath(this, uri)
                if (directOfficePath != null) {
                    initialOfficePath = directOfficePath
                    Log.d(TAG, "onCreate direct Office path: $directOfficePath")
                } else {
                    isResolvingInitialOffice = true
                    val appContext = applicationContext
                    val mime = intent.type
                    bgExecutor.execute {
                        val copiedPath = resolveOfficeUri(appContext, uri, mime)
                        Log.d(TAG, "onCreate background resolved Office path: $copiedPath")
                        runOnUiThread {
                            initialOfficePath = copiedPath
                            isResolvingInitialOffice = false
                            val pending = pendingInitialOfficeResult
                            if (pending != null) {
                                pendingInitialOfficeResult = null
                                initialOfficePath = null
                                pending.success(copiedPath)
                            } else if (copiedPath != null) {
                                officeMethodChannel?.invokeMethod("onOpenOfficeFile", copiedPath)
                            }
                        }
                    }
                }
            } else {
                // Original PDF pipeline (untouched)
                // Fast path: check if we can resolve a direct readable file path in <1ms
                val directPath = tryGetDirectFilePath(this, uri)
                if (directPath != null) {
                    initialPdfPath = directPath
                    Log.d(TAG, "onCreate direct PDF path: $directPath")
                } else {
                    // Slow path (e.g. WhatsApp private stream): copy on background thread so UI never freezes
                    isResolvingInitial = true
                    val appContext = applicationContext
                    bgExecutor.execute {
                        val copiedPath = resolveUri(appContext, uri)
                        Log.d(TAG, "onCreate background resolved PDF path: $copiedPath")
                        runOnUiThread {
                            initialPdfPath = copiedPath
                            isResolvingInitial = false
                            val pending = pendingInitialResult
                            if (pending != null) {
                                pendingInitialResult = null
                                initialPdfPath = null
                                pending.success(copiedPath)
                            } else if (copiedPath != null) {
                                methodChannel?.invokeMethod("onOpenPdf", copiedPath)
                            }
                        }
                    }
                }
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = extractUri(intent) ?: return
        tryTakePersistablePermission(uri)

        if (isOfficeIntent(intent, uri)) {
            val directOfficePath = tryGetDirectFilePath(this, uri)
            if (directOfficePath != null) {
                Log.d(TAG, "onNewIntent direct Office path: $directOfficePath")
                officeMethodChannel?.invokeMethod("onOpenOfficeFile", directOfficePath)
            } else {
                val appContext = applicationContext
                val mime = intent.type
                bgExecutor.execute {
                    val copiedPath = resolveOfficeUri(appContext, uri, mime)
                    Log.d(TAG, "onNewIntent background resolved Office path: $copiedPath")
                    if (copiedPath != null) {
                        runOnUiThread {
                            officeMethodChannel?.invokeMethod("onOpenOfficeFile", copiedPath)
                        }
                    }
                }
            }
            return
        }

        val directPath = tryGetDirectFilePath(this, uri)
        if (directPath != null) {
            Log.d(TAG, "onNewIntent direct PDF path: $directPath")
            methodChannel?.invokeMethod("onOpenPdf", directPath)
        } else {
            val appContext = applicationContext
            bgExecutor.execute {
                val copiedPath = resolveUri(appContext, uri)
                Log.d(TAG, "onNewIntent background resolved PDF path: $copiedPath")
                if (copiedPath != null) {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onOpenPdf", copiedPath)
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        val officeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OFFICE_CHANNEL)
        officeMethodChannel = officeChannel

        officeChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialOfficePath" -> {
                    if (isResolvingInitialOffice) {
                        pendingInitialOfficeResult = result
                    } else {
                        val path = initialOfficePath
                        initialOfficePath = null
                        result.success(path)
                    }
                }
                else -> result.notImplemented()
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialPdfPath" -> {
                    if (isResolvingInitial) {
                        pendingInitialResult = result
                    } else {
                        val path = initialPdfPath
                        initialPdfPath = null
                        result.success(path)
                    }
                }
                "resolveContentUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        val appContext = applicationContext
                        bgExecutor.execute {
                            try {
                                val uri = Uri.parse(uriString)
                                val filePath = resolveUri(appContext, uri)
                                runOnUiThread {
                                    if (filePath != null) {
                                        result.success(filePath)
                                    } else {
                                        result.error("UNABLE_TO_RESOLVE", "Could not resolve URI", null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("EXCEPTION", e.localizedMessage, null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "URI is null", null)
                    }
                }
                "openExternalFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType")
                    val chooserTitle = call.argument<String>("title") ?: "Open with"
                    if (filePath.isNullOrBlank() || mimeType.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "File path or mimeType is empty", null)
                        return@setMethodCallHandler
                    }

                    val file = File(filePath)
                    if (!file.exists()) {
                        result.success("FILE_NOT_FOUND")
                        return@setMethodCallHandler
                    }

                    try {
                        val contentUri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "${packageName}.fileprovider",
                            file
                        )

                        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        val pm = packageManager
                        val resolveInfos = pm.queryIntentActivities(
                            viewIntent,
                            PackageManager.MATCH_DEFAULT_ONLY
                        )
                        val canHandle = if (resolveInfos.isNotEmpty()) {
                            true
                        } else {
                            val allResolves = pm.queryIntentActivities(viewIntent, 0)
                            allResolves.isNotEmpty()
                        }

                        if (!canHandle) {
                            result.success("NO_APP")
                            return@setMethodCallHandler
                        }

                        val chooserIntent = Intent.createChooser(viewIntent, chooserTitle).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooserIntent)
                        result.success("SUCCESS")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening external file", e)
                        result.error("OPEN_FAILED", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Extracts PDF Uri from either ACTION_VIEW (open with) or ACTION_SEND (share to)
     */
    private fun extractUri(intent: Intent?): Uri? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) {
            return null
        }

        var uri: Uri? = intent.data

        if (uri == null && action == Intent.ACTION_SEND) {
            uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        }

        if (uri == null && intent.clipData != null && intent.clipData!!.itemCount > 0) {
            uri = intent.clipData!!.getItemAt(0).uri
        }

        return uri
    }

    private fun tryTakePersistablePermission(uri: Uri) {
        if (uri.scheme == "content") {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: SecurityException) {
            } catch (_: Exception) {}
        }
    }

    /**
     * Attempts to resolve a direct readable file path on storage in <1ms without copying.
     */
    private fun tryGetDirectFilePath(context: Context, uri: Uri): String? {
        try {
            if (uri.scheme == "file") {
                val p = uri.path
                if (p != null && File(p).let { it.exists() && it.canRead() }) {
                    return p
                }
            }

            if (uri.scheme == "content") {
                // 1. Check MediaStore _data column (used by Samsung My Files, Xiaomi File Manager, etc.)
                try {
                    val projection = arrayOf(MediaStore.MediaColumns.DATA)
                    context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                        val colIndex = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                        if (colIndex != -1 && cursor.moveToFirst()) {
                            val dataPath = cursor.getString(colIndex)
                            if (!dataPath.isNullOrEmpty() && File(dataPath).let { it.exists() && it.canRead() }) {
                                return dataPath
                            }
                        }
                    }
                } catch (_: Exception) {}

                // 2. Check ExternalStorageProvider documents
                if (DocumentsContract.isDocumentUri(context, uri) &&
                    uri.authority == "com.android.externalstorage.documents"
                ) {
                    val docId = DocumentsContract.getDocumentId(uri)
                    val split = docId.split(":")
                    if (split.size >= 2 && split[0].equals("primary", ignoreCase = true)) {
                        val candidate = "/storage/emulated/0/${split[1]}"
                        if (File(candidate).let { it.exists() && it.canRead() }) {
                            return candidate
                        }
                    }
                }

                // 3. Check embedded /storage/emulated/0/ or /external_files/ in URI path
                val rawPath = uri.path
                if (!rawPath.isNullOrEmpty()) {
                    val storageIdx = rawPath.indexOf("/storage/emulated/0/")
                    if (storageIdx >= 0) {
                        val candidate = rawPath.substring(storageIdx)
                        if (File(candidate).let { it.exists() && it.canRead() }) {
                            return candidate
                        }
                    }
                    if (rawPath.startsWith("/external_files/")) {
                        val candidate = "/storage/emulated/0/" + rawPath.removePrefix("/external_files/")
                        if (File(candidate).let { it.exists() && it.canRead() }) {
                            return candidate
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun resolveUri(context: Context, uri: Uri): String? {
        val direct = tryGetDirectFilePath(context, uri)
        if (direct != null) return direct

        return when (uri.scheme) {
            "content" -> resolveContentUri(context, uri)
            "file" -> uri.path
            else -> uri.path ?: uri.toString()
        }
    }

    private fun resolveContentUri(context: Context, uri: Uri): String? {
        var inputStream: InputStream? = null
        try {
            inputStream = context.contentResolver.openInputStream(uri)
            if (inputStream != null) {
                var fileName = "document.pdf"
                try {
                    context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1 && cursor.moveToFirst()) {
                            val displayName = cursor.getString(nameIndex)
                            if (!displayName.isNullOrEmpty()) {
                                fileName = displayName
                            }
                        }
                    }
                } catch (_: Exception) {}

                if (!fileName.endsWith(".pdf", ignoreCase = true)) {
                    fileName += ".pdf"
                }

                val safeName = fileName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
                val docsDir = File(context.cacheDir, "shared_pdfs")
                if (!docsDir.exists()) {
                    docsDir.mkdirs()
                }

                val targetFile = File(docsDir, safeName)
                FileOutputStream(targetFile).use { outputStream ->
                    val buffer = ByteArray(64 * 1024)
                    var read: Int
                    while (inputStream.read(buffer).also { read = it } != -1) {
                        outputStream.write(buffer, 0, read)
                    }
                    outputStream.flush()
                }
                return targetFile.absolutePath
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve content URI: $uri", e)
        } finally {
            try {
                inputStream?.close()
            } catch (_: Exception) {}
        }
        return null
    }

    // =========================================================================
    // SEPARATE OFFICE DOCUMENT RESOLUTION (Word, Excel, PowerPoint, CSV, WPS)
    // Completely isolated from PDF resolution logic
    // =========================================================================

    private val officeExtensions = setOf(
        "docx", "doc", "dotx", "dot", "docm",
        "xlsx", "xls", "xltx", "xlt", "xlsm", "csv",
        "pptx", "ppt", "potx", "pot", "ppsx", "pptm",
        "rtf", "wps", "wpt", "et", "ett", "dps", "dpt"
    )

    private fun isOfficeIntent(intent: Intent?, uri: Uri): Boolean {
        val mime = (intent?.type ?: contentResolver.getType(uri) ?: "").lowercase()
        if (mime.contains("pdf")) return false

        if (mime.contains("word") ||
            mime.contains("excel") ||
            mime.contains("spreadsheet") ||
            mime.contains("powerpoint") ||
            mime.contains("presentation") ||
            mime.contains("officedocument") ||
            mime.contains("ms-word") ||
            mime.contains("ms-excel") ||
            mime.contains("ms-powerpoint") ||
            mime.contains("csv") ||
            mime.contains("comma-separated") ||
            mime.contains("rtf") ||
            mime.contains("kswps") ||
            mime.contains("kset") ||
            mime.contains("ksdps")
        ) {
            return true
        }

        // Check URI path extension
        val pathSeg = uri.lastPathSegment ?: uri.path ?: ""
        val dotIdx = pathSeg.lastIndexOf('.')
        if (dotIdx >= 0 && dotIdx < pathSeg.length - 1) {
            val ext = pathSeg.substring(dotIdx + 1).lowercase()
            if (ext == "pdf") return false
            if (officeExtensions.contains(ext)) return true
        }

        // Check OpenableColumns.DISPLAY_NAME if content:// URI has opaque path (WhatsApp / Telegram)
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx != -1 && cursor.moveToFirst()) {
                        val name = cursor.getString(idx) ?: ""
                        val dIdx = name.lastIndexOf('.')
                        if (dIdx >= 0 && dIdx < name.length - 1) {
                            val ext = name.substring(dIdx + 1).lowercase()
                            if (ext == "pdf") return false
                            if (officeExtensions.contains(ext)) return true
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        return false
    }

    private fun resolveOfficeUri(context: Context, uri: Uri, intentMime: String?): String? {
        val direct = tryGetDirectFilePath(context, uri)
        if (direct != null) return direct

        return when (uri.scheme) {
            "content" -> resolveOfficeContentUri(context, uri, intentMime)
            "file" -> uri.path
            else -> uri.path ?: uri.toString()
        }
    }

    private fun inferOfficeExtension(mime: String?, fallbackName: String): String {
        val dIdx = fallbackName.lastIndexOf('.')
        if (dIdx >= 0 && dIdx < fallbackName.length - 1) {
            val ext = fallbackName.substring(dIdx + 1).lowercase()
            if (officeExtensions.contains(ext)) return ".$ext"
        }
        val m = (mime ?: "").lowercase()
        return when {
            m.contains("wordprocessingml") -> ".docx"
            m.contains("msword") || m.contains("ms-word") -> ".doc"
            m.contains("spreadsheetml") -> ".xlsx"
            m.contains("ms-excel") || m.contains("msexcel") -> ".xls"
            m.contains("presentationml") -> ".pptx"
            m.contains("ms-powerpoint") || m.contains("mspowerpoint") -> ".ppt"
            m.contains("csv") || m.contains("comma-separated") -> ".csv"
            m.contains("rtf") -> ".rtf"
            else -> ".docx"
        }
    }

    private fun resolveOfficeContentUri(context: Context, uri: Uri, intentMime: String?): String? {
        var inputStream: InputStream? = null
        try {
            inputStream = context.contentResolver.openInputStream(uri)
            if (inputStream != null) {
                var fileName = ""
                try {
                    context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1 && cursor.moveToFirst()) {
                            val displayName = cursor.getString(nameIndex)
                            if (!displayName.isNullOrEmpty()) {
                                fileName = displayName
                            }
                        }
                    }
                } catch (_: Exception) {}

                if (fileName.isEmpty()) {
                    val seg = uri.lastPathSegment ?: "office_document"
                    fileName = seg
                }

                val resolvedMime = intentMime ?: context.contentResolver.getType(uri)
                val ext = inferOfficeExtension(resolvedMime, fileName)
                val hasValidExt = officeExtensions.any { fileName.lowercase().endsWith(".$it") }
                if (!hasValidExt) {
                    fileName += ext
                }

                val safeName = fileName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
                val docsDir = File(context.cacheDir, "shared_office_docs")
                if (!docsDir.exists()) {
                    docsDir.mkdirs()
                }

                val targetFile = File(docsDir, safeName)
                FileOutputStream(targetFile).use { outputStream ->
                    val buffer = ByteArray(64 * 1024)
                    var read: Int
                    while (inputStream.read(buffer).also { read = it } != -1) {
                        outputStream.write(buffer, 0, read)
                    }
                    outputStream.flush()
                }
                return targetFile.absolutePath
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve Office content URI: $uri", e)
        } finally {
            try {
                inputStream?.close()
            } catch (_: Exception) {}
        }
        return null
    }
}
