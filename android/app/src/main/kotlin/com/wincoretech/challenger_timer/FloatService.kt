package com.wincoretech.challenger_timer

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.IBinder
import android.os.SystemClock
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Chronometer

/**
 * Plan v2 section 8: a small countdown that floats over other apps while a
 * session runs and this app is in the background. Tapping it opens the app.
 * It is only a view: TimerService and the finish alarm still own the clock.
 */
class FloatService : Service() {
    private var view: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val end = Core.prefs(this).getLong("timerEnd", 0L)
        if (end <= System.currentTimeMillis() || !Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (view == null) {
            val pad = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 10f, resources.displayMetrics).toInt()
            val c = Chronometer(this)
            c.isCountDown = true
            c.base = SystemClock.elapsedRealtime() + (end - System.currentTimeMillis())
            c.setTextColor(Color.WHITE)
            c.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            c.typeface = Typeface.DEFAULT_BOLD
            c.setBackgroundColor(Color.parseColor("#CC000000"))
            c.setPadding(pad, pad / 2, pad, pad / 2)
            c.setOnClickListener {
                try {
                    startActivity(Core.activityIntent(this, Intent.ACTION_MAIN, "float"))
                } catch (e: Exception) {
                    // Opening from the overlay was refused; the notification still works.
                }
            }
            c.start()
            val p = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
            )
            p.gravity = Gravity.TOP or Gravity.END
            p.y = pad * 6
            try {
                getSystemService(WindowManager::class.java).addView(c, p)
                view = c
            } catch (e: Exception) {
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        view?.let {
            try {
                getSystemService(WindowManager::class.java).removeView(it)
            } catch (e: Exception) {
                // Already removed.
            }
        }
        view = null
        super.onDestroy()
    }

    companion object {
        fun show(c: Context) {
            if (!Core.prefs(c).getBoolean("floating", false) || !Core.timerRunning(c) || !Settings.canDrawOverlays(c)) return
            try {
                c.startService(Intent(c, FloatService::class.java))
            } catch (e: Exception) {
                // Background start refused: the notification countdown remains.
            }
        }

        fun hide(c: Context) {
            c.stopService(Intent(c, FloatService::class.java))
        }
    }
}
