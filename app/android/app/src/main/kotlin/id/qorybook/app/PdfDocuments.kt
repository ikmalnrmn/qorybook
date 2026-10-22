package id.qorybook.app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.sqrt

/**
 * Menampilkan halaman PDF memakai PdfRenderer bawaan Android.
 * PdfRenderer tidak thread-safe, jadi semua akses lewat satu thread.
 */
class PdfDocuments : MethodChannel.MethodCallHandler {
    private class Doc(val fd: ParcelFileDescriptor, val renderer: PdfRenderer)

    private val docs = HashMap<Int, Doc>()
    private var nextId = 1
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> runAsync(result) { open(call.argument<String>("path")!!) }
            "render" -> runAsync(result) {
                render(call.argument<Int>("id")!!, call.argument<Int>("page")!!, call.argument<Int>("width")!!)
            }
            "close" -> runAsync(result) { close(call.argument<Int>("id")!!); null }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Throwable) {
                main.post { result.error("pdf_error", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    private fun open(path: String): Map<String, Any> {
        val fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try {
            PdfRenderer(fd)
        } catch (e: Exception) {
            fd.close()
            throw e
        }
        val sizes = ArrayList<List<Int>>(renderer.pageCount)
        for (i in 0 until renderer.pageCount) {
            val page = renderer.openPage(i)
            sizes.add(listOf(page.width, page.height))
            page.close()
        }
        val id = nextId++
        docs[id] = Doc(fd, renderer)
        return mapOf("id" to id, "sizes" to sizes)
    }

    private fun render(id: Int, index: Int, requestedWidth: Int): ByteArray {
        val doc = docs[id] ?: throw IllegalStateException("Dokumen sudah ditutup")
        val page = doc.renderer.openPage(index)
        try {
            var width = requestedWidth
            var height = (width.toDouble() * page.height / page.width).toInt().coerceAtLeast(1)
            // Batasi ~6 MP supaya tidak kehabisan memori di HP murah.
            val pixels = width.toLong() * height
            if (pixels > MAX_PIXELS) {
                val scale = sqrt(MAX_PIXELS.toDouble() / pixels)
                width = (width * scale).toInt().coerceAtLeast(1)
                height = (height * scale).toInt().coerceAtLeast(1)
            }
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
            bitmap.recycle()
            return out.toByteArray()
        } finally {
            page.close()
        }
    }

    private fun close(id: Int) {
        docs.remove(id)?.let {
            it.renderer.close()
            it.fd.close()
        }
    }

    fun closeAll() {
        executor.execute {
            docs.keys.toList().forEach { close(it) }
        }
    }

    companion object {
        private const val MAX_PIXELS = 6_000_000L
    }
}
