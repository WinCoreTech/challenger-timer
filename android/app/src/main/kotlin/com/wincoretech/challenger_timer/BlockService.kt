package com.wincoretech.challenger_timer

import android.app.Notification
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.telecom.TelecomManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * "Earn your phone". While today's first session is not finished, this
 * service watches which app is in front (usage access) and covers blocked
 * apps with an overlay that offers a one-tap 2-minute start.
 */
class BlockService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var overlay: View? = null
    private var current = ""
    private var last = 0L
    private var allow: Set<String> = emptySet()
    private val tick = object : Runnable {
        override fun run() {
            poll()
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Core.channels(this)
        val n = Notification.Builder(this, Core.CH_BLOCK)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle("Earn your phone is on")
            .setContentText("Chosen apps open after today's first session.")
            .setOngoing(true)
            .setContentIntent(Core.activityPending(this, Intent.ACTION_MAIN, "block", 6))
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(Core.N_BLOCK, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(Core.N_BLOCK, n)
            }
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        allow = allowList()
        if (last == 0L) {
            last = System.currentTimeMillis() - 60000L
            handler.post(tick)
        }
        return START_STICKY
    }

    private fun poll() {
        if (!Core.shouldBlock(this)) {
            hide()
            handler.removeCallbacks(tick)
            stopSelf()
            return
        }
        if (!getSystemService(PowerManager::class.java).isInteractive) return
        val now = System.currentTimeMillis()
        try {
            val events = getSystemService(UsageStatsManager::class.java).queryEvents(last - 1000L, now)
            val e = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(e)
                @Suppress("DEPRECATION")
                if (e.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) current = e.packageName ?: ""
            }
        } catch (ex: Exception) {
            return
        }
        last = now
        if (Core.isBlocked(this, current, allow)) show() else hide()
    }

    /** Never blocked, even in block-all mode: launcher, dialer, system UI, settings, user picks. */
    private fun allowList(): Set<String> {
        val set = HashSet<String>()
        set.add("com.android.systemui")
        set.add("com.android.settings")
        set.add("android")
        val home = packageManager.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
        home?.activityInfo?.packageName?.let { set.add(it) }
        getSystemService(TelecomManager::class.java)?.defaultDialerPackage?.let { set.add(it) }
        set.addAll(Core.prefs(this).getStringSet("allowApps", emptySet()) ?: emptySet())
        return set
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun show() {
        if (overlay != null) return
        val cyan = Color.parseColor("#00E5FF")
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(dp(28), dp(28), dp(28), dp(28))
        }
        fun text(s: String, size: Float, color: Int, bold: Boolean) = TextView(this).apply {
            text = s
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            if (bold) typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(8))
        }
        val inSession = Core.timerRunning(this)
        root.addView(text(if (inSession) "SESSION RUNNING" else "EARN YOUR PHONE", 28f, cyan, true))
        root.addView(text(
            if (inSession) "This app is parked until the timer ends. Back to it."
            else "This app opens after today's first session. Two minutes does it.", 18f, Color.WHITE, false))
        val task = Core.prefs(this).getString("task", "") ?: ""
        if (task.isNotBlank()) root.addView(text(task, 20f, Color.LTGRAY, true))
        val start = Button(this).apply {
            text = if (inSession) "BACK TO MY SESSION" else "START 2 MIN"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.BLACK)
            setBackgroundColor(cyan)
            minimumHeight = dp(72)
            setOnClickListener {
                current = ""
                hide()
                try {
                    startActivity(Core.activityIntent(this@BlockService, Core.ACTION_START2, "block"))
                } catch (e: Exception) {
                    Core.nativeStart(this@BlockService, "block")
                }
            }
        }
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(32)
        root.addView(start, lp)
        val home = Button(this).apply {
            text = "BACK TO HOME SCREEN"
            setTextColor(Color.LTGRAY)
            setBackgroundColor(Color.TRANSPARENT)
            minimumHeight = dp(56)
            setOnClickListener {
                current = ""
                hide()
                try {
                    startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } catch (e: Exception) {
                    // Nothing else to do: the overlay returns if the app is still in front.
                }
            }
        }
        val lp2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp2.topMargin = dp(12)
        root.addView(home, lp2)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, PixelFormat.OPAQUE
        )
        try {
            getSystemService(WindowManager::class.java).addView(root, params)
            overlay = root
        } catch (e: Exception) {
            overlay = null
        }
    }

    private fun hide() {
        val v = overlay ?: return
        overlay = null
        try {
            getSystemService(WindowManager::class.java).removeView(v)
        } catch (e: Exception) {
            // Already gone.
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        hide()
        super.onDestroy()
    }
}
