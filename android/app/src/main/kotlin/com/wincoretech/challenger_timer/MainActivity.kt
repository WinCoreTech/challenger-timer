package com.wincoretech.challenger_timer

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.Activity
import android.content.Intent
import android.content.IntentFilter
import android.speech.RecognizerIntent
import android.view.WindowManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaRecorder
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

class MainActivity : FlutterActivity(), SensorEventListener {
    private var faceDownSince = 0L
    private var faceDownOn = false

    private var channel: MethodChannel? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingSpeech: MethodChannel.Result? = null
    private var screenOnAtPause = true
    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null

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
        if (!powerRegistered) {
            // Feature 21: only possible while the app process is alive.
            applicationContext.registerReceiver(PowerReceiver(), IntentFilter(Intent.ACTION_POWER_CONNECTED))
            powerRegistered = true
        }
    }

    override fun onResume() {
        super.onResume()
        listenFaceDown()
    }

    /** Feature 206: phone placed face down for two seconds while the app is open. */
    private fun listenFaceDown() {
        val sm = getSystemService(SensorManager::class.java)
        sm.unregisterListener(this)
        faceDownSince = 0L
        if (!faceDownOn) return
        sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        if (event.values[2] < -8.5f) {
            if (faceDownSince == 0L) faceDownSince = now
            if (now - faceDownSince > 2000L) {
                faceDownSince = 0L
                getSystemService(SensorManager::class.java).unregisterListener(this)
                Core.nativeStart(this, "facedown")
                channel?.invokeMethod("action", null)
            }
        } else {
            faceDownSince = 0L
        }
    }

    override fun onPause() {
        getSystemService(SensorManager::class.java).unregisterListener(this)
        // Feature 90: tells "switched to another app" apart from "screen turned off".
        screenOnAtPause = getSystemService(PowerManager::class.java).isInteractive
        super.onPause()
    }

    override fun onDestroy() {
        Noise.stop()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 78) {
            val heard = if (resultCode == Activity.RESULT_OK) data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null
            pendingSpeech?.success(heard)
            pendingSpeech = null
        }
    }

    companion object {
        private var powerRegistered = false
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
            Intent.ACTION_VIEW -> if (intent.data?.scheme == "challengertimer") Core.nativeStart(this, "tag")
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
                "dnd" -> {
                    val nm = getSystemService(NotificationManager::class.java)
                    if (nm.isNotificationPolicyAccessGranted) {
                        nm.setInterruptionFilter(
                            if (call.arguments == true) NotificationManager.INTERRUPTION_FILTER_PRIORITY
                            else NotificationManager.INTERRUPTION_FILTER_ALL
                        )
                    }
                    result.success(null)
                }
                "usage" -> result.success(usage())
                "faceDown" -> {
                    faceDownOn = call.arguments == true
                    listenFaceDown()
                    result.success(null)
                }
                "recStart" -> result.success(recStart(call.arguments as String))
                "recStop" -> {
                    recStop()
                    result.success(null)
                }
                "play" -> {
                    play(call.arguments as String)
                    result.success(null)
                }
                "keepScreenOn" -> {
                    if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "leftWithScreenOn" -> result.success(screenOnAtPause)
                "noise" -> {
                    val kind = call.arguments as? String ?: ""
                    if (kind.isEmpty()) Noise.stop() else Noise.start(kind)
                    result.success(null)
                }
                "openUrl" -> {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                    result.success(null)
                }
                "listen" -> {
                    pendingSpeech?.success(null)
                    pendingSpeech = result
                    val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        .putExtra(RecognizerIntent.EXTRA_PROMPT, "Say: start five minutes on DSA")
                    try {
                        startActivityForResult(i, 78)
                    } catch (e: Exception) {
                        pendingSpeech = null
                        result.success(null)
                    }
                }
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
        e.putInt("streak", num(m["streak"]).toInt())
        e.putBoolean("widgetSinceZero", m["widgetSinceZero"] == true)
        e.putBoolean("chargeCue", m["chargeCue"] == true)
        e.putBoolean("blockAll", m["blockAll"] == true)
        e.putBoolean("blockInSession", m["blockInSession"] == true)
        e.putStringSet("allowApps", (m["allowApps"] as? List<*>)?.filterIsInstance<String>()?.toSet() ?: emptySet())
        e.putBoolean("unlockFriction", m["unlockFriction"] == true)
        e.putInt("scrollFrom", if (m["scrollFrom"] == null) -1 else num(m["scrollFrom"]).toInt())
        e.putInt("quietFrom", num(m["quietFrom"]).toInt())
        e.putInt("quietTo", num(m["quietTo"]).toInt())
        e.putInt("remCap", if (m["remCap"] == null) 3 else num(m["remCap"]).toInt())
        val rem = org.json.JSONArray()
        for (r in (m["reminders"] as? List<*>) ?: emptyList<Any>()) {
            val map = r as? Map<*, *> ?: continue
            rem.put(org.json.JSONObject(map.mapKeys { it.key.toString() }))
        }
        e.putString("reminders", rem.toString())
        e.apply()
        Core.scheduleAll(this)
        Core.ensureBlocker(this)
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val permission = when (name) {
            "notifications" -> if (Build.VERSION.SDK_INT >= 33) android.Manifest.permission.POST_NOTIFICATIONS else null
            "sms" -> android.Manifest.permission.SEND_SMS
            "mic" -> android.Manifest.permission.RECORD_AUDIO
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
            "mic" to (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED),
            "usage" to Core.hasUsageAccess(this),
            "overlay" to Settings.canDrawOverlays(this),
            "exactAlarm" to (Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "dnd" to nm.isNotificationPolicyAccessGranted,
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
            "dnd" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "display" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
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

    /** Features 207, 214, 215: today's unlocks and minutes per app, from usage access. */
    private fun usage(): Map<String, Any> {
        if (!Core.hasUsageAccess(this)) return mapOf("granted" to false)
        val usm = getSystemService(UsageStatsManager::class.java)
        val cal = java.util.Calendar.getInstance()
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        val from = cal.timeInMillis
        val now = System.currentTimeMillis()
        var pickups = 0
        val fg = HashMap<String, Long>()
        val startAt = HashMap<String, Long>()
        val events = usm.queryEvents(from, now)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            @Suppress("DEPRECATION")
            when (e.eventType) {
                18 -> pickups++ // KEYGUARD_HIDDEN (API 28+)
                UsageEvents.Event.MOVE_TO_FOREGROUND -> startAt[pkg] = e.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> startAt.remove(pkg)?.let { fg[pkg] = (fg[pkg] ?: 0L) + (e.timeStamp - it) }
            }
        }
        for ((pkg, st) in startAt) fg[pkg] = (fg[pkg] ?: 0L) + (now - st)
        val apps = fg.entries.filter { it.key != packageName && it.value > 60000L }.sortedByDescending { it.value }.take(10).map {
            val label = try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(it.key, 0)).toString()
            } catch (ex: Exception) {
                it.key
            }
            mapOf("label" to label, "minutes" to (it.value / 60000L).toInt())
        }
        return mapOf("granted" to true, "pickups" to pickups, "apps" to apps, "total" to (fg.values.sum() / 60000L).toInt())
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

    /** Feature 129: a voice note of at most 20 seconds, AAC in an .m4a file. */
    private fun recStart(path: String): Boolean {
        recStop()
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        return try {
            @Suppress("DEPRECATION")
            val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(64000)
            r.setAudioSamplingRate(22050)
            r.setMaxDuration(20000)
            r.setOutputFile(path)
            r.prepare()
            r.start()
            recorder = r
            true
        } catch (e: Exception) {
            recorder = null
            false
        }
    }

    private fun recStop() {
        val r = recorder ?: return
        recorder = null
        try {
            r.stop()
        } catch (e: Exception) {
            // Stopped before any audio was captured.
        }
        r.release()
    }

    private fun play(path: String) {
        try {
            player?.release()
            player = MediaPlayer().apply {
                setDataSource(path)
                setOnCompletionListener { it.release() }
                prepare()
                start()
            }
        } catch (e: Exception) {
            player = null
        }
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
