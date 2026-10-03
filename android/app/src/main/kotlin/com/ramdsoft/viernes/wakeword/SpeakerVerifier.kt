package com.ramdsoft.viernes.wakeword

import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.sqrt
import org.json.JSONArray
import org.json.JSONObject

/**
 * Reconoce si quien dijo «Viernes» es la persona que registró su voz.
 *
 * Huella de voz sencilla y sin internet: de cada grabación se toman los
 * coeficientes cepstrales (MFCC, la forma del tracto vocal) de los tramos con
 * voz, su promedio y su variación (38 valores), y el tono (frecuencia
 * fundamental). Al registrar la voz se guardan varias huellas; al activar se
 * compara la nueva con ellas.
 *
 * El umbral se calibra con las propias grabaciones del registro (dejando una
 * fuera cada vez), así se adapta a la voz y al micrófono de cada teléfono.
 *
 * No es una verificación biométrica de seguridad: distingue bien voces
 * distintas (sobre todo de otro tono), pero alguien con una voz muy parecida
 * podría pasar. Solo decide si Viernes se abre o no.
 */
object SpeakerVerifier {

    private const val SAMPLE_RATE = 16000
    private const val FRAME = 400 // 25 ms
    private const val HOP = 160 // 10 ms
    private const val FFT = 512
    private const val MELS = 40
    private const val CEPS = 19 // c1…c19 (sin c0, que es el volumen)

    /** Máximo de tramos que se guardan por grabación (los más fuertes). */
    private const val MAX_FRAMES = 90

    /** Mínimo de tramos con voz (≈ 0,2 s) para que la huella sirva. */
    private const val MIN_VOICED = 20

    /** Tramos con voz: hasta 30 dB por debajo del más fuerte… */
    private const val DYNAMIC_DB = 30.0

    /** …al menos esto por encima del ruido de fondo… */
    private const val ABOVE_NOISE_DB = 9.0

    /** …y nunca por debajo de este volumen (RMS en int16). */
    private const val MIN_RMS = 120.0

    const val MIN_SAMPLES = 3
    private const val PROFILE_FILE = "voice_profile.json"

    // --- Huella de una grabación --------------------------------------------

    /**
     * Huella de voz de una grabación: los MFCC de cada tramo con voz
     * ([frames], 19 valores cada uno) y el tono típico ([pitch]).
     */
    class Print(val frames: List<FloatArray>, val pitch: Float) {
        fun toJson(): JSONObject = JSONObject()
            .put(
                "f",
                JSONArray(frames.map { f -> JSONArray(f.map { (it * 1000).toInt() / 1000.0 }) }),
            )
            .put("p", if (pitch.isNaN()) JSONObject.NULL else pitch.toDouble())

        companion object {
            fun fromJson(json: JSONObject): Print {
                val array = json.getJSONArray("f")
                val frames = List(array.length()) { i ->
                    val row = array.getJSONArray(i)
                    FloatArray(row.length()) { row.getDouble(it).toFloat() }
                }
                val pitch = if (json.isNull("p")) Float.NaN else json.getDouble("p").toFloat()
                return Print(frames, pitch)
            }
        }
    }

    enum class Rejection { NONE, QUIET, SHORT }

    class Analysis(val print: Print?, val rejection: Rejection)

    private val window = FloatArray(FRAME) { (0.54 - 0.46 * cos(2 * PI * it / (FRAME - 1))).toFloat() }
    private val filters = melFilters()
    private val dct = Array(CEPS) { k ->
        FloatArray(MELS) { m -> cos(PI * (k + 1) * (m + 0.5) / MELS).toFloat() }
    }

    fun analyze(audio: ShortArray, length: Int = audio.size): Analysis {
        val n = minOf(length, audio.size)
        if (n < FRAME * 4) return Analysis(null, Rejection.SHORT)
        val frames = (n - FRAME) / HOP + 1
        val energyDb = DoubleArray(frames)
        val rms = DoubleArray(frames)
        for (f in 0 until frames) {
            var sum = 0.0
            val start = f * HOP
            for (i in 0 until FRAME) {
                val v = audio[start + i].toDouble()
                sum += v * v
            }
            rms[f] = sqrt(sum / FRAME)
            energyDb[f] = 10 * log10(sum / FRAME + 1e-9)
        }
        val loudest = energyDb.maxOrNull() ?: return Analysis(null, Rejection.QUIET)
        // Ruido de fondo: el nivel de los tramos más bajos. La voz tiene que
        // sobresalir de él (si no, se compararía el ruido y no la voz).
        val floor = energyDb.sorted()[frames / 5]
        val voiced = (0 until frames).filter {
            energyDb[it] >= loudest - DYNAMIC_DB &&
                energyDb[it] >= floor + ABOVE_NOISE_DB &&
                rms[it] >= MIN_RMS
        }.sortedByDescending { energyDb[it] }.take(MAX_FRAMES).sorted()
        if (voiced.isEmpty()) return Analysis(null, Rejection.QUIET)
        if (voiced.size < MIN_VOICED) return Analysis(null, Rejection.SHORT)

        val prints = ArrayList<FloatArray>(voiced.size)
        val re = FloatArray(FFT)
        val im = FloatArray(FFT)
        val logMel = FloatArray(MELS)
        for (f in voiced) {
            val start = f * HOP
            re.fill(0f)
            im.fill(0f)
            var previous = if (start > 0) audio[start - 1] / 32768f else 0f
            for (i in 0 until FRAME) {
                val x = audio[start + i] / 32768f
                re[i] = (x - 0.97f * previous) * window[i]
                previous = x
            }
            fft(re, im)
            for (m in 0 until MELS) {
                var e = 0.0
                val filter = filters[m]
                for (k in filter.indices) {
                    val w = filter[k]
                    if (w > 0f) e += w * (re[k] * re[k] + im[k] * im[k])
                }
                logMel[m] = ln(e + 1e-10).toFloat()
            }
            prints += FloatArray(CEPS) { k ->
                var c = 0.0
                val basis = dct[k]
                for (m in 0 until MELS) c += basis[m] * logMel[m]
                c.toFloat()
            }
        }
        return Analysis(Print(prints, pitchOf(audio, n, voiced)), Rejection.NONE)
    }

    /**
     * Tono típico en semitonos sobre 100 Hz (mediana de los tramos con voz
     * claramente periódica), o NaN si no se distingue.
     */
    private fun pitchOf(audio: ShortArray, n: Int, voiced: List<Int>): Float {
        val window = 640 // 40 ms: cabe un periodo de 60 Hz con margen
        val minLag = SAMPLE_RATE / 400
        val maxLag = SAMPLE_RATE / 60
        val semitones = ArrayList<Float>()
        for (f in voiced) {
            val start = f * HOP
            if (start + window + maxLag > n) continue
            var energy = 0.0
            for (i in 0 until window) {
                val v = audio[start + i].toDouble()
                energy += v * v
            }
            if (energy <= 0) continue
            val acf = DoubleArray(maxLag + 1)
            var best = 0.0
            for (lag in minLag..maxLag) {
                var sum = 0.0
                var lagged = 0.0
                for (i in 0 until window) {
                    val a = audio[start + i].toDouble()
                    val b = audio[start + i + lag].toDouble()
                    sum += a * b
                    lagged += b * b
                }
                acf[lag] = sum / sqrt(energy * lagged + 1e-9)
                if (acf[lag] > best) best = acf[lag]
            }
            // El periodo más corto con un pico casi tan alto como el mejor:
            // evita confundir el tono con su octava baja (2, 3 periodos).
            var bestLag = -1
            for (lag in minLag + 1 until maxLag) {
                if (acf[lag] >= best * 0.9 && acf[lag] >= acf[lag - 1] && acf[lag] >= acf[lag + 1]) {
                    bestLag = lag
                    break
                }
            }
            if (bestLag > 0 && best >= 0.4) {
                val hz = SAMPLE_RATE.toFloat() / bestLag
                semitones += (12 * log2(hz / 100f))
            }
        }
        if (semitones.size < 5) return Float.NaN
        semitones.sort()
        return semitones[semitones.size / 2]
    }

    // --- Perfil ----------------------------------------------------------------

    /** Qué tan exigente es: más exigente rechaza más a otras personas, pero
     * también puede rechazar al dueño si habla distinto (resfriado, lejos). */
    enum class Strictness(val distanceFactor: Double, val pitchTolerance: Double) {
        RELAXED(1.35, 6.0),
        NORMAL(1.2, 4.5),
        STRICT(1.0, 3.5),
    }

    /**
     * Perfil de la voz registrada. Cada tramo de una grabación nueva se
     * compara con el tramo más parecido de las grabaciones del registro
     * (cuantización vectorial, el método clásico para pocas palabras): una
     * misma voz encuentra tramos muy parecidos; otra voz, no.
     */
    class Profile(
        val prints: List<Print>,
        val strictness: Strictness,
        val createdAt: Long,
    ) {
        /** Escala de cada coeficiente (su variación en la voz registrada). */
        private val scale = FloatArray(CEPS)
        private val baseThreshold: Double
        private val pitchRef: Float

        init {
            val all = prints.flatMap { it.frames }
            for (k in 0 until CEPS) {
                var sum = 0.0
                var squares = 0.0
                for (f in all) {
                    sum += f[k]
                    squares += f[k] * f[k]
                }
                val mean = sum / all.size
                scale[k] = sqrt(max(squares / all.size - mean * mean, 1e-6)).toFloat()
            }
            // Umbral: qué tan lejos queda cada grabación del registro de las
            // demás. Lo normal de esta voz, con margen.
            val distances = prints.indices.map { i ->
                score(prints[i].frames, prints.filterIndexed { j, _ -> j != i }.flatMap { it.frames })
            }
            val avg = distances.average()
            val sd = sqrt(distances.map { (it - avg) * (it - avg) }.average())
            baseThreshold = maxOf(avg + 2 * sd, distances.maxOrNull() ?: 0.0)
            val pitches = prints.map { it.pitch }.filter { !it.isNaN() }.sorted()
            pitchRef = if (pitches.size >= 2) pitches[pitches.size / 2] else Float.NaN
        }

        val threshold: Double get() = baseThreshold * strictness.distanceFactor

        class Check(val accepted: Boolean, val distance: Double, val threshold: Double, val pitchDiff: Float) {
            /** 1 = idéntico; 0 = en el límite o más lejos. */
            val similarity: Double get() = (1 - distance / (threshold * 1.6)).coerceIn(0.0, 1.0)
        }

        fun check(print: Print): Check {
            val d = score(print.frames, prints.flatMap { it.frames })
            val pitchDiff = if (pitchRef.isNaN() || print.pitch.isNaN()) {
                Float.NaN
            } else {
                kotlin.math.abs(print.pitch - pitchRef)
            }
            val pitchOk = pitchDiff.isNaN() || pitchDiff <= strictness.pitchTolerance
            val limit = if (pitchDiff.isNaN()) threshold * UNKNOWN_PITCH_FACTOR else threshold
            return Check(d <= limit && pitchOk, d, limit, pitchDiff)
        }

        /** Distancia media de cada tramo al más parecido del registro (sin el
         * 10 % peor: golpes, respiración). */
        private fun score(frames: List<FloatArray>, reference: List<FloatArray>): Double {
            val nearest = frames.map { f ->
                var best = Double.MAX_VALUE
                for (r in reference) {
                    var sum = 0.0
                    for (k in 0 until CEPS) {
                        val z = (f[k] - r[k]) / scale[k]
                        sum += z * z
                        if (sum >= best) break
                    }
                    if (sum < best) best = sum
                }
                sqrt(best / CEPS)
            }.sorted()
            val kept = nearest.take(max(1, (nearest.size * 0.9).toInt()))
            return kept.average()
        }

        fun withStrictness(value: Strictness) = Profile(prints, value, createdAt)

        fun toJson(): JSONObject = JSONObject()
            .put("version", 2)
            .put("strictness", strictness.name)
            .put("createdAt", createdAt)
            .put("prints", JSONArray(prints.map { it.toJson() }))

        companion object {
            /** Sin tono claro (ruido, susurro) se exige más parecido. */
            private const val UNKNOWN_PITCH_FACTOR = 0.85

            fun fromJson(json: JSONObject): Profile? {
                if (json.optInt("version") != 2) return null
                val array = json.getJSONArray("prints")
                return Profile(
                    prints = List(array.length()) { Print.fromJson(array.getJSONObject(it)) },
                    strictness = runCatching {
                        Strictness.valueOf(json.optString("strictness"))
                    }.getOrDefault(Strictness.NORMAL),
                    createdAt = json.optLong("createdAt"),
                )
            }
        }
    }

    // --- Archivo -----------------------------------------------------------------

    private fun file(dir: File) = File(dir, PROFILE_FILE)

    fun load(dir: File): Profile? = runCatching {
        val f = file(dir)
        if (!f.exists()) null else Profile.fromJson(JSONObject(f.readText()))
    }.getOrNull()?.takeIf { it.prints.size >= MIN_SAMPLES }

    fun save(dir: File, profile: Profile) {
        val target = file(dir)
        val temp = File(dir, "$PROFILE_FILE.tmp")
        temp.writeText(profile.toJson().toString())
        if (!temp.renameTo(target)) {
            target.delete()
            temp.renameTo(target)
        }
    }

    fun delete(dir: File) {
        file(dir).delete()
    }

    // --- Utilidades --------------------------------------------------------------

    private fun melFilters(): Array<FloatArray> {
        fun hzToMel(hz: Double) = 2595 * log10(1 + hz / 700)
        fun melToHz(mel: Double) = 700 * (Math.pow(10.0, mel / 2595) - 1)
        val low = hzToMel(80.0)
        val high = hzToMel(7600.0)
        val points = DoubleArray(MELS + 2) { melToHz(low + (high - low) * it / (MELS + 1)) }
        val bins = points.map { (it / SAMPLE_RATE * FFT).toInt().coerceIn(0, FFT / 2) }
        return Array(MELS) { m ->
            val filter = FloatArray(FFT / 2 + 1)
            val left = bins[m]
            val center = max(bins[m + 1], left + 1)
            val right = max(bins[m + 2], center + 1)
            for (k in left until center) filter[k] = (k - left).toFloat() / (center - left)
            for (k in center until minOf(right, FFT / 2 + 1)) {
                filter[k] = (right - k).toFloat() / (right - center)
            }
            filter
        }
    }

    /** FFT radix 2 en el lugar. */
    private fun fft(re: FloatArray, im: FloatArray) {
        val n = re.size
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j xor bit
            if (i < j) {
                val tr = re[i]; re[i] = re[j]; re[j] = tr
                val ti = im[i]; im[i] = im[j]; im[j] = ti
            }
        }
        var len = 2
        while (len <= n) {
            val angle = -2 * PI / len
            val wr = cos(angle).toFloat()
            val wi = kotlin.math.sin(angle).toFloat()
            var i = 0
            while (i < n) {
                var cr = 1f
                var ci = 0f
                for (k in 0 until len / 2) {
                    val a = i + k
                    val b = a + len / 2
                    val xr = re[b] * cr - im[b] * ci
                    val xi = re[b] * ci + im[b] * cr
                    re[b] = re[a] - xr
                    im[b] = im[a] - xi
                    re[a] += xr
                    im[a] += xi
                    val nr = cr * wr - ci * wi
                    ci = cr * wi + ci * wr
                    cr = nr
                }
                i += len
            }
            len = len shl 1
        }
    }
}
