package com.ramdsoft.viernes.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.R
import com.ramdsoft.viernes.wakeword.WakeWordService

/** Widget pequeño (1×1): solo el micrófono para hablar con Viernes. */
class MicWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(WakeWordService.ACTION_WAKE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            context,
            REQUEST_MIC,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_mic)
            views.setOnClickPendingIntent(R.id.widget_mic_root, pending)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        private const val REQUEST_MIC = 22
    }
}
