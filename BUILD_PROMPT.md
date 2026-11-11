# Master build prompt

Paste the text below into a Claude Code session on this repo. FEATURES.md (all 702
features, the screen map, the daily loop, the force stack) is already in this repo.

```
Build a complete Android app called "Productivity Challenger Timer" in this repo.
Work autonomously from start to finish. Do not stop to ask me for approval. Make
sensible decisions yourself, write them in DECISIONS.md, and keep going. Stop only
if something is truly impossible, and then tell me exactly what you need.

Read FEATURES.md fully before writing any code. Feature numbers below refer to it.

WHO IT IS FOR
A college student who procrastinates until deadlines are at his neck. The app has
one job: get him to start a 2-minute work session every day and save proof of it.
Three rules shape every screen:
1. Starting beats duration. A 2-minute start is a full win.
2. Proof beats feeling. Every session ends with something saved.
3. No shame. All text is kind and a little funny. Never blame the user.

YOUR ENVIRONMENT
If you are in a cloud session with no phone or emulator, you cannot run the app. I
install builds on my own Android phone and report back. So test logic with unit
and widget tests, and never claim something works on a device unless a test
proves it. If you are on my computer with Flutter and the Android SDK, run
flutter analyze and flutter test yourself, and build the APK locally as well.

STACK
- Flutter, Android only, minSdk 26. Riverpod for state, go_router for navigation.
- Local-first, no backend: SQLite via Drift.
- Kotlin platform channels for: foreground timer service, exact alarms, full-screen
  alarm notification, app blocking (UsageStatsManager plus a blocking overlay),
  SMS sending.
- CI: .github/workflows/build-apk.yml already exists. It builds a debug APK on
  every push to main once pubspec.yaml exists and attaches it to a GitHub Release.
  Keep it working. Run flutter analyze and flutter test in it too.

ARCHITECTURE RULES
1. Event log: every user action is an event row (type, timestamp, payload).
   Streaks, XP, rank and stats are calculated from events, never stored as counters.
2. Streak engine is pure Dart with full unit tests. Rules:
   - A day ends at 3 am local time (setting).
   - One missed day is covered automatically by a streak freeze if one is left.
     The user gets 2 freezes per calendar month.
   - With no freeze, one missed day pauses the streak. Two missed days in a row
     break it.
3. Timer stores its start timestamp and runs in a foreground service with a
   persistent notification, so it survives the app being killed or the phone
   restarting mid-session.
4. Ranks and achievements are defined in a JSON asset, not in code.
5. Every feature after Version 1 sits behind a feature flag in one config file.

SCREENS (bottom navigation, six tabs)
- Home: one large START button, the next tiny step card, master streak, rank title.
- Timer: countdown, screen theme flips between WORK and REST, ends on proof screen.
- Streaks: every micro-streak with current, longest, a year heatmap, freezes left.
- Vault: timeline of saved proof, filter by project.
- Plan: projects with tasks, tomorrow's first task and cue time.
- Me: rank, XP, settings, buddy contact.

VERSION 1 FEATURES (build all 18 completely)
Start
 1. One-tap start: the app opens on Home and START begins a session in one tap.
 2. Two-minute door: the default session is 2 minutes and counts as a full win.
 3. Next tiny step card: Home shows one action written as a physical verb.
 4. Parking note: when a session ends, the user writes one line for the next step.
    It becomes the next tiny step card.
Streaks
 5. Streak per action: the user creates small habits, each with its own streak.
 6. Master streak: one "showed up" streak fed by any session or habit tick.
 7. Never miss twice: as in the streak rules above.
 8. Streak freeze: as in the streak rules above, shown as lives left.
Timer and proof
 9. Presets of 2, 5, 15, 25, 50 and 90 minutes, plus "just five more" at the end.
10. Proof at session end: a photo from the camera, a link, or one line of text.
    Stored locally, photos compressed.
11. Projects: each session and proof belongs to a project. Each project has tasks.
12. Funny rank ladder driven by XP: at least 10 ranks, from "Professional
    Postponer" up to "Momentum Machine". XP for starting, for minutes, for proof.
    Starting pays the most.
Force stack
13. Locked first task: the user sets tomorrow's first task and cue time in the
    evening. After 10 pm it cannot be edited.
14. Cue alarm: at cue time a full-screen alarm shows the first task with a
    "Start 2 min" button that starts the session directly from the notification.
15. Earn your phone: apps the user selects stay blocked each day until the first
    session is finished. Opening one shows an overlay with a one-tap start.
16. Bonus to lose: each day begins with 100 bonus XP already granted. It is
    removed at day end if there was no session. Home shows it draining.
17. Buddy report: at 8 pm the day's result is sent to one saved contact by SMS
    automatically, including a zero day. If SMS permission is denied, fall back
    to a share-sheet prompt.
18. Evening rescue: at 9 pm on a zero day, a call-style full-screen alert offers
    a one-tap 2-minute session.
Also in Version 1
- Delayed off switch: turning off any lock, block or report in settings takes
  24 hours to apply, with a visible countdown and a cancel option.
- Onboarding under 60 seconds: name, one habit, cue time, then straight into the
  first 2-minute session. Permissions are requested one at a time, each with a
  plain reason, only when the feature that needs them is switched on.
- Settings: day-end time, cue time, blocked apps, buddy contact, data export
  as JSON, delete all data.

STYLE
Dark theme: black background, one cyan accent, bold uppercase headings, large
numbers, flat poster-style vector illustrations you draw yourself. Haptic and a
short sound on every completion. Design it yourself and do not copy any
existing app's artwork or name.

ORDER OF WORK
Phase 1: Flutter project, CI building an APK, database, event log, streak engine
         with tests.
Phase 2: Home, Timer with foreground service, proof capture, Vault.
Phase 3: Streaks, Projects, Plan, XP and ranks.
Phase 4: force stack: alarms, notification start, app blocking, bonus, buddy
         report, evening rescue, delayed off switch.
Phase 5: onboarding, settings, polish, README with install steps and every
         permission explained.
After each phase: commit, push, confirm the workflow passed, fix it if not, and
append to PROGRESS.md what was built, what is untested on a real device, and the
APK release link. Then continue to the next phase without waiting.

ALL 702 FEATURES (start automatically when Version 1 is finished and CI is green)
FEATURES.md lists features 1 to 702. Build every one of them.
- Create FEATURES_STATUS.md with one line per feature: number, name, status
  (done, partial, needs-backend, blocked) and a note.
- Work in batches of 20, in numerical order, skipping ones already done in
  Version 1. Each feature goes behind its own feature flag, on by default.
- After each batch: add tests for the logic, push, confirm CI is green, fix it
  if not, update FEATURES_STATUS.md, then start the next batch without waiting.
- Never let a new batch break Version 1. If CI fails, fix it before anything new.
- Features that need a server, accounts or API keys (squads, buddies seeing live
  data, leaderboards, cloud backup, Google login, AI coach, GitHub sync): build
  the full screen and the local logic against an interface with a fake local
  implementation, mark them needs-backend, and list in BACKEND.md exactly what
  I must create and which keys to add.
- Features that Android does not allow (for example blocking uninstall): mark
  blocked, explain why, and build the closest allowed version.
- Keep the app usable: new features appear by rank (feature 492) and Home stays
  one Start button. Add a "Simple mode" switch that hides everything outside
  Version 1.
- Before your context runs low, write the exact next step at the top of
  FEATURES_STATUS.md so the work can resume.
Stop only when every line in FEATURES_STATUS.md has a status.

WHEN YOU FINISH
Give me: the APK download link, a list of everything built, a list of what you
could not verify without a phone, and a test checklist I should run on my phone
in order.
```

## To resume after a session ends

```
Read FEATURES_STATUS.md and DECISIONS.md, then continue building from the next
unfinished feature using the same rules. Do not stop until all 702 have a status.
```
