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
        const val EXTRA_CHIME = "chime"
        const val EXTRA_SAVE_SAMPLES = "saveSamples"
        const val EXTRA_LOW_BATTERY_PAUSE = "lowBatteryPause"

        /** Pausa por batería baja: 15 % o menos y sin cargar. */
        private const val LOW_BATTERY = 15f

        /** Retoma al cargar o al pasar de este nivel. */
        private const val BATTERY_OK = 20f
        private const val STATS_EVERY_MS = 60_000L

        /** Carpeta (en filesDir) con el audio de cada activación. */
        const val SAMPLES_DIR = "wake_samples"
        private const val SAMPLE_SECONDS = 2

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

        /** Cambia cada vez que se registra, ajusta o borra la voz. */
        @Volatile
        private var profileVersion = 0

        fun reloadVoiceProfile() {
            profileVersion++
        }

        private const val VOICE_PREFS = "wake_voice"
        const val KEY_REJECTED = "rejected"
        const val KEY_ACCEPTED = "accepted"

        fun voiceCounts(context: Context): Pair<Int, Int> {
            val prefs = context.getSharedPreferences(VOICE_PREFS, Context.MODE_PRIVATE)
            return prefs.getInt(KEY_ACCEPTED, 0) to prefs.getInt(KEY_REJECTED, 0)
        }
    }

    /** Voz registrada del dueño. Sin ella, la activación no funciona. */
    private var voiceProfile: SpeakerVerifier.Profile? = null
    private var loadedProfileVersion = -1

    private fun currentVoiceProfile(): SpeakerVerifier.Profile? {
        if (loadedProfileVersion != profileVersion) {
            loadedProfileVersion = profileVersion
            voiceProfile = SpeakerVerifier.load(filesDir)
        }
        return voiceProfile
    }

    private fun countVoice(key: String) {
        val prefs = getSharedPreferences(VOICE_PREFS, Context.MODE_PRIVATE)
        prefs.edit().putInt(key, prefs.getInt(key, 0) + 1).apply()
    }

    /** ¿La voz de los últimos segundos es la del dueño? */
    private fun isOwnerVoice(profile: SpeakerVerifier.Profile): Boolean {
        val ordered = ShortArray(history.size) { history[(historyPos + it) % history.size] }
        val print = SpeakerVerifier.analyze(ordered).print ?: return false
        val check = profile.check(print)
        Log.i(
            TAG,
            "Voz: distancia %.2f (límite %.2f), tono %.1f → %s".format(
                check.distance,
                check.threshold,
                check.pitchDiff,
                if (check.accepted) "dueño" else "otra persona",
            ),
        )
        countVoice(if (check.accepted) KEY_ACCEPTED else KEY_REJECTED)
        return check.accepted
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
    private var chime = true
    private var saveSamples = false
    private var lowBatteryPause = true

    /** En pausa porque queda poca batería (se retoma al cargar). */
    @Volatile
    private var batteryPaused = false
    private var batteryReceiver: android.content.BroadcastReceiver? = null

    /** Últimos [SAMPLE_SECONDS] s de audio, para guardar cada activación. */
    private val history = ShortArray(WakeWordEngine.SAMPLE_RATE * SAMPLE_SECONDS)
    private var historyPos = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                modelPath = intent.getStringExtra(EXTRA_MODEL_PATH) ?: modelPath
                threshold = intent.getFloatExtra(EXTRA_THRESHOLD, threshold)
                chime = intent.getBooleanExtra(EXTRA_CHIME, chime)
                saveSamples = intent.getBooleanExtra(EXTRA_SAVE_SAMPLES, saveSamples)
                lowBatteryPause = intent.getBooleanExtra(EXTRA_LOW_BATTERY_PAUSE, lowBatteryPause)
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
        if (lowBatteryPause && batteryIsLow()) {
            pauseForBattery()
            return
        }
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
        if (currentVoiceProfile() == null) {
            // Sin voz registrada no se activa con nadie.
            Log.w(TAG, "Sin voz registrada: la activación por voz queda apagada")
            mainHandler.post { stopEverything() }
            return
        }
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
        val stats = WakeStats.Session(this)
        var lastFlush = android.os.SystemClock.elapsedRealtime()
        fun flushStats() {
            val values = (engine as? OpenWakeWordEngine)?.takeStats()
                ?: longArrayOf(0, 0, 0, 0)
            stats.flush(values[0], values[1], values[2], values[3])
        }
        try {
            record.startRecording()
            val buffer = ShortArray(FRAME_SAMPLES)
            while (listening) {
                val now = android.os.SystemClock.elapsedRealtime()
                if (now - lastFlush >= STATS_EVERY_MS) {
                    lastFlush = now
                    flushStats()
                    if (lowBatteryPause && batteryIsLow()) {
                        listening = false
                        mainHandler.post { pauseForBattery() }
                        break
                    }
                }
                val read = record.read(buffer, 0, buffer.size)
                if (read <= 0) continue
                remember(buffer, read)
                val confidence = engine.process(buffer, read) ?: continue
                Log.i(TAG, "\"Viernes\" con confianza $confidence (umbral $threshold)")
                if (confidence >= threshold) {
                    val profile = currentVoiceProfile()
                    if (profile == null) {
                        listening = false
                        mainHandler.post { stopEverything() }
                        break
                    }
                    engine.reset()
                    if (!isOwnerVoice(profile)) continue
                    listening = false
                    if (saveSamples) saveSample(confidence)
                    mainHandler.post { onWakeWord() }
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Error escuchando", error)
        } finally {
            runCatching { flushStats() }
            runCatching { record.stop() }
            record.release()
        }
    }

    // --- Batería -----------------------------------------------------------------

    private fun batteryIsLow(): Boolean {
        val battery = WakeStats.battery(this) ?: return false
        return !battery.charging && battery.level <= LOW_BATTERY
    }

    /** Suelta el micrófono hasta que se conecte el cargador. */
    private fun pauseForBattery() {
        if (batteryPaused) return
        batteryPaused = true
        listening = false
        isPaused = true
        updateNotification()
        val receiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val battery = WakeStats.battery(context) ?: return
                if (battery.charging || battery.level >= BATTERY_OK) resumeAfterBattery()
            }
        }
        batteryReceiver = receiver
        val filter = android.content.IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_BATTERY_OKAY)
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    private fun resumeAfterBattery() {
        if (!batteryPaused) return
        batteryPaused = false
        batteryReceiver?.let { runCatching { unregisterReceiver(it) } }
        batteryReceiver = null
        if (isRunning) resumeListening()
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

    private fun remember(buffer: ShortArray, length: Int) {
        for (i in 0 until length) {
            history[historyPos] = buffer[i]
            historyPos = (historyPos + 1) % history.size
        }
    }

    /**
     * Guarda los últimos segundos como WAV ("pending_…"). Flutter lo etiqueta
     * después según cómo terminó la conversación: si fue una activación real o
     * un error ("me equivoqué"). Solo con el consentimiento de "Ayudar a
     * entrenar a Viernes".
     */
    private fun saveSample(confidence: Float) {
        try {
            val dir = java.io.File(filesDir, SAMPLES_DIR).apply { mkdirs() }
            val ordered = ShortArray(history.size) { history[(historyPos + it) % history.size] }
            val name = "pending_${System.currentTimeMillis()}_${(confidence * 100).toInt()}.wav"
            WavWriter.write(java.io.File(dir, name), ordered, WakeWordEngine.SAMPLE_RATE)
        } catch (error: Exception) {
            Log.w(TAG, "No se pudo guardar la muestra", error)
        }
    }

    private fun playChime() {
        try {
            val tone = android.media.ToneGenerator(android.media.AudioManager.STREAM_NOTIFICATION, 70)
            tone.startTone(android.media.ToneGenerator.TONE_PROP_ACK, 180)
            mainHandler.postDelayed({ tone.release() }, 400)
        } catch (error: Exception) {
            Log.w(TAG, "Sin sonido de activación", error)
        }
    }

    private fun onWakeWord() {
        if (chime) playChime()
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
                when {
                    batteryPaused -> "Escucha en pausa por batería baja"
                    paused -> "Escucha en pausa"
                    else -> "Viernes está atento"
                },
            )
            .setContentText(
                when {
                    batteryPaused -> "Se reanuda al conectar el cargador"
                    paused -> "Se reanuda al terminar la conversación"
                    else -> "Di «Viernes» para crear un recordatorio"
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
        batteryReceiver?.let { runCatching { unregisterReceiver(it) } }
        batteryReceiver = null
        batteryPaused = false
        listening = false
        audioThread?.join(500)
        audioThread = null
        isRunning = false
        isPaused = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        batteryReceiver?.let { runCatching { unregisterReceiver(it) } }
        batteryReceiver = null
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
