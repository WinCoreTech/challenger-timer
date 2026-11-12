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
- Batch 8 (features 176 to 200): evening plan, morning confirm, time blocks, timetable and
  free slots, realistic capacity, weekly review and targets, WOOP, shutdown ritual, plan
  versus actual, move to tomorrow, energy matching, scoreboard, planning lists.
- Batch 9 (features 201 to 225): blocking during sessions, allow-list, strict lock, auto Do Not
  Disturb, face-down start, pickup counter, screen-time and time-thief report, urge
  surfing, unlock friction, scheduled scroll time, focus score, deep work, place tags,
  message batching and night-lock reminders. Mostly native: untested on device.
- Batch 10 (features 226 to 250): levels, gentle rank decay, early-finish badges, reward chest,
  daily quests, coins and reward shop, savings jar, skill ladders, avatar, workshop,
  seasons, personal records, prestige, combo.
- Batches 11 to 13 (features 251 to 325): identity tools, name talk, feeling and aversion
  fixes, mood before/after, stress, burnout and support prompts, overwhelm mode, forgive
  yesterday, sleep log and protected sleep window, wind-down, morning light and caffeine
  reminders, body prompts on the timer, 90/20 mode, nap timer, recovery score.
- Batches 14 to 16 (features 326 to 400): share-sheet contracts, pledges, build-in-public
  drafts and help requests; squads, rooms, leaderboards and cheers marked needs-backend
  with honest "not connected" screens; playbook prompts (WOOP-style logs, Feynman, Ivy
  Lee, stoic morning and evening); career-path trackers, 80/20 finder, compounding.
- Batches 17 to 19 (features 401 to 475): flashcards with spaced repetition, exam plan,
  attendance, study sessions and logs; day score, trends, insights, milestone timeline, CSV
  export; reminder set (nudge, streak at risk, morning brief, evening wrap, night-before,
  start-by, notes from past you, Sunday preview), class silence, tone picker, own alarm
  words, partial Hindi and Marathi.
