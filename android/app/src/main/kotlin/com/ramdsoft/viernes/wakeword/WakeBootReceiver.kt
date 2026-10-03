package com.ramdsoft.viernes.wakeword

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.R

/**
 * Tras reiniciar el teléfono, Android 14+ no deja encender el micrófono en
 * segundo plano. Si la activación por voz estaba encendida, se avisa con una
 * notificación: al tocarla se abre la app y vuelve a escuchar "Viernes".
 */
class WakeBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }
        // Preferencias de Flutter (shared_preferences): prefijo "flutter.".
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.settings.wakeWordEnabled", false)) return
        if (WakeWordService.isRunning) return
        notifyReactivate(context)
    }

    private fun notifyReactivate(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Reactivar «Viernes»",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = "Aviso tras reiniciar el teléfono" },
            )
        }
        val open = Intent(context, MainActivity::class.java)
            .setAction(ACTION_REACTIVATE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            context,
            2,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_viernes)
            .setContentTitle("Viernes está en pausa")
            .setContentText("Se reinició el teléfono. Toca para que vuelva a escucharte.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val ACTION_REACTIVATE = "com.ramdsoft.viernes.REACTIVATE"
        const val NOTIFICATION_ID = 0x7FFFFFF2
        private const val CHANNEL = "wake_word_boot"
    }
}
