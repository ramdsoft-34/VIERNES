package com.ramdsoft.viernes.device

import android.Manifest
import android.app.Activity
import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Datos del teléfono que Viernes lee con permiso: eventos del calendario
 * (Google Calendar se sincroniza con el calendario del sistema), cumpleaños
 * de los contactos y si se va conduciendo. Solo lectura.
 */
class DeviceDataChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val pending = mutableMapOf<Int, Pair<String, MethodChannel.Result>>()

    init {
        channel.setMethodCallHandler(::onCall)
    }

    fun onPermissionResult(requestCode: Int) {
        val (permission, result) = pending.remove(requestCode) ?: return
        result.success(granted(permission))
    }

    private fun granted(permission: String) =
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

    private fun request(permission: String, code: Int, result: MethodChannel.Result) {
        if (granted(permission)) {
            result.success(true)
            return
        }
        pending.remove(code)?.second?.success(false)
        pending[code] = permission to result
        ActivityCompat.requestPermissions(activity, arrayOf(permission), code)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCalendarPermission" -> result.success(granted(Manifest.permission.READ_CALENDAR))
            "requestCalendarPermission" ->
                request(Manifest.permission.READ_CALENDAR, REQUEST_CALENDAR, result)
            "calendarEvents" -> {
                val from = call.argument<Number>("from")?.toLong() ?: 0L
                val to = call.argument<Number>("to")?.toLong() ?: 0L
                runInBackground(result) { calendarEvents(from, to) }
            }
            "hasContactsPermission" -> result.success(granted(Manifest.permission.READ_CONTACTS))
            "requestContactsPermission" ->
                request(Manifest.permission.READ_CONTACTS, REQUEST_CONTACTS, result)
            "birthdays" -> runInBackground(result) { birthdays() }
            "isDriving" -> result.success(isDriving(activity))
            "requestBluetoothPermission" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    result.success(true)
                } else {
                    request(Manifest.permission.BLUETOOTH_CONNECT, REQUEST_BLUETOOTH, result)
                }
            }
            "openAssistantSettings" -> {
                openAssistantSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            val value = try {
                work()
            } catch (error: Exception) {
                Log.w(TAG, "Error leyendo datos del teléfono", error)
                emptyList<Any>()
            }
            activity.runOnUiThread { result.success(value) }
        }.start()
    }

    // --- Calendario ------------------------------------------------------------

    private fun calendarEvents(from: Long, to: Long): List<Map<String, Any?>> {
        if (!granted(Manifest.permission.READ_CALENDAR)) return emptyList()
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.VISIBLE,
            CalendarContract.Instances.STATUS,
        )
        val events = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            uri,
            projection,
            null,
            null,
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext() && events.size < MAX_EVENTS) {
                // Calendarios ocultos y eventos cancelados no cuentan.
                if (cursor.getInt(6) == 0) continue
                if (!cursor.isNull(7) &&
                    cursor.getInt(7) == CalendarContract.Instances.STATUS_CANCELED
                ) {
                    continue
                }
                events += mapOf(
                    "title" to cursor.getString(0),
                    "start" to cursor.getLong(1),
                    "end" to cursor.getLong(2),
                    "allDay" to (cursor.getInt(3) == 1),
                    "calendar" to cursor.getString(4),
                    "location" to cursor.getString(5),
                )
            }
        }
        return events
    }

    // --- Cumpleaños --------------------------------------------------------------

    private fun birthdays(): List<Map<String, String>> {
        if (!granted(Manifest.permission.READ_CONTACTS)) return emptyList()
        val event = ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE
        val result = mutableListOf<Map<String, String>>()
        activity.contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            arrayOf(
                ContactsContract.Data.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Event.START_DATE,
            ),
            "${ContactsContract.Data.MIMETYPE} = ? AND " +
                "${ContactsContract.CommonDataKinds.Event.TYPE} = ?",
            arrayOf(
                event,
                ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString(),
            ),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(0) ?: continue
                val date = cursor.getString(1) ?: continue
                result += mapOf("name" to name, "date" to date)
            }
        }
        return result
    }

    // --- Asistente ---------------------------------------------------------------

    /** Ajustes del asistente digital / entrada de voz del teléfono. */
    private fun openAssistantSettings() {
        val candidates = listOf(
            Intent(Settings.ACTION_VOICE_INPUT_SETTINGS),
            Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (intent in candidates) {
            try {
                activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: ActivityNotFoundException) {
                // Siguiente opción.
            }
        }
    }

    companion object {
        private const val TAG = "DeviceDataChannel"
        private const val CHANNEL = "com.ramdsoft.viernes/device"
        private const val REQUEST_CALENDAR = 7101
        private const val REQUEST_CONTACTS = 7102
        private const val REQUEST_BLUETOOTH = 7103
        private const val MAX_EVENTS = 200

        /** Modo carro (Android Auto) o el Bluetooth de un carro conectado. */
        fun isDriving(context: Context): Boolean {
            val uiMode = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            if (uiMode?.currentModeType == Configuration.UI_MODE_TYPE_CAR) return true
            return CarConnectionReceiver.isCarConnected(context)
        }
    }
}
