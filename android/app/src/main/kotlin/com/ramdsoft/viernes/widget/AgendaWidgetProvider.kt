package com.ramdsoft.viernes.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.R
import com.ramdsoft.viernes.wakeword.WakeWordService
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Widget de la pantalla de inicio: próximos recordatorios y botón para hablar
 * con Viernes.
 *
 * La app guarda solo títulos y fechas; los textos "Hoy"/"Mañana" se calculan
 * aquí al dibujar, así siguen siendo correctos después de medianoche (el
 * sistema lo redibuja cada 30 minutos).
 */
class AgendaWidgetProvider : HomeWidgetProvider() {

    private data class Item(val title: String, val at: Long)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val items = parse(widgetData.getString("agenda", null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, items))
        }
    }

    private fun parse(json: String?): List<Item> {
        if (json.isNullOrEmpty()) return emptyList()
        return runCatching {
            val array = JSONArray(json)
            (0 until array.length()).map { i ->
                val obj = array.getJSONObject(i)
                Item(obj.getString("t"), obj.getLong("d"))
            }
        }.getOrDefault(emptyList())
    }

    private fun render(context: Context, items: List<Item>): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_agenda)
        val now = System.currentTimeMillis()
        val endOfToday = startOfDay(now) + DAY_MS

        val todayCount = items.count { it.at < endOfToday }
        views.setTextViewText(
            R.id.widget_summary,
            when (todayCount) {
                0 -> "Nada pendiente para hoy"
                1 -> "Hoy: 1 pendiente"
                else -> "Hoy: $todayCount pendientes"
            },
        )

        val rows = listOf(R.id.widget_row_1, R.id.widget_row_2, R.id.widget_row_3)
        val visible = items.sortedBy { it.at }.take(rows.size)
        rows.forEachIndexed { index, rowId ->
            val item = visible.getOrNull(index)
            if (item == null) {
                views.setViewVisibility(rowId, View.GONE)
            } else {
                views.setViewVisibility(rowId, View.VISIBLE)
                views.setTextViewText(rowId, "${whenLabel(item.at, now)} · ${item.title}")
                views.setTextColor(
                    rowId,
                    if (item.at < now) Color.parseColor("#FFB4AB") else Color.WHITE,
                )
            }
        }
        views.setViewVisibility(
            R.id.widget_empty,
            if (visible.isEmpty()) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(
            R.id.widget_root,
            activityIntent(context, null, REQUEST_OPEN),
        )
        // El micrófono abre la conversación como si se hubiera dicho "Viernes".
        views.setOnClickPendingIntent(
            R.id.widget_mic,
            activityIntent(context, WakeWordService.ACTION_WAKE, REQUEST_MIC),
        )
        return views
    }

    private fun whenLabel(at: Long, now: Long): String {
        val time = SimpleDateFormat("h:mm a", SPANISH).format(at)
        val today = startOfDay(now)
        val day = when {
            at < today -> "Vencido"
            at < today + DAY_MS -> "Hoy"
            at < today + 2 * DAY_MS -> "Mañana"
            else -> SimpleDateFormat("EEE d", SPANISH).format(at)
                .replaceFirstChar { it.uppercase() }
        }
        return "$day $time"
    }

    private fun startOfDay(millis: Long): Long = Calendar.getInstance().run {
        timeInMillis = millis
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        timeInMillis
    }

    private fun activityIntent(context: Context, action: String?, request: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action ?: Intent.ACTION_MAIN
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            request,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val REQUEST_OPEN = 20
        private const val REQUEST_MIC = 21
        private val SPANISH = Locale("es", "CO")
    }
}
