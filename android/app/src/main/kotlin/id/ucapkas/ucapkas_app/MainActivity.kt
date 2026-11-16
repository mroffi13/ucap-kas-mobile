package id.ucapkas.ucapkas_app

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "id.ucapkas.app/audio_recorder"
    private val fileSaverChannelName = "id.ucapkas.app/file_saver"
    private val micPermRequestCode = 9012
    private val logoPickRequestCode = 9015
    private var mediaRecorder: MediaRecorder? = null
    private var currentOutputPath: String? = null
    private var pendingPermResult: MethodChannel.Result? = null
    private var pendingLogoResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                        } else {
                            pendingPermResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                micPermRequestCode
                            )
                        }
                    }
                    "start" -> {
                        try {
                            stopRecorderQuietly(deleteFile = true)
                            val outFile = File(
                                cacheDir,
                                "ucapkas_voice_${System.currentTimeMillis()}.m4a"
                            )
                            currentOutputPath = outFile.absolutePath
                            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                MediaRecorder(this)
                            } else {
                                @Suppress("DEPRECATION")
                                MediaRecorder()
                            }
                            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            recorder.setAudioSamplingRate(16000)
                            recorder.setAudioEncodingBitRate(64000)
                            recorder.setAudioChannels(1)
                            recorder.setOutputFile(outFile.absolutePath)
                            recorder.prepare()
                            recorder.start()
                            mediaRecorder = recorder
                            result.success(outFile.absolutePath)
                        } catch (e: Exception) {
                            stopRecorderQuietly(deleteFile = true)
                            result.error("RECORDER_START_ERROR", e.message, null)
                        }
                    }
                    "stop" -> {
                        val path = currentOutputPath
                        stopRecorderQuietly(deleteFile = false)
                        result.success(path)
                    }
                    "cancel" -> {
                        stopRecorderQuietly(deleteFile = true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileSaverChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdf" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")
                            val rawName = call.argument<String>("filename") ?: "invoice.pdf"
                            if (bytes == null || bytes.isEmpty()) {
                                result.error("INVALID_ARGS", "PDF bytes kosong", null)
                                return@setMethodCallHandler
                            }
                            val safeName = rawName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                            val finalName = if (safeName.endsWith(".pdf", ignoreCase = true)) {
                                safeName
                            } else {
                                "$safeName.pdf"
                            }

                            var contentUriStr: String? = null
                            var displayLocation = "Folder Download/$finalName"
                            val cacheOut = File(cacheDir, finalName)
                            FileOutputStream(cacheOut).use { it.write(bytes) }

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val values = ContentValues().apply {
                                    put(MediaStore.Downloads.DISPLAY_NAME, finalName)
                                    put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                                    put(
                                        MediaStore.Downloads.RELATIVE_PATH,
                                        Environment.DIRECTORY_DOWNLOADS + "/UcapKas"
                                    )
                                    put(MediaStore.Downloads.IS_PENDING, 1)
                                }
                                val resolver = applicationContext.contentResolver
                                val uri = resolver.insert(
                                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                    values
                                )
                                if (uri != null) {
                                    resolver.openOutputStream(uri)?.use { out ->
                                        out.write(bytes)
                                        out.flush()
                                    }
                                    values.clear()
                                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                                    resolver.update(uri, values, null, null)
                                    contentUriStr = uri.toString()
                                    displayLocation = "Download/UcapKas/$finalName"
                                }
                            } else {
                                val dir = File(
                                    getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS),
                                    "UcapKas"
                                )
                                if (!dir.exists()) dir.mkdirs()
                                val outFile = File(dir, finalName)
                                FileOutputStream(outFile).use { it.write(bytes) }
                                displayLocation = outFile.absolutePath
                            }

                            result.success(
                                mapOf(
                                    "filePath" to cacheOut.absolutePath,
                                    "displayLocation" to displayLocation,
                                    "contentUri" to contentUriStr
                                )
                            )
                        } catch (e: Exception) {
                            result.error("SAVE_PDF_ERROR", e.message, null)
                        }
                    }
                    "openPdf" -> {
                        try {
                            val contentUriStr = call.argument<String>("contentUri")
                            if (contentUriStr.isNullOrBlank()) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val uri = Uri.parse(contentUriStr)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/pdf")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(Intent.createChooser(intent, "Buka Invoice PDF"))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "sharePdf" -> {
                        try {
                            val contentUriStr = call.argument<String>("contentUri")
                            val text = call.argument<String>("text") ?: ""
                            val title = call.argument<String>("title") ?: "Kirim Invoice PDF"
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                if (!contentUriStr.isNullOrBlank()) {
                                    type = "application/pdf"
                                    putExtra(Intent.EXTRA_STREAM, Uri.parse(contentUriStr))
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                } else {
                                    type = "text/plain"
                                }
                                if (text.isNotEmpty()) {
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                            }
                            startActivity(Intent.createChooser(intent, title))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "pickLogoImage" -> {
                        try {
                            pendingLogoResult = result
                            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                type = "image/*"
                                addCategory(Intent.CATEGORY_OPENABLE)
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(
                                Intent.createChooser(intent, "Pilih Logo Usaha"),
                                logoPickRequestCode
                            )
                        } catch (_: Exception) {
                            pendingLogoResult = null
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == logoPickRequestCode) {
            val cb = pendingLogoResult
            pendingLogoResult = null
            if (cb == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                cb.success(null)
                return
            }
            try {
                val uri = data.data!!
                val rawBitmap = contentResolver.openInputStream(uri)?.use { stream ->
                    BitmapFactory.decodeStream(stream)
                }
                if (rawBitmap == null) {
                    cb.success(null)
                    return
                }
                val side = minOf(rawBitmap.width, rawBitmap.height)
                val xOff = (rawBitmap.width - side) / 2
                val yOff = (rawBitmap.height - side) / 2
                val cropped = Bitmap.createBitmap(rawBitmap, xOff, yOff, side, side)
                val scaled = Bitmap.createScaledBitmap(cropped, 120, 120, true)
                val whiteBg = Bitmap.createBitmap(120, 120, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(whiteBg)
                canvas.drawColor(Color.WHITE)
                canvas.drawBitmap(scaled, 0f, 0f, null)

                val baos = ByteArrayOutputStream()
                whiteBg.compress(Bitmap.CompressFormat.JPEG, 86, baos)
                val b64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
                cb.success("data:image/jpeg;base64,$b64")
            } catch (_: Exception) {
                cb.success(null)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == micPermRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermResult?.success(granted)
            pendingPermResult = null
        }
    }

    private fun stopRecorderQuietly(deleteFile: Boolean) {
        try {
            mediaRecorder?.apply {
                try {
                    stop()
                } catch (_: Exception) {
                }
                reset()
                release()
            }
        } catch (_: Exception) {
        } finally {
            mediaRecorder = null
        }
        if (deleteFile) {
            currentOutputPath?.let {
                try {
                    File(it).delete()
                } catch (_: Exception) {
                }
            }
            currentOutputPath = null
        }
    }

    override fun onDestroy() {
        stopRecorderQuietly(deleteFile = false)
        super.onDestroy()
    }
}
