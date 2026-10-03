package com.ramdsoft.viernes.wakeword

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Escribe audio PCM de 16 bits, mono, como WAV. */
object WavWriter {
    fun write(file: File, samples: ShortArray, sampleRate: Int) {
        val dataBytes = samples.size * 2
        val buffer = ByteBuffer.allocate(44 + dataBytes).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray())
        buffer.putInt(36 + dataBytes)
        buffer.put("WAVE".toByteArray())
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16) // tamaño del bloque fmt
        buffer.putShort(1) // PCM
        buffer.putShort(1) // mono
        buffer.putInt(sampleRate)
        buffer.putInt(sampleRate * 2) // bytes por segundo
        buffer.putShort(2) // bytes por muestra
        buffer.putShort(16) // bits por muestra
        buffer.put("data".toByteArray())
        buffer.putInt(dataBytes)
        for (sample in samples) buffer.putShort(sample)
        file.writeBytes(buffer.array())
    }
}
