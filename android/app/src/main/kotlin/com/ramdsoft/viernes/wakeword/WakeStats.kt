package com.ramdsoft.viernes.wakeword

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Process
import android.os.SystemClock

/**
 * Cifras de consumo de la escucha de «Viernes», guardadas en el teléfono:
 * tiempo escuchando, bloques analizados y ahorrados por silencio, tiempo
 * del modelo, procesador y batería gastada mientras escucha (sin cargar).
 */
object WakeStats {
    private const val PREFS = "viernes_wake_stats"

    /** Mínimo de tiempo descargando para estimar la batería por hora. */
    private const val MIN_BATTERY_MS = 20 * 60 * 1000L

    data class Battery(val level: Float, val charging: Boolean)

    fun battery(context: Context): Battery? {
        val status = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return null
        val level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return null
        val plugged = status.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
        return Battery(level * 100f / scale, plugged != 0)
    }

    /**
     * Acumula un tramo de escucha. Lo llama el servicio cada minuto y al
     * pausar.
     */
    class Session(private val context: Context) {
        private var lastWall = SystemClock.elapsedRealtime()
        private var lastCpu = Process.getElapsedCpuTime()
        private var lastBattery = battery(context)

        fun flush(frames: Long, skipped: Long, inferenceNanos: Long, inferences: Long) {
            val now = SystemClock.elapsedRealtime()
            val cpu = Process.getElapsedCpuTime()
            val battery = battery(context)
            val wall = now - lastWall
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val edit = prefs.edit()
                .putLong("listeningMs", prefs.getLong("listeningMs", 0) + wall)
                .putLong("frames", prefs.getLong("frames", 0) + frames)
                .putLong("skipped", prefs.getLong("skipped", 0) + skipped)
                .putLong("inferenceNanos", prefs.getLong("inferenceNanos", 0) + inferenceNanos)
                .putLong("inferences", prefs.getLong("inferences", 0) + inferences)
                .putLong("cpuMs", prefs.getLong("cpuMs", 0) + (cpu - lastCpu))
                .putLong("cpuWallMs", prefs.getLong("cpuWallMs", 0) + wall)
            val previous = lastBattery
            if (previous != null && battery != null && !previous.charging && !battery.charging) {
                val drop = (previous.level - battery.level).coerceAtLeast(0f)
                edit.putFloat("batteryDrop", prefs.getFloat("batteryDrop", 0f) + drop)
                    .putLong("batteryMs", prefs.getLong("batteryMs", 0) + wall)
            }
            edit.apply()
            lastWall = now
            lastCpu = cpu
            lastBattery = battery
        }
    }

    fun read(context: Context): Map<String, Any> {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val inferences = p.getLong("inferences", 0)
        val batteryMs = p.getLong("batteryMs", 0)
        val cpuWall = p.getLong("cpuWallMs", 0)
        return mapOf(
            "listeningMs" to p.getLong("listeningMs", 0),
            "frames" to p.getLong("frames", 0),
            "skipped" to p.getLong("skipped", 0),
            "avgInferenceMs" to
                if (inferences == 0L) 0.0 else p.getLong("inferenceNanos", 0) / 1e6 / inferences,
            "batteryPerHour" to
                if (batteryMs < MIN_BATTERY_MS) -1.0
                else p.getFloat("batteryDrop", 0f) / (batteryMs / 3_600_000.0),
            "cpuPercent" to
                if (cpuWall == 0L) -1.0 else p.getLong("cpuMs", 0) * 100.0 / cpuWall,
        )
    }

    fun reset(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
