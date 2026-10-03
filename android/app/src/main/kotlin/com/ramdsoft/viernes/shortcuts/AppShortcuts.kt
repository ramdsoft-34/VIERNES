package com.ramdsoft.viernes.shortcuts

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.R
import com.ramdsoft.viernes.wakeword.WakeWordService

/**
 * Accesos directos al mantener presionado el ícono: hablar, «¿qué tengo
 * hoy?» y nuevo recordatorio. Se crean desde el código para que funcionen
 * igual en la versión de desarrollo (otro nombre de paquete).
 */
object AppShortcuts {
    const val ACTION_BRIEFING = "com.ramdsoft.viernes.BRIEFING"
    const val ACTION_NEW = "com.ramdsoft.viernes.NEW_REMINDER"

    fun publish(context: Context) {
        try {
            fun shortcut(id: String, short: Int, long: Int, icon: Int, action: String) =
                ShortcutInfoCompat.Builder(context, id)
                    .setShortLabel(context.getString(short))
                    .setLongLabel(context.getString(long))
                    .setIcon(IconCompat.createWithResource(context, icon))
                    .setIntent(Intent(context, MainActivity::class.java).setAction(action))
                    .build()

            ShortcutManagerCompat.setDynamicShortcuts(
                context,
                listOf(
                    shortcut(
                        "talk",
                        R.string.shortcut_talk,
                        R.string.shortcut_talk_long,
                        R.drawable.ic_shortcut_mic,
                        WakeWordService.ACTION_WAKE,
                    ),
                    shortcut(
                        "briefing",
                        R.string.shortcut_briefing,
                        R.string.shortcut_briefing_long,
                        R.drawable.ic_shortcut_today,
                        ACTION_BRIEFING,
                    ),
                    shortcut(
                        "new",
                        R.string.shortcut_new,
                        R.string.shortcut_new_long,
                        R.drawable.ic_shortcut_add,
                        ACTION_NEW,
                    ),
                ),
            )
        } catch (error: Exception) {
            Log.w("AppShortcuts", "No se pudieron crear los accesos directos", error)
        }
    }
}
