# Progress

Nothing below has been run on a phone. "Tested" means unit or widget tests in `test/`.
Releases: https://github.com/WinCoreTech/challenger-timer/releases

## Phases 1 to 5: Version 1 (CI green, release `build-2`)

APK: https://github.com/WinCoreTech/challenger-timer/releases/tag/build-2

Built and tested:
- Flutter project, CI (analyze, test, debug APK, release).
- SQLite storage through Drift: event log, records, settings. Round-trip test on real SQLite.
- Streak engine in pure Dart with tests for the 3 am boundary, daylight-saving jumps,
  time-zone travel, month and year boundaries, freezes, pause and break.
- Home (one START button, next tiny step, master streak, rank, bonus draining), Timer
  (presets 2/5/15/25/50/90, WORK and REST themes, just five more), proof (line, photo,
  link, parking note), Vault with project filter, Streaks with year heatmaps and lives,
  Plan (locked first task, projects, tasks), Me (rank, XP breakdown, 30 achievements).
- XP, 12 ranks and achievements from JSON assets.
- Delayed off switch for every lock, onboarding in three questions, settings, JSON export,
  delete all.

Built, untested on device (needs a real phone):
- Foreground timer service and its notification, surviving app kill and reboot.
- Exact alarms: cue alarm, session end, 8 pm buddy report, 9 pm rescue, day roll.
- Full-screen alarm and call-style rescue screen over the lock screen.
- "Start 2 min" from the notification, the alarm screen and the block overlay.
- App blocking: usage-access polling and the overlay.
- Automatic SMS and the notification fallback to the share sheet.
- Camera photo capture and compression, share sheet, haptics and completion tone.
- Permission prompts and the system settings pages they open.

## All 702 features

Tracked in `FEATURES_STATUS.md`, one line per feature. Batches are logged below.

- Batch 1 (features 1 to 25): feature catalog with one flag per feature, Simple mode,
  rank-gated Toolbox, home-screen widget, quick-settings tile, voice start, NFC/deep-link
  start, charger cue, if-then reminders, five-second launch, start ritual, dice start,
  bad-day bar, start count, starting-delay meter. Native parts untested on device.
- Batch 2 (features 26 to 50): tiny and weekly habits, time windows, graduation, chain
  calendar, 66-day track, growing flame, before-noon, plan-kept, wake, upload and review
  streaks, stacking bonus, odd milestones, streak wager, rest days, task due dates.
- Batch 3 (features 51 to 75): earned freezes, optional decay, comeback counter and bonus,
  repair task, sick/travel mode, exam mode, miss autopsy and pattern finder, restart at
  tiny, fresh-start dates, slip guard, half-credit and gold days, gifted freeze (local
  version), return screen, lapse plan, friend test, archive.
- Batch 4 (features 76 to 100): pomodoro cycles, flowtime, ramp ladder, intention, outcome,
  daily/weekly/monthly challenges, mission cards, beat yesterday, ghost race, hard mode,
  soft-mode pauses, wander tally, strict breaks, break menu, hidden clock, generated
  noise, tags, difficulty XP, marathon day, session receipt.
- Batch 5 (features 101 to 125): task screen with deadline maths (personal due date,
  sessions left, quota, start-by, panic simulator, pace, backward plan), neck-level alarm,
  early-bird XP, postpone friction and limit, load calendar, delay debt, buddy share.
- Batch 6 (features 126 to 150): voice proof, camera-first, unit counters, vault search and
  pins, evidence wall, daily page, weekly digest, done list, before/after, on this day,
  backup status, portfolio export, share card, progress photos, small wins. Backend
  interface and BACKEND.md started (GitHub sync, cloud backup marked needs-backend).
  Note: one push in batch 5 went out with a failing widget test and was fixed in the next
  commit. Commits now go through tools/ship.sh, which refuses to push unless analyze and
  all tests pass.
- Batch 7 (features 151 to 175): why line, breakdown wizard, local task splitter, next action,
  estimate correction, urgent-important matrix, frog flag, WIP limit, dread XP, vague-task
  check, templates, head-start bar, almost-there, open loops, dependencies, recurring tasks.
