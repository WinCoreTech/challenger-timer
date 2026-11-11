package com.wincoretech.challenger_timer

import android.app.Notification
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Receives every scheduled alarm plus boot, time and time-zone changes. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        Core.channels(c)
        val p = Core.prefs(c)
        when (intent.action) {
            "timer_done" -> {
                Core.timerDone(c)
                return
            }
            "cue" -> if (Core.switchOn(c, "cue") && !Core.workedToday(c)) alarm(c, "cue")
            "rescue" -> if (Core.switchOn(c, "rescue") && !Core.workedToday(c)) alarm(c, "rescue")
            "buddy" -> if (Core.switchOn(c, "buddy")) report(c)
            else -> {
                // Boot, package replaced, clock or zone changed, or day roll.
                if (p.getLong("timerEnd", 0L) > System.currentTimeMillis()) {
                    Core.startTimer(c, p.getLong("timerEnd", 0L), p.getString("timerTitle", "") ?: "")
                } else if (p.getLong("timerEnd", 0L) > 0L) {
                    Core.timerDone(c)
                }
            }
        }
        Core.scheduleAll(c)
        Core.ensureBlocker(c)
    }

    private fun alarm(c: Context, kind: String) {
        val rescue = kind == "rescue"
        val task = (Core.prefs(c).getString("task", "") ?: "").ifBlank { "Open your notebook to the page you stopped on." }
        val full = PendingIntent.getActivity(
            c, if (rescue) 21 else 20,
            Intent(c, AlarmActivity::class.java).putExtra("kind", kind).putExtra("task", task)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val start = Core.activityPending(c, Core.ACTION_START2, kind, if (rescue) 31 else 30)
        val n = Notification.Builder(c, if (rescue) Core.CH_CALL else Core.CH_ALARM)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle(if (rescue) "Two minutes saves today" else "Time for your first task")
            .setContentText(task)
            .setStyle(Notification.BigTextStyle().bigText(task))
            .setCategory(if (rescue) Notification.CATEGORY_CALL else Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setTimeoutAfter(90000L)
            .setContentIntent(full)
            .setFullScreenIntent(full, true)
            .addAction(Notification.Action.Builder(null, "START 2 MIN", start).build())
            .build()
        n.flags = n.flags or Notification.FLAG_INSISTENT
        Core.notify(c, Core.N_ALARM, n)
    }

    private fun report(c: Context) {
        val phone = Core.prefs(c).getString("buddyPhone", "") ?: ""
        if (phone.isBlank()) return
        val text = Core.buddyText(c)
        val sent = Core.sendSms(c, phone, text)
        val n = Notification.Builder(c, Core.CH_INFO)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle(if (sent) "Buddy report sent" else "Send today's report to your buddy")
            .setContentText(if (sent) text else "SMS is not allowed, so tap to share it yourself.")
            .setStyle(Notification.BigTextStyle().bigText(if (sent) text else "SMS is not allowed, so tap to share it yourself."))
            .setAutoCancel(true)
            .setContentIntent(Core.activityPending(c, if (sent) Intent.ACTION_MAIN else Core.ACTION_REPORT, "buddy", 5))
            .build()
        Core.notify(c, Core.N_REPORT, n)
    }
}
