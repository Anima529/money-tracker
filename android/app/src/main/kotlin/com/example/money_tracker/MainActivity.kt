package com.example.money_tracker

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "money_tracker/backup_files"
    private val openRequest = 4101
    private val saveRequest = 4102
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (pendingResult != null) {
                    result.error("busy", "文件选择器正在使用", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "open" -> {
                            pendingResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/zip"
                                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "application/octet-stream"))
                            }
                            startActivityForResult(intent, openRequest)
                        }
                        "save" -> {
                            val bytes = call.argument<ByteArray>("bytes")
                                ?: throw IllegalArgumentException("缺少备份内容")
                            val name = call.argument<String>("name") ?: "money-tracker-backup.zip"
                            pendingResult = result
                            pendingBytes = bytes
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/zip"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                            startActivityForResult(intent, saveRequest)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    pendingResult = null
                    pendingBytes = null
                    result.error("file_error", error.message, null)
                }
            }
    }

    @Deprecated("Used for Android document picker results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != openRequest && requestCode != saveRequest) return
        val result = pendingResult ?: return
        pendingResult = null
        try {
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result.success(null)
                return
            }
            val uri = data.data!!
            if (requestCode == openRequest) {
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val output = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > 50 * 1024 * 1024) {
                            throw IllegalArgumentException("备份文件超过 50 MB")
                        }
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: throw IllegalStateException("无法读取备份文件")
                result.success(bytes)
            } else {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(pendingBytes!!) }
                    ?: throw IllegalStateException("无法写入备份文件")
                result.success(true)
            }
        } catch (error: Exception) {
            result.error("file_error", error.message, null)
        } finally {
            pendingBytes = null
        }
    }
}
