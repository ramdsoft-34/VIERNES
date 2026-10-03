package com.ramdsoft.viernes.location

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.R
import org.json.JSONArray
import org.json.JSONObject

/** Un recordatorio por ubicación tal como lo registra Android. */
data class GeofenceSpec(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Float,
    val onArrive: Boolean,
    val title: String,
    val placeName: String,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("latitude", latitude)
        .put("longitude", longitude)
        .put("radius", radiusMeters.toDouble())
        .put("onArrive", onArrive)
        .put("title", title)
        .put("placeName", placeName)

    companion object {
        fun fromJson(json: JSONObject) = GeofenceSpec(
            id = json.getString("id"),
            latitude = json.getDouble("latitude"),
            longitude = json.getDouble("longitude"),
            radiusMeters = json.getDouble("radius").toFloat(),
            onArrive = json.optBoolean("onArrive", true),
            title = json.optString("title"),
            placeName = json.optString("placeName"),
        )
    }
}

/**
 * Geocercas de Android para los recordatorios por ubicación. Se guardan
 * también aquí (preferencias nativas) porque Android las borra al reiniciar
 * el teléfono y hay que volver a registrarlas sin abrir la app.
 */
object Geofences {
    private const val TAG = "Geofences"
    private const val PREFS = "viernes_geofences"
    private const val KEY = "specs"
    private const val CHANNEL = "location_reminders"

    fun hasPermission(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        return fine && background
    }

    fun saved(context: Context): List<GeofenceSpec> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, "[]") ?: "[]"
        val array = JSONArray(raw)
        return (0 until array.length()).map { GeofenceSpec.fromJson(array.getJSONObject(it)) }
    }

    private fun save(context: Context, specs: List<GeofenceSpec>) {
        val array = JSONArray().apply { specs.forEach { put(it.toJson()) } }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, array.toString()).apply()
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, GeofenceReceiver::class.java)
        // Android exige MUTABLE: el sistema agrega los datos del evento.
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    /** Reemplaza todas las geocercas por [specs]. Devuelve un error o nulo. */
    @SuppressLint("MissingPermission")
    fun replaceAll(context: Context, specs: List<GeofenceSpec>, done: (String?) -> Unit) {
        save(context, specs)
        val client = LocationServices.getGeofencingClient(context)
        client.removeGeofences(pendingIntent(context)).addOnCompleteListener {
            if (specs.isEmpty()) {
                done(null)
                return@addOnCompleteListener
            }
            if (!hasPermission(context)) {
                done("permission")
                return@addOnCompleteListener
            }
            val request = GeofencingRequest.Builder()
                .setInitialTrigger(0) // no avisar por estar ya dentro al crearla
                .addGeofences(
                    specs.take(100).map { spec ->
                        Geofence.Builder()
                            .setRequestId(spec.id)
                            .setCircularRegion(spec.latitude, spec.longitude, spec.radiusMeters)
                            .setExpirationDuration(Geofence.NEVER_EXPIRE)
                            .setTransitionTypes(
                                if (spec.onArrive) {
                                    Geofence.GEOFENCE_TRANSITION_ENTER
                                } else {
                                    Geofence.GEOFENCE_TRANSITION_EXIT
                                },
                            )
                            .build()
                    },
                )
                .build()
            client.addGeofences(request, pendingIntent(context))
                .addOnSuccessListener { done(null) }
                .addOnFailureListener { error ->
                    Log.e(TAG, "No se pudieron registrar las geocercas", error)
                    done(error.message ?: "error")
                }
        }
    }

    /** Tras reiniciar: vuelve a registrar lo guardado. */
    fun restore(context: Context) {
        val specs = saved(context)
        if (specs.isNotEmpty()) replaceAll(context, specs) {}
    }

    fun notify(context: Context, spec: GeofenceSpec) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Recordatorios por ubicación",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = "Avisos al llegar a un lugar o salir de él" },
            )
        }
        val open = Intent(context, MainActivity::class.java)
            .setAction(ACTION_OPEN_LOCATION)
            .putExtra(EXTRA_ID, spec.id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            context,
            spec.id.hashCode(),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val where = if (spec.onArrive) "Llegaste a ${spec.placeName}" else "Saliste de ${spec.placeName}"
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_viernes)
            .setContentTitle(spec.title)
            .setContentText("📍 $where")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        manager.notify(NOTIFICATION_BASE + (spec.id.hashCode() and 0xFFFF), notification)
    }

    const val ACTION_OPEN_LOCATION = "com.ramdsoft.viernes.OPEN_LOCATION"
    const val EXTRA_ID = "locationReminderId"
    private const val NOTIFICATION_BASE = 0x7FF00000
}

/** Recibe la entrada o salida de un lugar y muestra el aviso. */
class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.w("Geofences", GeofenceStatusCodes.getStatusCodeString(event.errorCode))
            return
        }
        val ids = event.triggeringGeofences?.map { it.requestId }?.toSet() ?: return
        Geofences.saved(context).filter { it.id in ids }.forEach { Geofences.notify(context, it) }
    }
}

/** Android borra las geocercas al reiniciar: se vuelven a registrar. */
class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Geofences.restore(context)
    }
}
