package com.ramdsoft.viernes.device

import android.Manifest
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Recuerda si hay un carro conectado por Bluetooth (para el modo
 * conducción automático). Android avisa de cada conexión y desconexión.
 */
class CarConnectionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
        if (device == null || !isCar(context, device)) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val cars = prefs.getStringSet(KEY_CARS, emptySet())!!.toMutableSet()
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> cars += device.address
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> cars -= device.address
            else -> return
        }
        prefs.edit().putStringSet(KEY_CARS, cars).apply()
    }

    private fun isCar(context: Context, device: BluetoothDevice): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return try {
            val type = device.bluetoothClass?.deviceClass
            type == BluetoothClass.Device.AUDIO_VIDEO_CAR_AUDIO ||
                type == BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE
        } catch (_: SecurityException) {
            false
        }
    }

    companion object {
        private const val PREFS = "viernes_device"
        private const val KEY_CARS = "connectedCars"

        fun isCarConnected(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getStringSet(KEY_CARS, emptySet())!!.isNotEmpty()
    }
}
