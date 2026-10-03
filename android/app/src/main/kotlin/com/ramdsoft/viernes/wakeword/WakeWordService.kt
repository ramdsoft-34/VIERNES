package com.ramdsoft.viernes.wakeword

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.R

/**
 * Servicio en primer plano que escucha la palabra "Viernes" sin internet.
 *
 * Al detectarla deja de usar el micrófono (para que la app pueda escuchar la
 * frase completa) y abre la app. La app pide reanudar al terminar; si nadie lo
 * hace, se reanuda solo tras [AUTO_RESUME_MS].
 */
class WakeWordService : Service() {

    companion object {
        private const val TAG = "WakeWordService"

        const val ACTION_START = "com.ramdsoft.viernes.wakeword.START"
        const val ACTION_STOP = "com.ramdsoft.viernes.wakeword.STOP"
        const val ACTION_PAUSE = "com.ramdsoft.viernes.wakeword.PAUSE"
        const val ACTION_RESUME = "com.ramdsoft.viernes.wakeword.RESUME"

        /** Acción con la que se abre MainActivity al oír "Viernes". */
        const val ACTION_WAKE = "com.ramdsoft.viernes.WAKE"

        const val EXTRA_MODEL_PATH = "modelPath"
        const val EXTRA_THRESHOLD = "threshold"

        private const val CHANNEL_SERVICE = "wake_word"
        private const val CHANNEL_WAKE = "wake_word_alert"
        // Fuera del rango de ids de los recordatorios (ver NotificationIds).
        const val NOTIFICATION_SERVICE_ID = 0x7FFFFFF0
        const val NOTIFICATION_WAKE_ID = 0x7FFFFFF1

        private const val AUTO_RESUME_MS = 90_000L
        private const val FRAME_SAMPLES = 2048 // ~128 ms a 16 kHz

        @Volatile
        var isRunning = false
            private set

        @Volatile
        var isPaused = false
            private set

        fun intent(context: Context, action: String) =
            Intent(context, WakeWordService::class.java).setAction(action)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val autoResume = Runnable { resumeListening() }

    @Volatile
    private var listening = false
    private var audioThread: Thread? = null
    private var engine: WakeWordEngine? = null
    private var enginePath: String? = null
    private var modelPath: String? = null
    private var threshold = 0.8f

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                modelPath = intent.getStringExtra(EXTRA_MODEL_PATH) ?: modelPath
                threshold = intent.getFloatExtra(EXTRA_THRESHOLD, threshold)
                if (!startInForeground()) return START_NOT_STICKY
                isRunning = true
                resumeListening()
            }
            ACTION_PAUSE -> pauseListening()
            ACTION_RESUME -> if (isRunning) resumeListening()
            ACTION_STOP -> {
                stopEverything()
                return START_NOT_STICKY
            }
        }
        // Android 14+ no permite reiniciar un servicio de micrófono desde
        // segundo plano: se vuelve a iniciar al abrir la app.
        return START_NOT_STICKY
    }

    private fun startInForeground(): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Sin permiso de micrófono")
            stopSelf()
            return false
        }
        createChannels()
        return try {
            val notification = serviceNotification(paused = false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_SERVICE_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_SERVICE_ID, notification)
            }
            true
        } catch (error: Exception) {
            Log.e(TAG, "No se pudo iniciar en primer plano", error)
            stopSelf()
            false
        }
    }

    // --- Escucha -------------------------------------------------------------

    private fun resumeListening() {
        mainHandler.removeCallbacks(autoResume)
        if (listening) return
        listening = true
        isPaused = false
        updateNotification()
        audioThread = Thread(::listenLoop, "viernes-wake-word").apply { start() }
    }

    private fun pauseListening() {
        mainHandler.removeCallbacks(autoResume)
        listening = false
        isPaused = true
        audioThread?.join(500)
        audioThread = null
        updateNotification()
    }

    private fun listenLoop() {
        val engine = obtainEngine() ?: run {
            mainHandler.post { stopEverything() }
            return
        }
        val record = try {
            createRecorder()
        } catch (error: SecurityException) {
            Log.e(TAG, "Micrófono no disponible", error)
            mainHandler.post { stopEverything() }
            return
        }
        try {
            record.startRecording()
            val buffer = ShortArray(FRAME_SAMPLES)
            while (listening) {
                val read = record.read(buffer, 0, buffer.size)
                if (read <= 0) continue
                val confidence = engine.process(buffer, read) ?: continue
                Log.i(TAG, "\"Viernes\" con confianza $confidence (umbral $threshold)")
                if (confidence >= threshold) {
                    listening = false
                    engine.reset()
                    mainHandler.post { onWakeWord() }
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Error escuchando", error)
        } finally {
            runCatching { record.stop() }
            record.release()
        }
    }

    /**
     * "asset:wakeword" → modelo propio incluido en el APK (openWakeWord);
     * cualquier otra ruta → modelo de Vosk descargado.
     */
    @Synchronized
    private fun obtainEngine(): WakeWordEngine? {
        val path = modelPath ?: return null
        if (engine != null && enginePath == path) return engine
        engine?.close()
        engine = null
        return try {
            val created = if (path.startsWith(OpenWakeWordEngine.ASSET_PREFIX)) {
                OpenWakeWordEngine(this, path.removePrefix(OpenWakeWordEngine.ASSET_PREFIX))
            } else {
                VoskWakeWordEngine(path)
            }
            enginePath = path
            created.also { engine = it }
        } catch (error: Exception) {
            Log.e(TAG, "No se pudo cargar el modelo en $path", error)
            null
        }
    }

    private fun createRecorder(): AudioRecord {
        val minBuffer = AudioRecord.getMinBufferSize(
            WakeWordEngine.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        return AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            WakeWordEngine.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuffer, FRAME_SAMPLES * 4),
        )
    }

    // --- Activación ------------------------------------------------------------

    private fun onWakeWord() {
        isPaused = true
        updateNotification()
        mainHandler.postDelayed(autoResume, AUTO_RESUME_MS)

        val open = Intent(this, MainActivity::class.java)
            .setAction(ACTION_WAKE)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        // Android no deja abrir pantallas desde segundo plano, salvo que el
        // usuario permita "mostrar sobre otras apps". Si no, se usa una
        // notificación a pantalla completa (abre la app con el teléfono
        // bloqueado; con el teléfono en uso aparece como aviso para tocar).
        if (Settings.canDrawOverlays(this)) {
            try {
                startActivity(open)
                return
            } catch (error: Exception) {
                Log.w(TAG, "No se pudo abrir la app directamente", error)
            }
        }
        val pending = PendingIntent.getActivity(
            this,
            1,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_WAKE)
            .setSmallIcon(R.drawable.ic_stat_viernes)
            .setContentTitle("Te escucho")
            .setContentText("Toca para decirle a Viernes qué recordar")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setTimeoutAfter(AUTO_RESUME_MS)
            .setContentIntent(pending)
            .setFullScreenIntent(pending, true)
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_WAKE_ID, notification)
    }

    // --- Notificaciones --------------------------------------------------------

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_SERVICE,
                "Escucha de «Viernes»",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Indica que Viernes está atento a su nombre"
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_WAKE,
                "Activación por voz",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Abre Viernes cuando lo llamas"
                setSound(null, null)
            },
        )
    }

    private fun serviceNotification(paused: Boolean): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            2,
            intent(this, ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_SERVICE)
            .setSmallIcon(R.drawable.ic_stat_viernes)
            .setContentTitle(
                if (paused) "Escucha en pausa" else "Viernes está atento",
            )
            .setContentText(
                if (paused) {
                    "Se reanuda al terminar la conversación"
                } else {
                    "Di «Viernes» para crear un recordatorio"
                },
            )
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openApp)
            .addAction(0, "Desactivar", stop)
            .build()
    }

    private fun updateNotification() {
        if (!isRunning) return
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_SERVICE_ID, serviceNotification(isPaused))
    }

    private fun stopEverything() {
        mainHandler.removeCallbacks(autoResume)
        listening = false
        audioThread?.join(500)
        audioThread = null
        isRunning = false
        isPaused = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        listening = false
        audioThread?.join(500)
        engine?.close()
        engine = null
        isRunning = false
        isPaused = false
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
