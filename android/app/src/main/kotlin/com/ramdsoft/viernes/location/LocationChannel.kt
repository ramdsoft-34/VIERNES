package com.ramdsoft.viernes.location

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Puente con Flutter para los recordatorios por ubicación. */
class LocationChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingPermission: MethodChannel.Result? = null

    /** Recordatorio a mostrar si la app se abrió desde su aviso. */
    private var launchId: String? = null

    init {
        channel.setMethodCallHandler(::onCall)
    }

    fun onIntent(intent: Intent?, fromNewIntent: Boolean) {
        if (intent?.action != Geofences.ACTION_OPEN_LOCATION) return
        val id = intent.getStringExtra(Geofences.EXTRA_ID) ?: return
        if (fromNewIntent) channel.invokeMethod("onOpen", id) else launchId = id
    }

    fun onPermissionResult(requestCode: Int) {
        if (requestCode != REQUEST_FINE && requestCode != REQUEST_BACKGROUND) return
        pendingPermission?.success(status())
        pendingPermission = null
    }

    private fun granted(permission: String) =
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

    private fun status(): Map<String, Boolean> = mapOf(
        "fine" to granted(Manifest.permission.ACCESS_FINE_LOCATION),
        "background" to (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            ),
    )

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "requestFine" -> request(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                REQUEST_FINE,
                result,
            )
            "requestBackground" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(status())
                } else {
                    // Android 11+ lleva al usuario a Ajustes para elegir
                    // «Permitir todo el tiempo».
                    request(
                        arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                        REQUEST_BACKGROUND,
                        result,
                    )
                }
            }
            "currentLocation" -> currentLocation(result)
            "setGeofences" -> {
                val specs = (call.arguments as? List<*>).orEmpty().mapNotNull { raw ->
                    val m = raw as? Map<*, *> ?: return@mapNotNull null
                    GeofenceSpec(
                        id = m["id"] as String,
                        latitude = (m["latitude"] as Number).toDouble(),
                        longitude = (m["longitude"] as Number).toDouble(),
                        radiusMeters = (m["radius"] as Number).toFloat(),
                        onArrive = m["onArrive"] as? Boolean ?: true,
                        title = m["title"] as? String ?: "",
                        placeName = m["placeName"] as? String ?: "",
                    )
                }
                Geofences.replaceAll(activity, specs) { error -> result.success(error) }
            }
            "consumeLaunch" -> {
                result.success(launchId)
                launchId = null
            }
            else -> result.notImplemented()
        }
    }

    private fun request(permissions: Array<String>, code: Int, result: MethodChannel.Result) {
        pendingPermission?.success(status())
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, permissions, code)
    }

    @SuppressLint("MissingPermission")
    private fun currentLocation(result: MethodChannel.Result) {
        if (!granted(Manifest.permission.ACCESS_FINE_LOCATION) &&
            !granted(Manifest.permission.ACCESS_COARSE_LOCATION)
        ) {
            result.success(null)
            return
        }
        LocationServices.getFusedLocationProviderClient(activity)
            .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, CancellationTokenSource().token)
            .addOnSuccessListener { location ->
                result.success(
                    location?.let {
                        mapOf(
                            "latitude" to it.latitude,
                            "longitude" to it.longitude,
                            "accuracy" to it.accuracy.toDouble(),
                        )
                    },
                )
            }
            .addOnFailureListener { result.success(null) }
    }

    companion object {
        private const val CHANNEL = "com.ramdsoft.viernes/location"
        private const val REQUEST_FINE = 4101
        private const val REQUEST_BACKGROUND = 4102
    }
}
