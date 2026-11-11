package com.wincoretech.challenger_timer

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Foreground service that keeps a running session visible and alive. The end
 * time lives in SharedPreferences, so the service can be recreated after the
 * app is killed or the phone restarts and still show the right countdown.
 */
class TimerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val finish = Runnable { Core.timerDone(this) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Core.channels(this)
        val p = Core.prefs(this)
        val end = p.getLong("timerEnd", 0L)
        val title = p.getString("timerTitle", "") ?: ""
        val n = Notification.Builder(this, Core.CH_TIMER)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle("Session running")
            .setContentText(title.ifBlank { "Two minutes is the whole job." })
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(end)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setContentIntent(Core.activityPending(this, Intent.ACTION_MAIN, "timer", 1))
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(Core.N_TIMER, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(Core.N_TIMER, n)
            }
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        handler.removeCallbacks(finish)
        val left = end - System.currentTimeMillis()
        if (left <= 0) {
            Core.timerDone(this)
            stopSelf()
            return START_NOT_STICKY
        }
        handler.postDelayed(finish, left)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(finish)
        super.onDestroy()
    }
}
