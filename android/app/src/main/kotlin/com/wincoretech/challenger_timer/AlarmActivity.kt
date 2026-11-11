package com.wincoretech.challenger_timer

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Full-screen alarm (cue) and call-style rescue screen. Shows over the lock screen. */
class AlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            getSystemService(KeyguardManager::class.java)?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val rescue = intent.getStringExtra("kind") == "rescue"
        val task = intent.getStringExtra("task") ?: ""
        val cyan = Color.parseColor("#00E5FF")
        fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
        fun text(s: String, size: Float, color: Int, bold: Boolean) = TextView(this).apply {
            text = s
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            if (bold) typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(8))
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(dp(28), dp(28), dp(28), dp(28))
        }
        root.addView(text(if (rescue) "INCOMING: TWO MINUTES" else "FIRST TASK", 16f, cyan, true))
        root.addView(text(if (rescue) "Today is still saveable." else "Your alarm, your plan.", 16f, Color.LTGRAY, false))
        root.addView(text(task, 30f, Color.WHITE, true))
        val start = Button(this).apply {
            text = "START 2 MIN"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.BLACK)
            setBackgroundColor(cyan)
            minimumHeight = dp(72)
            setOnClickListener {
                startActivity(Core.activityIntent(this@AlarmActivity, Core.ACTION_START2, intent.getStringExtra("kind") ?: "cue"))
                finish()
            }
        }
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(32)
        root.addView(start, lp)
        val later = Button(this).apply {
            text = "NOT RIGHT NOW"
            setTextColor(Color.LTGRAY)
            setBackgroundColor(Color.TRANSPARENT)
            minimumHeight = dp(56)
            setOnClickListener {
                getSystemService(NotificationManager::class.java).cancel(Core.N_ALARM)
                finish()
            }
        }
        val lp2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp2.topMargin = dp(12)
        root.addView(later, lp2)
        setContentView(root)
    }
}
