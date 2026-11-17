# Architecture

## Layers
```
lib/ui/*        Flutter widgets. Read a DayView, call App methods. No storage access.
lib/app/state   Riverpod: App (Notifier) holds the whole database in memory (AppData),
                writes through the Store, and exposes viewProvider -> DayView.
lib/core/*      Pure Dart. DayView computes everything from events + records + settings.
                streak_engine, rules (XP, ranks, switches), pressure, deadlines, etc.
lib/data/*      Store interface. DriftStore (SQLite) on the phone, MemoryStore in tests.
lib/app/native  Native interface over one MethodChannel. FakeNative in tests.
android/.../*.kt  Timer service, alarms, blocker, widget, tile, noise.
```
Data flow: UI -> `App` method -> `Store` write + new `AppData` -> `viewProvider` rebuilds
`DayView` -> UI. Nothing derived (streak, XP, rank, stats) is stored; it is recomputed.

## Storage (Drift, schemaVersion 1, no migrations yet)
| Table | Columns | Holds |
| --- | --- | --- |
| `events` | id, type, ts, offsetMin, day, payload (JSON) | Every user action, append-only |
| `recs` | id, kind, created, data (JSON) | Things the user made: habit, project, task, proof, class, card, tool entries |
| `kvs` | k, v | Settings, the running session, delayed switches |

Because `recs.data` and `events.payload` are JSON, new fields (project parent, per-project
durations, session mode, drift cause) need no SQL migration. `test/schema_test.dart` proves
old-shaped rows still load and compute.

## Native bridge: MethodChannel `pct/native`
Dart -> Kotlin: `sync(map)`, `startTimer{endMs,title}`, `stopTimer`, `takeLaunchAction`,
`requestPermission(name)`, `status`, `openSettings(which)`, `listApps`, `sendSms{phone,text}`,
`tone`, `openUrl`, `listen`, `keepScreenOn(bool)`, `leftWithScreenOn`, `noise(kind)`,
`recStart(path)`, `recStop`, `play(path)`, `dnd(bool)`, `usage`, `faceDown(bool)`.
Kotlin -> Dart: `action` (a start was requested from outside the app).
`sync` pushes a snapshot into SharedPreferences so alarms, blocker and SMS work while
Flutter is not running.

## Alarms (AlarmReceiver, by intent action)
| Action | When | Does |
| --- | --- | --- |
| `cue` | cue time | full-screen alarm unless worked today |
| `rescue` | 21:00 | call-style alert on a zero day |
| `buddy` | 20:00 | SMS or share-sheet notice |
| `dayroll` | day end + 1 min | reschedule, start blocker |
| `timer_done` | session end | finish the session natively |
| `rem` | next reminder | fire due reminders within cap and quiet hours |
Boot, time and time-zone changes reschedule everything.

## Notification channels
`timer` (running session), `block` (blocker, sticky notice), `alarm` (cue), `call`
(rescue), `done` (session finished), `info` (reminders, buddy report).
