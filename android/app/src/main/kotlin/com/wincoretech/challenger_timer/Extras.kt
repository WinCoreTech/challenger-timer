package com.wincoretech.challenger_timer

import android.app.Notification
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.service.quicksettings.TileService
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

/** Home-screen widget (features 16, 483, 646, 698): streak number and a start button. */
class StartWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) = Extras.updateWidgets(c)
}

/** Quick-settings tile (feature 17): one tap in the pull-down panel starts 2 minutes. */
class StartTile : TileService() {
    override fun onClick() {
        super.onClick()
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(Core.activityPending(this, Core.ACTION_START2, "tile", 40))
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(Core.activityIntent(this, Core.ACTION_START2, "tile"))
        }
    }
}

/**
 * Charger cue (feature 21). Android does not deliver this broadcast to closed
 * apps, so it is registered at runtime and works while the app process lives.
 */
class PowerReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_POWER_CONNECTED) return
        val p = Core.prefs(c)
        if (!p.getBoolean("chargeCue", false) || Core.workedToday(c) || p.getLong("timerEnd", 0L) > 0L) return
        Extras.nudge(c, 41, "Plugged in. Two minutes while it charges?", p.getString("task", "") ?: "", true)
    }
}

object Extras {
    fun updateWidgets(c: Context) {
        val m = AppWidgetManager.getInstance(c)
        val ids = m.getAppWidgetIds(ComponentName(c, StartWidget::class.java))
        if (ids.isEmpty()) return
        val p = Core.prefs(c)
        val worked = Core.workedToday(c)
        val v = RemoteViews(c.packageName, R.layout.widget_start)
        v.setTextViewText(R.id.widget_streak, p.getInt("streak", 0).toString())
        v.setTextViewText(R.id.widget_label, if (p.getBoolean("widgetSinceZero", false)) "DAYS SINCE A ZERO" else "DAY STREAK")
        v.setTextViewText(R.id.widget_start, if (worked) "DONE TODAY" else "START 2 MIN")
        v.setInt(R.id.widget_start, "setBackgroundColor", Color.parseColor(if (worked) "#FF00E676" else "#FFFF5252"))
        val start = Core.activityPending(c, if (worked) Intent.ACTION_MAIN else Core.ACTION_START2, "widget", 42)
        v.setOnClickPendingIntent(R.id.widget_start, start)
        v.setOnClickPendingIntent(R.id.widget_root, Core.activityPending(c, Intent.ACTION_MAIN, "widget", 43))
        m.updateAppWidget(ids, v)
    }

    /** A plain reminder notification, optionally with the Start 2 min action. */
    fun nudge(c: Context, id: Int, title: String, text: String, start: Boolean) {
        Core.channels(c)
        val b = Notification.Builder(c, Core.CH_INFO)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(Core.activityPending(c, Intent.ACTION_MAIN, "nudge", 44))
        if (start) {
            b.addAction(Notification.Action.Builder(null, "START 2 MIN", Core.activityPending(c, Core.ACTION_START2, "nudge", 45)).build())
        }
        Core.notify(c, id, b.build())
    }

    // ---- generic daily reminders -------------------------------------
    // prefs "reminders": JSON array of {id, minute, title, text, start, days}
    // where days is a 7-char string of 0/1 for Mon..Sun ("" = every day).

    private fun minuteNow(cal: Calendar) = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

    /** True inside quiet hours (feature 455). from == to means no quiet hours. */
    fun quiet(c: Context, minute: Int): Boolean {
        val p = Core.prefs(c)
        val from = p.getInt("quietFrom", 0)
        val to = p.getInt("quietTo", 0)
        if (from == to) return false
        return if (from < to) minute in from until to else minute >= from || minute < to
    }

    private fun dayOn(days: String, cal: Calendar): Boolean {
        if (days.length != 7) return true
        val idx = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Monday = 0
        return days[idx] == '1'
    }

    /** Schedules the single next reminder. Called from Core.scheduleAll. */
    fun scheduleNext(c: Context) {
        val arr = try {
            JSONArray(Core.prefs(c).getString("reminders", "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        var best = Long.MAX_VALUE
        val now = System.currentTimeMillis()
        for (i in 0 until arr.length()) {
            val r = arr.getJSONObject(i)
            for (add in 0..7) {
                val cal = Calendar.getInstance()
                cal.add(Calendar.DAY_OF_YEAR, add)
                cal.set(Calendar.HOUR_OF_DAY, r.getInt("minute") / 60)
                cal.set(Calendar.MINUTE, r.getInt("minute") % 60)
                cal.set(Calendar.SECOND, 0)
                cal.set(Calendar.MILLISECOND, 0)
                if (cal.timeInMillis > now + 5000 && dayOn(r.optString("days", ""), cal)) {
                    if (cal.timeInMillis < best) best = cal.timeInMillis
                    break
                }
            }
        }
        if (best == Long.MAX_VALUE) Core.cancel(c, "rem") else Core.schedule(c, "rem", best, false)
    }

    /** Fires every reminder due this minute, within the daily cap (feature 454). */
    fun fireDue(c: Context) {
        val p = Core.prefs(c)
        val cal = Calendar.getInstance()
        val minute = minuteNow(cal)
        val arr = try {
            JSONArray(p.getString("reminders", "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        val today = Core.today(c)
        var count = if (p.getInt("remDay", -1) == today) p.getInt("remCount", 0) else 0
        val cap = p.getInt("remCap", 3)
        for (i in 0 until arr.length()) {
            val r = arr.getJSONObject(i)
            val m = r.getInt("minute")
            if (m > minute || minute - m > 2 || !dayOn(r.optString("days", ""), cal)) continue
            if (quiet(c, minute) || count >= cap) continue
            if (r.optBoolean("skipIfWorked", false) && Core.workedToday(c)) continue
            nudge(c, 1000 + r.getInt("id"), r.optString("title"), r.optString("text"), r.optBoolean("start", false))
            count++
        }
        p.edit().putInt("remDay", today).putInt("remCount", count).apply()
    }
}
