package com.ramdsoft.viernes.wakeword

import android.content.Context
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.max
import kotlin.math.sqrt
import kotlin.random.Random
import org.tensorflow.lite.Interpreter

/**
 * Detector propio de "Viernes" con la arquitectura de openWakeWord:
 *
 *   audio 16 kHz → melspectrogram.tflite → embedding_model.tflite (96 valores
 *   cada 80 ms) → viernes.tflite (últimos 16 embeddings → probabilidad)
 *
 * Los dos primeros modelos son los de openWakeWord; el último se entrena con
 * `training/wake_word/train_wakeword.py`. Pesa ~1,5 MB en total, viene dentro
 * del APK (no se descarga) y gasta mucho menos que un reconocedor completo.
 *
 * El flujo replica `openwakeword.utils.AudioFeatures` en modo streaming para
 * que el teléfono calcule exactamente lo mismo que en el entrenamiento.
 *
 * Ahorro de batería: tras más de 1,3 s de silencio (el largo de la ventana
 * del clasificador) no se ejecutan el modelo de embeddings ni el
 * clasificador; se repite el último embedding de silencio. Con el primer
 * sonido fuerte vuelve a analizar todo, así que la palabra no se pierde.
 */
class OpenWakeWordEngine(
    context: Context,
    assetDir: String = DEFAULT_ASSET_DIR,
    /** Por debajo de esto no se informa nada (evita ruido en el registro). */
    private val reportFrom: Float = 0.2f,
) : WakeWordEngine {

    private val melspec = Interpreter(load(context, "$assetDir/melspectrogram.tflite"))
    private val embedding = Interpreter(load(context, "$assetDir/embedding_model.tflite"))
    private val classifier = Interpreter(load(context, "$assetDir/viernes.tflite"))

    /** Últimas muestras de audio (como valores int16, sin normalizar). */
    private val raw = FloatArray(CHUNK + MEL_CONTEXT)
    private val pending = FloatArray(CHUNK)
    private var pendingCount = 0

    /** Melspectrograma: últimas [MEL_WINDOW] filas de 32 bandas. */
    private val mel = ArrayDeque<FloatArray>()

    /** Embeddings: últimos [FEATURES] vectores de 96 valores. */
    private val features = ArrayDeque<FloatArray>()

    private val melInput = Array(1) { FloatArray(CHUNK + MEL_CONTEXT) }
    private val melOutput: Array<Array<Array<FloatArray>>>
    private val embInput = Array(1) { Array(MEL_WINDOW) { Array(MEL_BANDS) { FloatArray(1) } } }
    private val embOutput = Array(1) { Array(1) { Array(1) { FloatArray(EMBEDDING) } } }
    private val clsInput = Array(1) { Array(FEATURES) { FloatArray(EMBEDDING) } }
    private val clsOutput = Array(1) { FloatArray(1) }

    /** Cifras de consumo (las lee el servicio y las reinicia). */
    var frames = 0L
        private set
    var skippedFrames = 0L
        private set
    var inferenceNanos = 0L
        private set
    var inferences = 0L
        private set

    /** Nivel de ruido de fondo (RMS de muestras int16). */
    private var noiseFloor = INITIAL_NOISE
    private var quietRun = 0
    private var silenceEmbedding: FloatArray? = null
    private var gate = false

    fun takeStats(): LongArray {
        val values = longArrayOf(frames, skippedFrames, inferenceNanos, inferences)
        frames = 0
        skippedFrames = 0
        inferenceNanos = 0
        inferences = 0
        return values
    }

    init {
        melspec.resizeInput(0, intArrayOf(1, CHUNK + MEL_CONTEXT))
        melspec.allocateTensors()
        val shape = melspec.getOutputTensor(0).shape() // [1, 1, frames, 32]
        melOutput = Array(shape[0]) { Array(shape[1]) { Array(shape[2]) { FloatArray(shape[3]) } } }
        reset()
    }

    override fun process(buffer: ShortArray, length: Int): Float? {
        var best: Float? = null
        for (i in 0 until length) {
            pending[pendingCount++] = buffer[i].toFloat()
            if (pendingCount == CHUNK) {
                pendingCount = 0
                val score = step(pending)
                if (score >= reportFrom && (best == null || score > best)) best = score
            }
        }
        return best
    }

    /** Procesa 80 ms de audio y devuelve la probabilidad de "Viernes". */
    private fun step(chunk: FloatArray): Float {
        // Desplaza el búfer y agrega el bloque nuevo (con 30 ms de contexto).
        System.arraycopy(raw, CHUNK, raw, 0, MEL_CONTEXT)
        System.arraycopy(chunk, 0, raw, MEL_CONTEXT, CHUNK)

        System.arraycopy(raw, 0, melInput[0], 0, raw.size)
        melspec.run(melInput, melOutput)
        for (frame in melOutput[0][0]) {
            mel.addLast(FloatArray(MEL_BANDS) { frame[it] / 10f + 2f })
            if (mel.size > MEL_WINDOW) mel.removeFirst()
        }

        val quiet = isQuiet(chunk)
        if (gate) frames++
        val cached = silenceEmbedding
        if (gate && quietRun > FEATURES && cached != null) {
            // Silencio largo: la ventana entera es silencio, no hay palabra.
            features.addLast(cached.copyOf())
            if (features.size > FEATURES) features.removeFirst()
            skippedFrames++
            return 0f
        }

        val started = System.nanoTime()
        for (r in 0 until MEL_WINDOW) {
            val row = mel[r]
            for (b in 0 until MEL_BANDS) embInput[0][r][b][0] = row[b]
        }
        embedding.run(embInput, embOutput)
        val current = embOutput[0][0][0].copyOf()
        features.addLast(current)
        if (features.size > FEATURES) features.removeFirst()
        if (quiet) silenceEmbedding = current

        for (f in 0 until FEATURES) {
            System.arraycopy(features[f], 0, clsInput[0][f], 0, EMBEDDING)
        }
        classifier.run(clsInput, clsOutput)
        if (gate) {
            inferenceNanos += System.nanoTime() - started
            inferences++
        }
        return clsOutput[0][0]
    }

    /** Actualiza el ruido de fondo y dice si este bloque es silencio. */
    private fun isQuiet(chunk: FloatArray): Boolean {
        var sum = 0.0
        for (v in chunk) sum += v * v
        val rms = sqrt(sum / chunk.size).toFloat()
        // Baja rápido hacia el silencio; sube muy despacio con el ruido.
        noiseFloor = if (rms < noiseFloor) {
            noiseFloor * 0.9f + rms * 0.1f
        } else {
            noiseFloor * 0.998f + rms * 0.002f
        }
        val quiet = rms < max(noiseFloor * QUIET_FACTOR, MIN_SPEECH_RMS)
        quietRun = if (quiet) quietRun + 1 else 0
        return quiet
    }

    override fun reset() {
        gate = false
        quietRun = 0
        silenceEmbedding = null
        noiseFloor = INITIAL_NOISE
        raw.fill(0f)
        pendingCount = 0
        mel.clear()
        repeat(MEL_WINDOW) { mel.addLast(FloatArray(MEL_BANDS) { 1f }) }
        features.clear()
        repeat(FEATURES) { features.addLast(FloatArray(EMBEDDING)) }
        // Igual que openWakeWord: arranca con 4 s de ruido suave para que los
        // búferes tengan valores realistas desde el primer instante.
        val noise = ShortArray(CHUNK)
        repeat(WARMUP_CHUNKS) {
            for (i in noise.indices) noise[i] = Random.nextInt(-1000, 1000).toShort()
            for (i in 0 until CHUNK) pending[i] = noise[i].toFloat()
            step(pending)
        }
        pendingCount = 0
        // El ruido de arranque no cuenta como silencio real.
        quietRun = 0
        silenceEmbedding = null
        noiseFloor = INITIAL_NOISE
        gate = true
    }

    override fun close() {
        melspec.close()
        embedding.close()
        classifier.close()
    }

    companion object {
        const val DEFAULT_ASSET_DIR = "wakeword"

        /** Ruta que usa Flutter para pedir este motor en vez de Vosk. */
        const val ASSET_PREFIX = "asset:"

        private const val CHUNK = 1280 // 80 ms
        private const val MEL_CONTEXT = 160 * 3
        private const val MEL_BANDS = 32
        private const val MEL_WINDOW = 76
        private const val EMBEDDING = 96
        private const val FEATURES = 16
        private const val WARMUP_CHUNKS = 50

        /** Silencio: menos de 2,5 veces el ruido de fondo… */
        private const val QUIET_FACTOR = 2.5f

        /** …y nunca por encima de esto (voz baja a un par de metros). */
        private const val MIN_SPEECH_RMS = 120f
        private const val INITIAL_NOISE = 200f

        fun isAvailable(context: Context, assetDir: String = DEFAULT_ASSET_DIR): Boolean =
            runCatching { context.assets.list(assetDir)?.contains("viernes.tflite") == true }
                .getOrDefault(false)

        private fun load(context: Context, path: String): MappedByteBuffer {
            context.assets.openFd(path).use { fd ->
                FileInputStream(fd.fileDescriptor).use { stream ->
                    return stream.channel.map(
                        FileChannel.MapMode.READ_ONLY,
                        fd.startOffset,
                        fd.declaredLength,
                    )
                }
            }
        }
    }
}
