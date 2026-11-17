# Progress

## Audit (17 Nov 2026, start of plan v2)

Environment: Flutter 3.47.9 and Java 21 in this cloud session; no Android SDK, no adb, no
phone. Kotlin is compiled only by GitHub Actions. Nothing has ever run on a device.

**Solid** (tested, real logic): event log and SQLite store; streak engine with day
boundary, DST, time-zone and freeze tests; XP and rank maths; session lifecycle (start,
finish while closed, pause, cycles, hard mode); delayed off switch and pressure dial;
deadline maths; reminders list with sleep window and class silence; ship script.

**Shallow** (works, but thin): most Toolbox items are one generic prompt, list, checklist
or card; analytics are text lines, not charts; "coach" is keyword rules; share-sheet
versions stand in for social features; themes, languages and accessibility are minimal;
Home and navigation do not follow the reference app.

**Untested on device** (compiles in CI only): timer service, exact alarms, full-screen
alarm, blocker overlay, SMS, widget, quick tile, voice recording, noise, Do Not Disturb,
usage stats, face-down start, sticky notice, camera, haptics and tone.

**Code health:** `lib/ui/special.dart` (1,790 lines) is now split into 12 files by area.
Storage is three JSON-document tables at schema version 1; plan v2 data changes need no
SQL migration (see `docs/ARCHITECTURE.md`, `test/schema_test.dart`).

Plan v2 phases are logged at the end of this file.

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
- Batches 20 to 24 (features 476 to 600): text size, week-one missions and Starter badge,
  fading support, day-3 message, rule-based coach (plan draft, priority, task rewriter,
  excuse responder, deadline extraction, slump forecast, learned cue, reflection prompts),
  voice journal, routine builder with timed runs, preset routine habits, weekly spotlight,
  milestone letters, year in review, habit audit, graduation test. AI features marked
  needs-backend with no fake output.
- Batches 25 to 28 (features 601 to 702): pressure dial (Gentle, Firm, Relentless; lowering
  takes 24 hours; default Gentle), daily deposit, melting block, plant, loss preview,
  insurance, rank trial, typed oath, signed plan, voice promise and desk photo on the
  alarm, yes ladder, auto-start, cancel sentence, skip delay, honest buttons, Ulysses lock,
  timed vault, permission guard, hidden lines, serial story, chests, spins, double hour,
  jackpot, puzzle, fog map, sticky banner. Squad features marked needs-backend.
- Every line in FEATURES_STATUS.md now has a status.

## Final state

- CI: green through release `build-18`. One earlier run (build 7) was red because a
  failing widget test was pushed; it was fixed in the next commit.
- APK: https://github.com/WinCoreTech/challenger-timer/releases/tag/build-18
- 702 features: 555 done, 99 partial, 44 needs-backend, 4 blocked. See `FEATURES_STATUS.md`.
- 181 unit and widget tests pass. Nothing has run on a real phone.
- Many "done" features are simple prompts, lists, checklists or explainer cards in the
  Toolbox. The note on each status line says what was actually built.

## Phone test checklist (run in this order)

Install: open the release, download `app-debug.apk`, allow the install. If a newer build
will not install over an older one, uninstall the old one first.

Core loop
1. Open the app. Expect three setup questions (name, one habit, alarm time), then one
   permission dialog for notifications, then a running 02:00 timer on a black WORK screen.
2. Pull down the notification shade. Expect a "Session running" notification counting down.
3. Swipe the app away from recent apps and wait for the two minutes to end. Expect a
   "Session done. Full win." notification with a sound. Tap it.
4. Expect a cyan REST screen saying DONE with SAVE PROOF and JUST FIVE MORE.
5. Tap SAVE PROOF, type one line, type a parking note, save. Expect a receipt card, then
   Home showing your parking note as the next tiny step, streak 1 and "Bonus kept".
6. Open the Vault tab. Expect the proof line under today's date.
7. Start a 5-minute session from the Timer tab, then restart the phone. After it boots,
   expect the "Session running" notification to come back with the right time left.
8. On the proof screen choose PHOTO and take a picture. Expect the camera to open and the
   photo to show in the Vault.

Streaks and plan
9. Streaks tab: tap DONE on your habit. Expect a tick, current 1, and two hearts for freezes.
10. Plan tab before 10 pm: set tomorrow's first task and alarm time. Expect "Set. It locks
    at 10 pm." After 10 pm, expect a lock icon and no way to edit it.

Force stack (each asks for a permission when switched on)
11. Me, Settings, Permissions: allow exact alarms, full-screen alarms and battery
    optimisation. Set the cue time 2 minutes ahead, lock the phone. Expect the screen to
    wake with a full-screen alarm showing the task and a START 2 MIN button.
12. Tap START 2 MIN on the alarm. Expect the app to open on a running 2-minute timer.
13. Settings: turn on Earn your phone, pick one app, allow usage access and display over
    other apps. On a day with no session yet, open that app. Expect a black "EARN YOUR
    PHONE" screen within about a second, with START 2 MIN.
14. Finish a session, then open the same app. Expect it to open normally.
15. Settings: add a buddy (use your own second number), turn on Buddy report, allow SMS.
    Tap "Send today's report now". Expect an SMS to arrive.
16. Deny SMS instead (or revoke it) and tap the same button. Expect the share sheet.
17. Leave the buddy report on overnight. Expect an SMS at 8 pm.
18. On a day with no session, wait for 9 pm. Expect a ringing, call-style alert.
19. Settings: tap TURN OFF on any force-stack switch. Expect a 24-hour countdown and a
    KEEP IT ON button, and the feature still working meanwhile.

Extras (Me, Toolbox; Settings, Features has "unlock" switches per feature)
20. Long-press the home screen, add the Challenger Timer widget. Expect the streak number
    and a red START 2 MIN that turns green after a session.
21. Add the "Start 2 min" quick-settings tile and tap it. Expect a session to start.
22. Timer tab, "More ways to run it", Pomodoro. Expect a break screen after the round and
    the next round starting by itself while the app is open.
23. Timer tab, pick brown noise, start. Expect a low hiss that stops when the session ends.
24. Proof screen, VOICE: record and play back. Expect your voice.
25. Settings, Export JSON. Expect a share sheet with a `.json` file.

For anything that does not match, note the step number, what you saw, and your phone
model and Android version.

## Plan v2

- Phase 0 (17 Nov 2026): audit above, `special.dart` split with no behaviour change,
  `REFERENCE_SPEC.md`, `docs/ARCHITECTURE.md`, schema survival test. 183 tests.
- Phase 1 (17 Nov 2026): reference shell. Dashboard home with tiles and rank bar (bottom
  tabs removed), Work screen (idle, running, continuous mode, cancel, late-finish warning,
  notes, mute), project picker, nested Projects with per-project lengths, Ranks ladder with
  promotion and demotion, Achievements (unknown until earned, date earned), Stats with
  eight ranges, Schedule blocks with reminders, Settings with every reference key, Backup
  (versioned, redacted, load by paste, wipe), About. Phone, tablet-landscape and 2x-text
  layouts are covered by widget tests. 218 tests.
  Not done in Phase 1: golden screenshots; file picker for loading a backup (paste for
  now); light theme (setting exists, dark is used); several sound and screen settings are
  stored but not yet applied by the timer (almost-complete sound, overtime step, sound
  channel and volumes, ticking, screen-during-countdown). The old Timer screen is still
  used for alarm-started 2-minute sessions and Toolbox modes.
  Untested on device: everything, as before, plus the late-finish detection and the
  robust-countdown switch added to the Kotlin side.
- Phase 2, first slice (17 Nov 2026): pressure dial now defaults to Firm; burnout check
  eases it one step after 3 days over the daily limit; 00:00 to 04:00 is protected in code
  (no reminder, no cue alarm, no auto-start, no setting overrides it); focus modes Normal,
  Hyper, Beast on the Work screen with pauses, grace, XP multipliers and the Beast rank
  penalty; emergency pause; phone calls do not count as leaving; required task label;
  LOST FOCUS button with a cause; focus score on the finished line.
  Still to do in Phase 2: streak day = 25+ minutes, 3 freezes and weekly rest day, the
  2-minute door with its own streak, floating timer, funny reminder pack and 5-a-day cap,
  7 pm rescue session, night shutdown ritual and daily score, goal tracker card, drift
  charts in Stats, onboarding sleep-window question.
- Phase 2, second slice (17 Nov 2026): streak day = one session of 25+ minutes with 3
  freezes a month and one rest day a week; milestone titles from 7 to 365 days; the
  2-minute door with its own streak, a random 5 to 15 XP bonus and "Stay for 25?" at
  double XP; 60 original reminder lines in three tiers; 7 pm streak-at-risk alert; one
  reminder cap (5 a day at most, 0 in casual mode); shutdown ritual with a daily score and
  tomorrow chosen by rules; long-term goal bar on the dashboard; drift causes in Stats;
  floating timer service (Kotlin). 236+ tests.
  Not done from section 6: recovery challenge after a break; reminder times adapting to
  productive hours; PDF portfolio export; project deadline streaks; lock-screen widget
  (Android no longer allows them); onboarding question about a wider sleep window.
  Untested on device: floating timer, and everything listed before.
- Phase 3 started (17 Nov 2026): orange-on-navy palette applied everywhere (one place:
  `lib/ui/theme.dart`), native alarm and block screens match. Still to do in Phase 3: light
  theme, original tile artwork, animations, haptics tuning, empty/error states audit,
  screenshots of every screen in light and dark.
- Phase 2, third slice: recovery challenge after a streak break (3 full days in 5, 100 XP,
  banner on Work), reminder nudge moves to your best hour after 14 days, onboarding asks
  whether to protect 23:00 to 06:00 (on by default; 00:00 to 04:00 is always protected).
  Still open in section 6: PDF portfolio export, project deadline streaks.
