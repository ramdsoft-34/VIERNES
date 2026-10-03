package com.ramdsoft.viernes.wakeword

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class SpeakerVerifierTest {

    private fun tone(hz: Double, seconds: Double, amplitude: Double = 6000.0) =
        ShortArray((16000 * seconds).toInt()) {
            val t = it / 16000.0
            // Tono con armónicos, parecido a una vocal.
            (amplitude * (Math.sin(2 * Math.PI * hz * t) +
                0.5 * Math.sin(4 * Math.PI * hz * t) +
                0.25 * Math.sin(6 * Math.PI * hz * t)) / 1.75).toInt().toShort()
        }

    @Test
    fun silenceIsRejected() {
        val result = SpeakerVerifier.analyze(ShortArray(32000))
        assertNull(result.print)
        assertEquals(SpeakerVerifier.Rejection.QUIET, result.rejection)
    }

    @Test
    fun pitchOfAToneIsFound() {
        val audio = ShortArray(8000) + tone(200.0, 1.0) + ShortArray(8000)
        val print = SpeakerVerifier.analyze(audio).print
        assertNotNull(print)
        // 200 Hz = 12 semitonos sobre 100 Hz.
        assertEquals(12f, print!!.pitch, 0.6f)
    }

    /**
     * Con voces sintéticas de Windows (variable VIERNES_VOICES, ver
     * `tool/voice_samples/README.md`): se registra una voz con
     * cinco grabaciones y se mide cuántas veces acepta a esa voz y a otras.
     * Se salta si no están las muestras.
     */
    @Test
    fun distinguishesVoices() {
        val dir = File(System.getenv("VIERNES_VOICES") ?: "")
        assumeTrue(dir.isDirectory)
        fun load(name: String, i: Int, noisy: Boolean = false): ShortArray {
            val suffix = if (noisy) "n" else ""
            val bytes = File(dir, "%s_%02d%s.pcm".format(name, i, suffix)).readBytes()
            val shorts = ShortArray(bytes.size / 2)
            ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)
            return shorts
        }
        val voices = listOf("Helena", "Laura", "Pablo")

        // Registro: «Viernes» dicho 5 veces con variaciones naturales.
        val enroll = listOf(1, 5, 9, 14, 23)
        for (owner in voices) {
            val prints = enroll.mapNotNull { SpeakerVerifier.analyze(load(owner, it)).print }
            assertTrue(prints.size >= SpeakerVerifier.MIN_SAMPLES)
            for (strictness in SpeakerVerifier.Strictness.values()) {
                val profile = SpeakerVerifier.Profile(prints, strictness, 0)
                val line = StringBuilder("$owner ${strictness.name.padEnd(7)} umbral=%.2f".format(profile.threshold))
                val withNoise = File(dir, "Helena_01n.pcm").exists()
                for (noisy in listOf(false, true).filter { !it || withNoise }) {
                    line.append(if (noisy) "  | ruido:" else "")
                    for (other in voices) {
                        var accepted = 0
                        var total = 0
                        for (i in 1..45) {
                            if (other == owner && i in enroll) continue
                            val print = SpeakerVerifier.analyze(load(other, i, noisy)).print ?: continue
                            total++
                            if (profile.check(print).accepted) accepted++
                        }
                        val rate = 100 * accepted / total
                        line.append("  $other $rate%")
                        // Sin ruido y con la exigencia normal: acepta al dueño
                        // y rechaza a los demás.
                        if (!noisy && strictness == SpeakerVerifier.Strictness.NORMAL) {
                            if (other == owner) assertTrue(line.toString(), rate >= 70)
                            else assertTrue(line.toString(), rate <= 20)
                        }
                    }
                }
                println(line)
            }
        }
    }
}
