package com.devapp.doc_manager

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.devapp.doc_manager/pdf_thumbnail"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            CHANNEL,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        ).setMethodCallHandler { call, result ->
            if (call.method == "renderFirstPage") {
                val pdfPath = call.argument<String>("pdfPath")
                val thumbPath = call.argument<String>("thumbPath")
                val maxWidth = call.argument<Int>("maxWidth") ?: 360
                if (pdfPath == null || thumbPath == null || maxWidth !in 1..2048) {
                    result.error("INVALID_ARGS", "Paths are required and maxWidth must be between 1 and 2048", null)
                    return@setMethodCallHandler
                }
                try {
                    val success = renderPdfPage(pdfPath, thumbPath, maxWidth)
                    result.success(success)
                } catch (e: Exception) {
                    result.error("RENDER_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun renderPdfPage(pdfPath: String, thumbPath: String, maxWidth: Int): Boolean {
        val file = File(pdfPath)
        if (!file.exists()) return false
        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        var renderer: PdfRenderer? = null
        var page: PdfRenderer.Page? = null
        try {
            renderer = PdfRenderer(pfd)
            if (renderer.pageCount == 0) return false
            page = renderer.openPage(0)
            val srcWidth = page.width
            val srcHeight = page.height
            val scale = maxWidth.toFloat() / max(1, srcWidth).toFloat()
            val targetWidth = maxWidth
            val targetHeight = max(1, (srcHeight * scale).toInt())

            val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            try {
                val canvas = Canvas(bitmap)
                canvas.drawColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

                val outFile = File(thumbPath)
                outFile.parentFile?.mkdirs()
                FileOutputStream(outFile).use { fos ->
                    check(bitmap.compress(Bitmap.CompressFormat.JPEG, 80, fos)) {
                        "Unable to encode PDF thumbnail"
                    }
                }
                return true
            } finally {
                bitmap.recycle()
            }
        } finally {
            try { page?.close() } catch (_: Exception) {}
            try { renderer?.close() } catch (_: Exception) {}
            try { pfd.close() } catch (_: Exception) {}
        }
    }
}
