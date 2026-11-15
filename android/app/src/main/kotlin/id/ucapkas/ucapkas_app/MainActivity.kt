package id.ucapkas.ucapkas_app

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "id.ucapkas.app/audio_recorder"
    private val micPermRequestCode = 9012
    private var mediaRecorder: MediaRecorder? = null
    private var currentOutputPath: String? = null
    private var pendingPermResult: MethodChannel.Result? = null

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
