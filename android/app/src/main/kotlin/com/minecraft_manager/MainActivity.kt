package com.mcserver_manager

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "mc_server_manager/update"
        const val PROGRESS_CHANNEL = "mc_server_manager/down_progress"
        const val ARG_URL = "url"
        const val ARG_FILENAME = "filename"

        /** 是否正在下载，防止并发下载到同一文件 */
        val downloading = AtomicBoolean(false)

        /** 下载进度推送事件流（由 Flutter 订阅） */
        val progressSink = AtomicReference<EventChannel.EventSink?>(null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAndInstall" -> {
                    val url = call.argument<String>(ARG_URL)
                    val filename = call.argument<String>(ARG_FILENAME)
                    if (url.isNullOrBlank()) {
                        result.error("BAD_ARGS", "下载地址为空", null)
                    } else if (!downloading.compareAndSet(false, true)) {
                        // 已有下载正在进行，拒绝并发，避免文件写坏
                        result.error("BUSY", "正在下载，请稍候", null)
                    } else {
                        downloadAndInstall(url, filename ?: "latest.apk", result)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROGRESS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink.set(events)
            }

            override fun onCancel(arguments: Any?) {
                progressSink.set(null)
            }
        })
    }

    private fun sendProgress(downloaded: Long, total: Long) {
        val sink = progressSink.get() ?: return
        val percent = if (total > 0) downloaded.toDouble() / total else 0.0
        val payload = HashMap<String, Any>()
        payload["downloaded"] = downloaded
        payload["total"] = total
        payload["percent"] = percent
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            runCatching { sink.success(payload) }
        }
    }

    private fun downloadAndInstall(
        url: String,
        filename: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                val dir = File(cacheDir, "apk").apply { mkdirs() }
                val file = File(dir, filename)
                // 删除旧的半成品/残留文件，保证安装的是最新完整文件
                file.delete()

                val connection = java.net.URL(url).openConnection()
                connection.setRequestProperty("User-Agent", "MCServerManager")
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                val total = connection.contentLengthLong

                val buffer = ByteArray(8 * 1024)
                var downloaded = 0L
                var lastSent = 0L
                connection.inputStream.use { input ->
                    file.outputStream().use { output ->
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            downloaded += read
                            // 每约 256KB 推送一次进度，避免高频回调卡顿
                            if (downloaded - lastSent >= 256 * 1024 || downloaded >= total) {
                                sendProgress(downloaded, total)
                                lastSent = downloaded
                            }
                        }
                    }
                }
                // 确保最终 100% 进度已推送
                if (lastSent < downloaded) {
                    sendProgress(downloaded, total)
                }

                if (file.length() == 0L) {
                    file.delete()
                    runOnUiThread { result.error("DOWNLOAD_FAILED", "下载文件为空", null) }
                    return@Thread
                }

                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file,
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
                runOnUiThread { result.success(null) }
            } catch (e: ActivityNotFoundException) {
                runOnUiThread { result.error("INSTALL_NOT_FOUND", "未找到可用的安装器", e.message) }
            } catch (e: Exception) {
                runOnUiThread { result.error("DOWNLOAD_FAILED", "下载失败：${e.message}", null) }
            } finally {
                downloading.set(false)
            }
        }.start()
    }
}