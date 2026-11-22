package com.hostingerpanel.app

import android.app.DownloadManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.webkit.CookieManager
import android.webkit.MimeTypeMap
import android.webkit.URLUtil
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

class MainActivity : FlutterActivity() {

    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFiles" -> pickFiles(
                        call.argument<List<String>>("acceptTypes").orEmpty(),
                        call.argument<Boolean>("allowMultiple") ?: false,
                        result,
                    )
                    "attachDownloadHandler" -> {
                        val id = call.argument<Number>("webViewId")?.toLong()
                        if (id == null) {
                            result.error("BAD_ARGS", "webViewId is required", null)
                        } else {
                            attachDownloadHandler(flutterEngine, id, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickFiles(
        acceptTypes: List<String>,
        allowMultiple: Boolean,
        result: MethodChannel.Result,
    ) {
        if (pendingPickResult != null) {
            result.error("ALREADY_ACTIVE", "A file picker is already open", null)
            return
        }
        val mimeTypes = toMimeTypes(acceptTypes)
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            if (mimeTypes.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
        }
        pendingPickResult = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(Intent.createChooser(intent, null), REQUEST_PICK_FILES)
        } catch (e: ActivityNotFoundException) {
            pendingPickResult = null
            result.success(emptyList<String>())
        }
    }

    private fun toMimeTypes(acceptTypes: List<String>): List<String> =
        acceptTypes
            .flatMap { it.split(',') }
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
            .mapNotNull { type ->
                if (type.contains('/')) {
                    type
                } else {
                    MimeTypeMap.getSingleton().getMimeTypeFromExtension(type.removePrefix("."))
                }
            }
            .distinct()

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_FILES) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPickResult ?: return
        pendingPickResult = null

        if (resultCode != RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }
        val uris = mutableListOf<String>()
        data.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri.toString())
        }
        if (uris.isEmpty()) data.data?.let { uris.add(it.toString()) }
        result.success(uris)
    }

    private fun attachDownloadHandler(
        engine: FlutterEngine,
        webViewId: Long,
        result: MethodChannel.Result,
    ) {
        val webView = WebViewFlutterAndroidExternalApi.getWebView(engine, webViewId)
        if (webView == null) {
            result.error("NO_WEBVIEW", "WebView $webViewId not found", null)
            return
        }
        webView.setDownloadListener { url, userAgent, contentDisposition, mimeType, _ ->
            startDownload(url, userAgent, contentDisposition, mimeType)
        }
        result.success(null)
    }

    private fun startDownload(
        url: String,
        userAgent: String?,
        contentDisposition: String?,
        mimeType: String?,
    ) {
        val uri = Uri.parse(url)
        if (uri.scheme != "https" && uri.scheme != "http") {
            toast("This download type is not supported in the app.")
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            openInBrowser(uri)
            return
        }
        try {
            val fileName = URLUtil.guessFileName(url, contentDisposition, mimeType)
            val request = DownloadManager.Request(uri).apply {
                setMimeType(mimeType)
                CookieManager.getInstance().getCookie(url)?.let { addRequestHeader("Cookie", it) }
                userAgent?.let { addRequestHeader("User-Agent", it) }
                setTitle(fileName)
                setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                )
                setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            }
            val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
            dm.enqueue(request)
            toast("Downloading $fileName")
        } catch (e: Exception) {
            openInBrowser(uri)
        }
    }

    private fun openInBrowser(uri: Uri) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (e: ActivityNotFoundException) {
            toast("No app found to handle this download.")
        }
    }

    private fun toast(message: String) =
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()

    companion object {
        private const val CHANNEL = "com.hostingerpanel.app/webview"
        private const val REQUEST_PICK_FILES = 4801
    }
}
