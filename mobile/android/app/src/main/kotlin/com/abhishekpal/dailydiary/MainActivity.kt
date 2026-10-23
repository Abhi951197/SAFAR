package com.abhishekpal.dailydiary

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity: FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var source: File? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safar/backups").setMethodCallHandler { call, result ->
            if (pending != null) { result.error("busy", "A file picker is already open.", null); return@setMethodCallHandler }
            when(call.method) {
                "saveBackup" -> {
                    val file = File(call.argument<String>("path") ?: "").canonicalFile
                    if (!file.path.startsWith(File(applicationInfo.dataDir).canonicalPath + "/") || !file.isFile) {
                        result.error("path", "Backup file is unavailable.", null); return@setMethodCallHandler
                    }
                    source = file; pending = result
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "Safar.safar")
                    }
                    try { startActivityForResult(intent, 4811) } catch(e: Exception) { pending=null; source=null; result.error("picker",e.message,null) }
                }
                "pickBackup" -> {
                    pending = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type = "*/*" }
                    try { startActivityForResult(intent, 4812) } catch(e: Exception) { pending=null; result.error("picker",e.message,null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if(requestCode != 4811 && requestCode != 4812) return
        val result = pending ?: return
        val file = source
        val uri = data?.data
        if(resultCode != Activity.RESULT_OK || uri == null) { pending=null; source=null; result.success(if(requestCode == 4811) false else null); return }
        Thread {
            var temporary: File? = null
            try {
                val value: Any = if(requestCode == 4811) {
                    val input = file ?: throw IllegalStateException("Backup unavailable")
                    contentResolver.openOutputStream(uri, "wt")?.use { output -> input.inputStream().use { it.copyTo(output) } }
                        ?: throw IllegalStateException("Cannot write selected location")
                    true
                } else {
                    val target = File(cacheDir,"safar-restore-${UUID.randomUUID()}.safar")
                    temporary = target
                    contentResolver.openInputStream(uri)?.use { input -> target.outputStream().use { input.copyTo(it) } }
                        ?: throw IllegalStateException("Cannot read selected file")
                    target.absolutePath
                }
                runOnUiThread { pending=null; source=null; result.success(value) }
            } catch(e: Exception) {
                temporary?.delete()
                runOnUiThread { pending=null; source=null; result.error("file",e.message,null) }
            }
        }.start()
    }
}
