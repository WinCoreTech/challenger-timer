package com.wincoretech.challenger_timer

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.telephony.SmsManager
import java.util.Calendar
import java.util.TimeZone

/**
 * Shared native logic. The Flutter side pushes a small snapshot of state into
 * SharedPreferences ("sync"), so alarms, the blocker and the buddy report keep
 * working while the Flutter engine is not running.
 */
object Core {
    const val ACTION_START2 = "com.wincoretech.challenger_timer.START2"
    const val ACTION_REPORT = "com.wincoretech.challenger_timer.REPORT"
    const val CH_TIMER = "timer"
    const val CH_ALARM = "alarm"
    const val CH_CALL = "call"
    const val CH_DONE = "done"
    const val CH_BLOCK = "block"
    const val CH_INFO = "info"
    const val N_TIMER = 1
    const val N_BLOCK = 2
    const val N_ALARM = 3
    const val N_DONE = 4
    const val N_REPORT = 5
    val KINDS = listOf("cue", "buddy", "rescue", "dayroll", "timer_done", "rem")

    fun prefs(c: Context): SharedPreferences = c.getSharedPreferences("pct", Context.MODE_PRIVATE)

    /** Same formula as lib/core/day.dart. */
    fun today(c: Context): Int {
        val now = System.currentTimeMillis()
        val off = TimeZone.getDefault().getOffset(now)
        val end = prefs(c).getInt("dayEndHour", 3)
        return Math.floorDiv(now + off - end * 3600000L, 86400000L).toInt()
    }

    /** A delayed-off switch is effective while on and before its offAt time. */
    fun switchOn(c: Context, key: String): Boolean {
        val p = prefs(c)
        val offAt = p.getLong("$key.offAt", 0L)
        return p.getBoolean("$key.on", false) && (offAt == 0L || System.currentTimeMillis() < offAt)
    }

    fun workedToday(c: Context): Boolean = prefs(c).getInt("lastSessionDay", -1) >= today(c)

    fun channels(c: Context) {
        val nm = c.getSystemService(NotificationManager::class.java)
        fun make(id: String, name: String, importance: Int, sound: Int?, usage: Int) {
            val ch = NotificationChannel(id, name, importance)
            if (sound != null) {
                ch.setSound(
                    RingtoneManager.getDefaultUri(sound),
                    AudioAttributes.Builder().setUsage(usage)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                )
                ch.enableVibration(true)
            } else if (importance <= NotificationManager.IMPORTANCE_LOW) {
                ch.setSound(null, null)
            }
            nm.createNotificationChannel(ch)
        }
        make(CH_TIMER, "Running session", NotificationManager.IMPORTANCE_LOW, null, 0)
        make(CH_BLOCK, "Earn your phone", NotificationManager.IMPORTANCE_LOW, null, 0)
        make(CH_ALARM, "Cue alarm", NotificationManager.IMPORTANCE_HIGH, RingtoneManager.TYPE_ALARM, AudioAttributes.USAGE_ALARM)
        make(CH_CALL, "Evening rescue", NotificationManager.IMPORTANCE_HIGH, RingtoneManager.TYPE_RINGTONE, AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
        make(CH_DONE, "Session finished", NotificationManager.IMPORTANCE_HIGH, RingtoneManager.TYPE_NOTIFICATION, AudioAttributes.USAGE_NOTIFICATION)
        make(CH_INFO, "Buddy report", NotificationManager.IMPORTANCE_DEFAULT, RingtoneManager.TYPE_NOTIFICATION, AudioAttributes.USAGE_NOTIFICATION)
    }

    private const val IMMUTABLE = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun activityIntent(c: Context, action: String, source: String): Intent =
        Intent(c, MainActivity::class.java).setAction(action).putExtra("source", source)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)

    fun activityPending(c: Context, action: String, source: String, code: Int): PendingIntent =
        PendingIntent.getActivity(c, code, activityIntent(c, action, source), IMMUTABLE)

    private fun alarmPending(c: Context, kind: String): PendingIntent =
        PendingIntent.getBroadcast(c, 100 + KINDS.indexOf(kind), Intent(c, AlarmReceiver::class.java).setAction(kind), IMMUTABLE)

    fun canExact(c: Context): Boolean {
        val am = c.getSystemService(AlarmManager::class.java)
        return Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
    }

    fun schedule(c: Context, kind: String, at: Long, alarmClock: Boolean) {
        val am = c.getSystemService(AlarmManager::class.java)
        val pi = alarmPending(c, kind)
        try {
            if (!canExact(c)) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else if (alarmClock) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(at, activityPending(c, Intent.ACTION_MAIN, "clock", 9)), pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    fun cancel(c: Context, kind: String) {
        c.getSystemService(AlarmManager::class.java).cancel(alarmPending(c, kind))
    }

    /** Next local time [minuteOfDay] that is at least a few seconds away. */
    private fun at(minuteOfDay: Int, addDays: Int): Long {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, addDays)
        cal.set(Calendar.HOUR_OF_DAY, minuteOfDay / 60)
        cal.set(Calendar.MINUTE, minuteOfDay % 60)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun next(minuteOfDay: Int): Long {
        val t = at(minuteOfDay, 0)
        return if (t > System.currentTimeMillis() + 5000) t else at(minuteOfDay, 1)
    }

    fun scheduleAll(c: Context) {
        val p = prefs(c)
        if (!p.getBoolean("onboarded", false)) {
            listOf("cue", "buddy", "rescue", "dayroll", "rem").forEach { cancel(c, it) }
            return
        }
        val cueToday = at(p.getInt("cueMinute", 540), 0)
        val cue = if (cueToday > System.currentTimeMillis() + 5000) cueToday else at(p.getInt("nextCueMinute", 540), 1)
        if (switchOn(c, "cue")) schedule(c, "cue", cue, true) else cancel(c, "cue")
        if (switchOn(c, "buddy")) schedule(c, "buddy", next(20 * 60), false) else cancel(c, "buddy")
        if (switchOn(c, "rescue")) schedule(c, "rescue", next(21 * 60), true) else cancel(c, "rescue")
        schedule(c, "dayroll", next(p.getInt("dayEndHour", 3) * 60 + 1), false)
        Extras.scheduleNext(c)
        Extras.updateWidgets(c)
    }

    // ---- timer -----------------------------------------------------------
    fun startTimer(c: Context, end: Long, title: String) {
        prefs(c).edit().putLong("timerEnd", end).putString("timerTitle", title).apply()
        schedule(c, "timer_done", end, true)
        try {
            c.startForegroundService(Intent(c, TimerService::class.java))
        } catch (e: Exception) {
            // The alarm above still ends the session on time.
        }
        ensureBlocker(c)
    }

    fun stopTimer(c: Context) {
        prefs(c).edit().remove("timerEnd").apply()
        cancel(c, "timer_done")
        c.stopService(Intent(c, TimerService::class.java))
    }

    /** Idempotent: called by both the service and the backup alarm. */
    @Synchronized
    fun timerDone(c: Context) {
        val p = prefs(c)
        val end = p.getLong("timerEnd", 0L)
        if (end == 0L || System.currentTimeMillis() < end - 1500) return
        p.edit().remove("timerEnd").putInt("lastSessionDay", today(c)).apply()
        cancel(c, "timer_done")
        c.stopService(Intent(c, TimerService::class.java))
        val n = Notification.Builder(c, CH_DONE)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle("Session done. Full win.")
            .setContentText("Tap to save your proof. One line is enough.")
            .setAutoCancel(true)
            .setContentIntent(activityPending(c, Intent.ACTION_MAIN, "done", 2))
            .build()
        notify(c, N_DONE, n)
        Extras.updateWidgets(c)
    }

    fun notify(c: Context, id: Int, n: Notification) {
        try {
            c.getSystemService(NotificationManager::class.java).notify(id, n)
        } catch (e: SecurityException) {
            // Notifications are not allowed. The app still shows the result when opened.
        }
    }

    // ---- start from outside the app -------------------------------------
    /** Starts a 2-minute session right now and leaves a note for Flutter. */
    fun nativeStart(c: Context, source: String) {
        val p = prefs(c)
        val now = System.currentTimeMillis()
        if (p.getLong("timerEnd", 0L) <= now) {
            p.edit().putString("pendingAction", "start2").putString("pendingSource", source)
                .putLong("pendingStartMs", now).apply()
            startTimer(c, now + 120000L, p.getString("task", "") ?: "")
        }
        c.getSystemService(NotificationManager::class.java).cancel(N_ALARM)
    }

    // ---- blocker ---------------------------------------------------------
    fun hasUsageAccess(c: Context): Boolean {
        val ops = c.getSystemService(AppOpsManager::class.java)
        @Suppress("DEPRECATION")
        val mode = if (Build.VERSION.SDK_INT >= 29)
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), c.packageName)
        else ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), c.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun blockedApps(c: Context): Set<String> = prefs(c).getStringSet("blockedApps", emptySet()) ?: emptySet()

    fun timerRunning(c: Context): Boolean = prefs(c).getLong("timerEnd", 0L) > System.currentTimeMillis()

    /** Blocking during a running session (feature 201). */
    fun sessionBlock(c: Context): Boolean = prefs(c).getBoolean("blockInSession", false) && timerRunning(c)

    /** Earn your phone: until today's first session is finished. */
    fun earnBlock(c: Context): Boolean = switchOn(c, "block") && !workedToday(c)

    fun shouldBlock(c: Context): Boolean {
        val p = prefs(c)
        if (!p.getBoolean("onboarded", false) || !Settings.canDrawOverlays(c) || !hasUsageAccess(c)) return false
        if (blockedApps(c).isEmpty() && !p.getBoolean("blockAll", false)) return false
        return earnBlock(c) || sessionBlock(c)
    }

    /** Is [pkg] blocked right now? Block-all mode (feature 22) spares an allow-list. */
    fun isBlocked(c: Context, pkg: String, allow: Set<String>): Boolean {
        if (pkg.isEmpty() || pkg == c.packageName) return false
        if (blockedApps(c).contains(pkg)) return true
        return prefs(c).getBoolean("blockAll", false) && earnBlock(c) && !allow.contains(pkg)
    }

    fun ensureBlocker(c: Context) {
        if (!shouldBlock(c)) return
        try {
            c.startForegroundService(Intent(c, BlockService::class.java))
        } catch (e: Exception) {
            // Background start refused. It starts the next time the app opens.
        }
    }

    // ---- buddy report ----------------------------------------------------
    fun buddyText(c: Context): String {
        val p = prefs(c)
        val name = (p.getString("name", "") ?: "").ifBlank { "Your buddy" }
        return if (workedToday(c)) {
            val msg = p.getString("msgDone", "") ?: ""
            if (msg.isNotEmpty() && p.getInt("msgDoneDay", -1) == today(c)) msg
            else "$name showed up today and finished a session. (Sent automatically by Challenger Timer)"
        } else {
            (p.getString("msgZero", "") ?: "").ifBlank {
                "$name did not start a session today. A kind nudge tomorrow morning would help. (Sent automatically by Challenger Timer)"
            }
        }
    }

    fun canSms(c: Context): Boolean =
        c.checkSelfPermission(android.Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED

    fun sendSms(c: Context, phone: String, text: String): Boolean {
        if (!canSms(c) || phone.isBlank()) return false
        return try {
            @Suppress("DEPRECATION")
            val sms = if (Build.VERSION.SDK_INT >= 31) c.getSystemService(SmsManager::class.java) else SmsManager.getDefault()
            val parts = sms.divideMessage(text)
            if (parts.size > 1) sms.sendMultipartTextMessage(phone, null, parts, null, null)
            else sms.sendTextMessage(phone, null, text, null, null)
            true
        } catch (e: Exception) {
            false
        }
    }
}
