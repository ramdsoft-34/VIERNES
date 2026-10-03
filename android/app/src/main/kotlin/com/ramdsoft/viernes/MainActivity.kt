package com.ramdsoft.viernes

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognizerIntent
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.ramdsoft.viernes.device.DeviceDataChannel
import com.ramdsoft.viernes.location.LocationChannel
import com.ramdsoft.viernes.shortcuts.AppShortcuts
import com.ramdsoft.viernes.wakeword.WakeStats
import com.ramdsoft.viernes.wakeword.OpenWakeWordEngine
import com.ramdsoft.viernes.wakeword.VoiceProfileChannel
import com.ramdsoft.viernes.wakeword.WakeWordService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var wakeChannel: MethodChannel? = null
    private var location: LocationChannel? = null
    private var device: DeviceDataChannel? = null

    /** La app se abrió porque se dijo "Viernes"; Flutter lo consulta al iniciar. */
    private var pendingWake = false

    /** Acceso directo con el que se abrió la app («briefing» o «new»). */
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppShortcuts.publish(this)
        handleIntent(intent, notifyFlutter = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        location?.onIntent(intent, fromNewIntent = true)
        handleIntent(intent, notifyFlutter = true)
    }

    /**
     * «Viernes», el widget, el botón de ajustes rápidos o el botón del
     * asistente de los audífonos abren la conversación; los accesos directos
     * del ícono, el resumen o un recordatorio nuevo.
     */
    private fun handleIntent(intent: Intent?, notifyFlutter: Boolean) {
        when (intent?.action) {
            WakeWordService.ACTION_WAKE,
            Intent.ACTION_VOICE_COMMAND,
            Intent.ACTION_ASSIST,
            RecognizerIntent.ACTION_VOICE_SEARCH_HANDS_FREE,
            -> onWakeIntent(notifyFlutter)
            AppShortcuts.ACTION_BRIEFING -> onAction("briefing", notifyFlutter)
            AppShortcuts.ACTION_NEW -> onAction("new", notifyFlutter)
            Intent.ACTION_VIEW -> inviteCode(intent.data)?.let {
                onAction("invite:$it", notifyFlutter)
            }
        }
    }

    /**
     * Código de una invitación de amigo:
     * `https://viernes-ramdsoft.web.app/amigo#CODIGO` (enlace que se comparte)
     * o `viernes://amigo/CODIGO` (botón de la página web).
     */
    private fun inviteCode(uri: Uri?): String? {
        uri ?: return null
        val code = when {
            uri.scheme == "https" && uri.host == INVITE_HOST &&
                uri.path.orEmpty().startsWith("/amigo") ->
                uri.fragment ?: uri.lastPathSegment?.takeIf { it != "amigo" }
            uri.scheme == "viernes" && uri.host == "amigo" -> uri.lastPathSegment
            else -> null
        }
        return code?.takeIf { it.matches(Regex("[A-Za-z0-9_-]{12,600}")) }
    }

    private fun onAction(action: String, notifyFlutter: Boolean) {
        if (notifyFlutter && wakeChannel != null) {
            wakeChannel?.invokeMethod("onAction", action)
        } else {
            pendingAction = action
        }
    }

    private fun onWakeIntent(notifyFlutter: Boolean) {
        getSystemService(NotificationManager::class.java)
            .cancel(WakeWordService.NOTIFICATION_WAKE_ID)
        // Que la conversación se vea aunque el teléfono esté bloqueado; Flutter
        // lo desactiva al cerrarla.
        setShowOverLockScreen(true)
        if (notifyFlutter && wakeChannel != null) {
            wakeChannel?.invokeMethod("onWake", null)
        } else {
            pendingWake = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setShowOverLockScreen" -> {
                    setShowOverLockScreen(call.argument<Boolean>("enabled") == true)
                    result.success(null)
                }
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                else -> result.notImplemented()
            }
        }
        wakeChannel = MethodChannel(messenger, WAKE_CHANNEL).apply {
            setMethodCallHandler(::onWakeWordCall)
        }
        location = LocationChannel(this, messenger).also { it.onIntent(intent, fromNewIntent = false) }
        device = DeviceDataChannel(this, messenger)
        VoiceProfileChannel(this, messenger)
    }

    // --- Activación por voz ------------------------------------------------

    private fun onWakeWordCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val service = WakeWordService.intent(this, WakeWordService.ACTION_START)
                    .putExtra(WakeWordService.EXTRA_MODEL_PATH, call.argument<String>("modelPath"))
                    .putExtra(
                        WakeWordService.EXTRA_THRESHOLD,
                        (call.argument<Double>("threshold") ?: 0.8).toFloat(),
                    )
                    .putExtra(WakeWordService.EXTRA_CHIME, call.argument<Boolean>("chime") ?: true)
                    .putExtra(
                        WakeWordService.EXTRA_SAVE_SAMPLES,
                        call.argument<Boolean>("saveSamples") ?: false,
                    )
                    .putExtra(
                        WakeWordService.EXTRA_LOW_BATTERY_PAUSE,
                        call.argument<Boolean>("lowBatteryPause") ?: true,
                    )
                ContextCompat.startForegroundService(this, service)
                result.success(null)
            }
            "stop" -> sendToService(WakeWordService.ACTION_STOP, result)
            "pause" -> sendToService(WakeWordService.ACTION_PAUSE, result)
            "resume" -> sendToService(WakeWordService.ACTION_RESUME, result)
            "isRunning" -> result.success(WakeWordService.isRunning)
            "hasOwnModel" -> result.success(OpenWakeWordEngine.isAvailable(this))
            "consumeLaunchWake" -> {
                result.success(pendingWake)
                pendingWake = false
            }
            "consumeLaunchAction" -> {
                result.success(pendingAction)
                pendingAction = null
            }
            "stats" -> result.success(WakeStats.read(this))
            "resetStats" -> {
                WakeStats.reset(this)
                result.success(null)
            }
            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
            "requestDrawOverlays" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun sendToService(action: String, result: MethodChannel.Result) {
        if (WakeWordService.isRunning) {
            startService(WakeWordService.intent(this, action))
        }
        result.success(null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        location?.onPermissionResult(requestCode)
        device?.onPermissionResult(requestCode)
    }

    // --- Pantalla de bloqueo -------------------------------------------------

    /**
     * Muestra la app sobre la pantalla de bloqueo y enciende la pantalla.
     * Solo se activa durante una alerta o una conversación iniciada con la
     * voz; el resto de la app sigue protegido por el bloqueo del teléfono.
     */
    private fun setShowOverLockScreen(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (enabled) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /** Android 14+ exige que el usuario permita las alertas a pantalla completa. */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    companion object {
        const val INVITE_HOST = "viernes-ramdsoft.web.app"
        private const val SYSTEM_CHANNEL = "com.ramdsoft.viernes/system"
        private const val WAKE_CHANNEL = "com.ramdsoft.viernes/wake_word"
    }
}
