# Productivity Challenger Timer

An Android app for people who delay work until the deadline is at their neck. One job:
start a 2-minute session every day and save proof of it.

- `FEATURES.md`: the 702-feature plan. `FEATURES_STATUS.md`: what is built so far.
- `DECISIONS.md`: every choice made while building. `PROGRESS.md`: phase log.
- `BACKEND.md`: what you would need to create for the features that need a server.

**Honest status:** the app is built and tested with unit and widget tests only. Nothing
has been run on a real phone yet. Alarms, the timer service, app blocking, the overlay and
SMS are "built, untested on device". See the checklist at the end of `PROGRESS.md`.

## Install on your phone

1. Open the latest release on this repo's **Releases** page.
2. Download `app-debug.apk` and open it.
3. Allow installs from your browser or file manager when Android asks.
4. If a newer build refuses to install over an old one, uninstall the old one first
   (debug builds from different CI runs are signed with different keys). Export your data
   first from Me, Settings, Export JSON.

## How it works

Six tabs: **Home** (one START button), **Timer**, **Streaks**, **Vault**, **Plan**, **Me**.

- START begins a 2-minute session in one tap. Two minutes is a full win.
- When the timer ends you save proof (one line, a photo or a link) and a parking note,
  which becomes the next tiny step on Home.
- The day ends at 3 am (changeable). A missed day uses a freeze (2 a month). With none
  left, one miss pauses the streak and two in a row break it.
- Force stack, all optional: locked first task, cue alarm, app blocking until the first
  session, a 100 XP bonus that leaves at day end, an SMS report to a buddy at 8 pm and a
  9 pm rescue alert.
- **Delayed off switch:** any lock turns on instantly but takes 24 hours to turn off, with
  a visible countdown you can cancel.

## Permissions, and why each one exists

Each is asked only when you switch on the feature that needs it, with the reason shown
first. Saying no always leaves a working fallback.

| Permission | Used for | If you say no |
| --- | --- | --- |
| Notifications (`POST_NOTIFICATIONS`) | Running-timer notification, cue alarm, rescue alert, "session done" | Timer still works while the app is open. Alarms cannot show. The task stays on Home. |
| Exact alarms (`USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM`) | Cue alarm, rescue and session end fire on the minute | Android may delay them by several minutes. |
| Full-screen intent (`USE_FULL_SCREEN_INTENT`) | The alarm covers the lock screen | You get a normal heads-up notification with the same Start 2 min button. |
| Foreground service (`FOREGROUND_SERVICE`, `..._SPECIAL_USE`) | Keeps the session alive when the app is closed, runs the blocker | Granted at install, no prompt. |
| Run at startup (`RECEIVE_BOOT_COMPLETED`) | Re-sets alarms and restores a running timer after a restart | Granted at install, no prompt. |
| Usage access (`PACKAGE_USAGE_STATS`) | Earn your phone: see which app is in front | Blocking stays off. Everything else works. |
| Display over other apps (`SYSTEM_ALERT_WINDOW`) | Earn your phone: draw the block screen | Blocking stays off. |
| Send SMS (`SEND_SMS`) | Automatic buddy report at 8 pm | At 8 pm you get a notification that opens the share sheet with the report filled in. |
| Ignore battery optimisation | Stops Android delaying alarms and the blocker | Alarms can be late on aggressive phones (Xiaomi, Oppo, Vivo, Realme, Samsung). |
| Camera | Photo proof, through the system camera app | Use one line or a link as proof instead. |
| Microphone (`RECORD_AUDIO`) | Voice proof and the recorded promise, only between your two taps | Use text, photo or link proof. |
| Do Not Disturb access | Optional: silence the phone during sessions | Sessions run without changing Do Not Disturb. |

### Battery optimisation and Doze

Android puts idle apps to sleep. The app uses alarm-clock style alarms, which Android
lets through Doze, and the running session ends by alarm, not by a sleeping timer. On
phones with aggressive battery savers you should also:

1. Me, Settings, Permissions, **Ignore battery optimisation**, Allow.
2. In the phone's own settings, allow **Autostart** for Challenger Timer if your phone has
   that switch (Xiaomi, Oppo, Vivo, Realme).
3. Do not swipe-lock or "clean" the app in the recent-apps cleaner.

## Beyond the core app

Me, Toolbox holds the optional extras, which unlock as your rank rises. Settings has
**Simple mode** (hide all of them) and **Features** (a switch per feature). The pressure
dial in the Toolbox starts on Gentle; stronger features need you to raise it, and lowering
it takes 24 hours. `FEATURES_STATUS.md` lists all 702 features with what was really built.

## Your data

Everything stays on the phone in a SQLite database. No account, no server, no analytics.
Me, Settings, **Export JSON** gives you all of it. **Delete all** removes all of it.

## Building it yourself

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions (`.github/workflows/build-apk.yml`) does the same on every push to `main`
and attaches `app-debug.apk` to a new Release.
