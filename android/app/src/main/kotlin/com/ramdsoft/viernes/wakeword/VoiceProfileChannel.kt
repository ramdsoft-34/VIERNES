package com.ramdsoft.viernes.wakeword

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.sqrt

/**
 * Registro de la voz del dueño (canal `com.ramdsoft.viernes/voice_profile`).
 *
 * Graba unos segundos con el micrófono, calcula la huella
 * ([SpeakerVerifier]) y la guarda solo en este teléfono
 * (`files/voice_profile.json`): la voz nunca sale del teléfono ni se sube a
 * la cuenta. [WakeWordService] la lee para decidir si quien dijo «Viernes»
 * es el dueño.
 */
class VoiceProfileChannel(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Huellas grabadas en este registro (aún sin guardar). */
    private val pending = ArrayList<SpeakerVerifier.Print>()

    init {
        channel.setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "startEnrollment" -> {
                pending.clear()
                result.success(null)
            }
            "recordSample" -> record(call.argument<Int>("ms") ?: 2500, result) { audio, level ->
                val analysis = SpeakerVerifier.analyze(audio)
                val print = analysis.print
                if (print != null) pending += print
                mapOf(
                    "ok" to (print != null),
                    "reason" to analysis.rejection.name.lowercase(),
                    "count" to pending.size,
                    "level" to level,
                )
            }
            "finishEnrollment" -> {
                if (pending.size < SpeakerVerifier.MIN_SAMPLES) {
                    result.success(false)
                    return
                }
                val strictness = SpeakerVerifier.load(context.filesDir)?.strictness
                    ?: SpeakerVerifier.Strictness.NORMAL
                SpeakerVerifier.save(
                    context.filesDir,
                    SpeakerVerifier.Profile(pending.toList(), strictness, System.currentTimeMillis()),
                )
                pending.clear()
                WakeWordService.reloadVoiceProfile()
                result.success(true)
            }
            "testSample" -> {
                val profile = SpeakerVerifier.load(context.filesDir)
                if (profile == null) {
                    result.success(mapOf("ok" to false, "reason" to "noProfile"))
                    return
                }
                record(call.argument<Int>("ms") ?: 2500, result) { audio, _ ->
                    val analysis = SpeakerVerifier.analyze(audio)
                    val print = analysis.print
                    if (print == null) {
                        mapOf("ok" to false, "reason" to analysis.rejection.name.lowercase())
                    } else {
                        val check = profile.check(print)
                        mapOf(
                            "ok" to true,
                            "accepted" to check.accepted,
                            "similarity" to check.similarity,
                        )
                    }
                }
            }
            "setStrictness" -> {
                val profile = SpeakerVerifier.load(context.filesDir)
                val value = runCatching {
                    SpeakerVerifier.Strictness.valueOf(call.argument<String>("value").orEmpty())
                }.getOrNull()
                if (profile != null && value != null) {
                    SpeakerVerifier.save(context.filesDir, profile.withStrictness(value))
                    WakeWordService.reloadVoiceProfile()
                }
                result.success(null)
            }
            "delete" -> {
                SpeakerVerifier.delete(context.filesDir)
                pending.clear()
                WakeWordService.reloadVoiceProfile()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun status(): Map<String, Any?> {
        val profile = SpeakerVerifier.load(context.filesDir)
        val (accepted, rejected) = WakeWordService.voiceCounts(context)
        return mapOf(
            "enrolled" to (profile != null),
            "accepted" to accepted,
            "rejected" to rejected,
            "samples" to (profile?.prints?.size ?: 0),
            "strictness" to profile?.strictness?.name,
            "createdAt" to profile?.createdAt,
        )
    }

    /**
     * Graba [ms] milisegundos en otro hilo y responde con [analyze]. El
     * servicio de «Viernes» suelta el micrófono antes (lo pide Flutter).
     */
    private fun record(
        ms: Int,
        result: MethodChannel.Result,
        analyze: (ShortArray, Double) -> Map<String, Any?>,
    ) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(mapOf("ok" to false, "reason" to "permission"))
            return
        }
        worker.execute {
            val reply = try {
                val audio = capture(ms.coerceIn(800, 6000))
                var sum = 0.0
                for (v in audio) sum += v.toDouble() * v
                val level = sqrt(sum / audio.size.coerceAtLeast(1))
                analyze(audio, level)
            } catch (error: Exception) {
                mapOf("ok" to false, "reason" to "error", "message" to error.message)
            }
            main.post { result.success(reply) }
        }
    }

    @Suppress("MissingPermission") // Revisado en record().
    private fun capture(ms: Int): ShortArray {
        val rate = WakeWordEngine.SAMPLE_RATE
        val total = rate * ms / 1000
        val minBuffer = AudioRecord.getMinBufferSize(
            rate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            rate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuffer, 4096),
        )
        val audio = ShortArray(total)
        try {
            recorder.startRecording()
            var read = 0
            while (read < total) {
                val n = recorder.read(audio, read, minOf(2048, total - read))
                if (n <= 0) break
                read += n
            }
        } finally {
            runCatching { recorder.stop() }
            recorder.release()
        }
        return audio
    }

    companion object {
        const val CHANNEL = "com.ramdsoft.viernes/voice_profile"
    }
}
