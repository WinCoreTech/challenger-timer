# Decisions

Every choice made without asking, newest section last.

## Tooling and packages
- Flutter 3.47.9 stable (Dart 3.13.7), pinned in the CI workflow. `pubspec.lock` is
  committed, so every package version is pinned exactly.
- `flutter_riverpod` 3.5.0 for state, `go_router` 18.1.4 for navigation.
- `drift` 2.35.4 over `sqlite3` 3.x. `sqlite3_flutter_libs` is not used: it is obsolete
  with sqlite3 3.x, which ships the native library through build hooks.
- The Drift generated file `lib/data/drift_store.g.dart` is committed so CI does not need
  `build_runner`. Regenerate with `dart run build_runner build` after changing tables.
- `image_picker` 1.2.4 takes the proof photo and compresses it itself (max 1600 px,
  JPEG quality 70). `share_plus` 13.3.1 opens the share sheet. `path`, `path_provider`.
- No notification, alarm, SMS or permission plugin. Those are written directly in Kotlin
  (`android/app/src/main/kotlin/...`) because the app needs exact control over full-screen
  intents, foreground service types and the blocker overlay. Only framework APIs are used
  there, no extra Android libraries.
- The Android SDK cannot be downloaded in the build session (host blocked), so the Kotlin
  code is compiled only by GitHub Actions.

## Data model
- Three tables: `events` (id, type, ts, offsetMin, day, payload JSON), `recs` (things the
  user made: habits, projects, tasks, proof, as typed-by-kind JSON documents) and `kvs`
  (settings). Streaks, XP, rank, bonus and stats are computed from `events` on every
  read. Nothing derived is stored.
- The whole database is loaded into memory at start. A heavy user writes maybe 30 rows a
  day, so years of use stay small, and every screen can be a pure function of the log.
- Each event stores the UTC offset in force when it happened and its logical day number,
  frozen at write time. Daylight-saving shifts, travel and later changes to the day-end
  setting never move old events to another day.

## Rules
- A day "counts" (master streak, bonus kept, apps unblocked) when a session is finished,
  not merely started. A finished session is one that ran its full length, or was stopped
  after at least 2 minutes. A habit tick also feeds the master streak.
- XP: start 50, each finished minute 2, proof 20, habit tick 10, daily bonus 100. Start XP
  is paid for at most 5 starts a day so start-and-cancel loops earn nothing extra.
- Freezes: 2 per calendar month per streak, no rollover, used automatically, never spent
  when there is no streak to protect. Each habit has its own allowance. The "lives" shown
  are the master streak's.
- A frozen day is not a miss, so it neither pauses nor breaks the streak.
- Daily bonus: all 100 XP are held from the first moment of the day and removed when the
  day ends without a session. The Home bar drains with the time left in the day.
- "Just five more" starts a linked 5-minute session and adds its minutes to the proof that
  is already waiting.
- Proof cannot be skipped, but the session is recorded the moment the timer ends, so
  closing the app never costs the streak. Home keeps a "proof waiting" card.
- Locked first task: an existing plan for tomorrow is read-only from 22:00 until the day
  ends. If nothing was planned before 22:00, one plan can still be set, then it locks.
- Delayed off switch covers: cue alarm, app blocker, bonus, buddy report, evening rescue
  and the first-task lock. On is instant, off takes 24 hours, cancellable. Removing an app
  from the blocked list also counts as weakening a lock and is refused while the blocker
  is on. Adding apps is always allowed.
- Buddy report text never blames. A zero day reads "did not start a session today".

## Android
- Foreground service type `specialUse` for both the timer and the blocker (there is no
  timer type). Session end is driven by an exact alarm (`setAlarmClock`) with the service
  as the visible part, so it fires in Doze. The end time is in SharedPreferences and the
  service is restored after reboot.
- `USE_EXACT_ALARM` (Android 13+) and `SCHEDULE_EXACT_ALARM` (Android 12). If exact alarms
  are refused, inexact `setAndAllowWhileIdle` is used.
- "Start 2 min" on the alarm, the notification and the block overlay starts the native
  timer immediately, before Flutter is running, and Flutter adopts that start time.
- The blocker polls UsageStatsManager once a second while the screen is on, only until the
  first session of the day is finished, then stops itself.
- Buddy SMS at 20:00 and rescue at 21:00 are fixed times in Version 1.
- Completion sound is a short system tone from `ToneGenerator`, so no audio asset.
- I pushed builds to `main` as well as the working branch, because the workflow builds
  the APK only from `main`.

## The 702 features
- One flag per feature lives in `assets/features.json`, generated from `FEATURES.md` and
  `tools/feature_meta.txt` by `tools/gen_features.py`, which also writes
  `FEATURES_STATUS.md`. Users can switch any built feature off in Settings, Features.
- Features outside Version 1 appear by rank (section 1 to 3 at rank 1, later sections at
  higher ranks). They live in a Toolbox under Me, so Home stays one Start button. Simple
  mode hides all of them.
- Most small features (prompts, lists, checklists, counters, ratings, preset habits and
  sessions, explainer cards, computed read-outs) are data in `assets/tools.json` rendered
  by one generic screen. This was the only way to cover 702 items; it means many "done"
  features are simple. Status notes say what each one really is.
- Batches after the tenth were shipped several at a time (still in numerical order) to
  save build time. Every push went through `tools/ship.sh`, which refuses to commit unless
  the analyzer is clean and all tests pass. That script exists because one push in batch 5
  went out with a failing test.
- Rules that would change Version 1 behaviour are opt-in even when their flag is on:
  decay instead of reset (55), ramp ladder (80), daily deposit drain (601, needs Firm).
- XP rules use the flag without the rank gate, because rank depends on XP.
- Pressure dial (701): Gentle by default; Firm and Relentless features are listed in
  `lib/core/pressure.dart`. Raising is instant, lowering takes 24 hours. Auto-start (633)
  is never synced when the cue time is inside the sleep window, and no reminder is ever
  scheduled inside it.
- Backend features run on `LocalBackend`, which only reports "not connected". Their
  screens show no people and no numbers. Where a share-sheet version made sense
  (contracts, pledges, digests) that was built and marked partial.
- Features that involve money (stakes, escrow, deposits) only record what you wrote.
  The app never holds or moves money.
- AI coach features are fixed rules over the user's own log and say so on screen.
- Extra permissions added by later batches, each asked only when its feature is used:
  microphone (voice proof, voice promise), Do Not Disturb access (auto DND).
