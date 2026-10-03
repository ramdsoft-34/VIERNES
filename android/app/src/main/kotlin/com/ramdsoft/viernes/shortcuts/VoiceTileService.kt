package com.ramdsoft.viernes.shortcuts

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.ramdsoft.viernes.MainActivity
import com.ramdsoft.viernes.wakeword.WakeWordService

/**
 * Botón «Viernes» en los ajustes rápidos (donde están el wifi y la
 * linterna): abre la conversación como si se hubiera dicho «Viernes».
 */
class VoiceTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                subtitle = "Hablar"
            }
            updateTile()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java)
            .setAction(WakeWordService.ACTION_WAKE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this,
                        REQUEST_TILE,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }
        // Con el teléfono bloqueado, primero pide desbloquear.
        if (isLocked) unlockAndRun(open) else open()
    }

    companion object {
        private const val REQUEST_TILE = 30
    }
}
