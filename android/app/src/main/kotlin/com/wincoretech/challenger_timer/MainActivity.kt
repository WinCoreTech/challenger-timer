package com.wincoretech.challenger_timer

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Core.channels(this)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pct/native").also {
            it.setMethodCallHandler(::onCall)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handle(intent)
        channel?.invokeMethod("action", null)
    }

    /** A tap on "Start 2 min" starts the timer here, before Flutter is even ready. */
    private fun handle(intent: Intent?) {
        when (intent?.action) {
            Core.ACTION_START2 -> Core.nativeStart(this, intent.getStringExtra("source") ?: "alarm")
            Core.ACTION_REPORT -> Core.prefs(this).edit().putString("pendingAction", "report").apply()
        }
        intent?.action = Intent.ACTION_MAIN
    }

    private fun num(v: Any?): Long = (v as? Number)?.toLong() ?: 0L

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "sync" -> {
                    sync(call.arguments as Map<*, *>)
                    result.success(null)
                }
                "startTimer" -> {
                    Core.startTimer(this, num(call.argument<Any>("endMs")), call.argument<String>("title") ?: "")
                    result.success(null)
                }
                "stopTimer" -> {
                    Core.stopTimer(this)
                    result.success(null)
                }
                "takeLaunchAction" -> {
                    val p = Core.prefs(this)
                    val action = p.getString("pendingAction", null)
                    if (action == null) {
                        result.success(null)
                    } else {
                        val map = HashMap<String, Any?>()
                        map["action"] = action
                        map["source"] = p.getString("pendingSource", "alarm")
                        if (action == "start2") map["startMs"] = p.getLong("pendingStartMs", System.currentTimeMillis())
                        p.edit().remove("pendingAction").remove("pendingSource").remove("pendingStartMs").apply()
                        result.success(map)
                    }
                }
                "requestPermission" -> requestPermission(call.arguments as String, result)
                "status" -> result.success(status())
                "openSettings" -> {
                    openSettings(call.arguments as String)
                    result.success(null)
                }
                "listApps" -> result.success(listApps())
                "sendSms" -> result.success(
                    Core.sendSms(this, call.argument<String>("phone") ?: "", call.argument<String>("text") ?: "")
                )
                "tone" -> {
                    tone()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("native", e.message, null)
        }
    }

    private fun sync(m: Map<*, *>) {
        val p = Core.prefs(this)
        val e = p.edit()
        e.putInt("dayEndHour", num(m["dayEndHour"]).toInt())
        e.putInt("cueMinute", num(m["cueMinute"]).toInt())
        e.putInt("nextCueMinute", num(m["nextCueMinute"]).toInt())
        e.putString("task", m["task"] as? String ?: "")
        e.putString("name", m["name"] as? String ?: "")
        e.putString("buddyPhone", m["buddyPhone"] as? String ?: "")
        e.putString("msgDone", m["msgDone"] as? String ?: "")
        e.putInt("msgDoneDay", num(m["msgDoneDay"]).toInt())
        e.putString("msgZero", m["msgZero"] as? String ?: "")
        e.putBoolean("onboarded", m["onboarded"] == true)
        // Flutter owns the log; the native side may have marked a later day itself.
        val synced = num(m["lastSessionDay"]).toInt()
        val timerRunning = p.getLong("timerEnd", 0L) > 0L
        e.putInt("lastSessionDay", if (timerRunning) synced else maxOf(synced, if (m["onboarded"] == true) p.getInt("lastSessionDay", -1) else -1))
        e.putStringSet("blockedApps", (m["blockedApps"] as? List<*>)?.filterIsInstance<String>()?.toSet() ?: emptySet())
        for (key in listOf("block", "cue", "buddy", "rescue")) {
            val s = m[key] as? Map<*, *>
            e.putBoolean("$key.on", s?.get("on") == true)
            e.putLong("$key.offAt", num(s?.get("offAt")))
        }
        e.apply()
        Core.scheduleAll(this)
        Core.ensureBlocker(this)
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val permission = when (name) {
            "notifications" -> if (Build.VERSION.SDK_INT >= 33) android.Manifest.permission.POST_NOTIFICATIONS else null
            "sms" -> android.Manifest.permission.SEND_SMS
            else -> null
        }
        if (permission == null || checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(permission != null || name == "notifications")
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(permission), 77)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 77) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    private fun status(): Map<String, Boolean> {
        val nm = getSystemService(NotificationManager::class.java)
        return mapOf(
            "notifications" to nm.areNotificationsEnabled(),
            "sms" to Core.canSms(this),
            "usage" to Core.hasUsageAccess(this),
            "overlay" to Settings.canDrawOverlays(this),
            "exactAlarm" to (Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "battery" to getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
        )
    }

    private fun openSettings(which: String) {
        val pkg = Uri.parse("package:$packageName")
        val intent = when (which) {
            "usage" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkg)
            "exactAlarm" -> if (Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg) else null
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg) else null
            "battery" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
            "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            else -> null
        } ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
        try {
            startActivity(intent)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
        }
    }

    private fun listApps(): List<Map<String, String>> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.packageName to it.loadLabel(packageManager).toString() }
            .filter { it.first != packageName }
            .distinctBy { it.first }
            .sortedBy { it.second.lowercase() }
            .map { mapOf("package" to it.first, "label" to it.second) }
    }

    private fun tone() {
        try {
            val t = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 70)
            t.startTone(ToneGenerator.TONE_PROP_ACK, 180)
            Handler(Looper.getMainLooper()).postDelayed({ t.release() }, 400L)
        } catch (e: Exception) {
            // No sound available. The haptic still fires from Flutter.
        }
    }
}
