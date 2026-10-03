package com.ramdsoft.viernes.wakeword

import org.json.JSONObject
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer

/**
 * Detector de la palabra de activación. Recibe audio PCM de 16 bits, mono,
 * a 16 kHz.
 *
 * Hoy lo implementa Vosk limitado a una sola palabra. En la fase de IA propia
 * se agrega un motor openWakeWord con un modelo entrenado para "Viernes" que
 * cumple esta misma interfaz.
 */
interface WakeWordEngine : AutoCloseable {
    /** Devuelve la confianza (0–1) si en este bloque se detectó la palabra. */
    fun process(buffer: ShortArray, length: Int): Float?

    fun reset()

    companion object {
        const val SAMPLE_RATE = 16000
    }
}

/**
 * Reconocimiento sin internet con una gramática de una sola palabra: todo lo
 * que no sea "viernes" cae en "[unk]".
 */
class VoskWakeWordEngine(
    modelPath: String,
    private val keyword: String = "viernes",
) : WakeWordEngine {

    private val model: Model
    private val recognizer: Recognizer

    init {
        LibVosk.setLogLevel(LogLevel.WARNINGS)
        model = Model(modelPath)
        recognizer = Recognizer(
            model,
            WakeWordEngine.SAMPLE_RATE.toFloat(),
            "[\"$keyword\", \"[unk]\"]",
        ).apply { setWords(true) }
    }

    override fun process(buffer: ShortArray, length: Int): Float? {
        if (!recognizer.acceptWaveForm(buffer, length)) return null
        return confidenceOf(recognizer.result)
    }

    private fun confidenceOf(json: String): Float? {
        val words = JSONObject(json).optJSONArray("result") ?: return null
        for (i in 0 until words.length()) {
            val word = words.getJSONObject(i)
            if (word.optString("word") == keyword) {
                return word.optDouble("conf", 0.0).toFloat()
            }
        }
        return null
    }

    override fun reset() = recognizer.reset()

    override fun close() {
        recognizer.close()
        model.close()
    }
}
