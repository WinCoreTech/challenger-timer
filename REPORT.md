# Productivity Go: build report (18 Nov 2026)

Plain version: the app is built and heavily tested in code, and has **never run on a phone**.

## What shipped
| Area | State |
| --- | --- |
| Rename to **Productivity Go**, new logo, adaptive and themed launcher icons, notification icon, launch screen, brand palette | Built, CI compiles it. Icons not yet seen on a device. |
| Reference shell: dashboard, Work (idle, running, loop, cancel, late-finish warning), project picker, nested Projects, Ranks ladder with promotion and demotion, Achievements, Stats ranges, Schedule, Settings (every key), Backup (versioned, redacted, load by paste, wipe), About | Built and tested |
| Our core: Firm default, burnout easing, hard 00:00 to 04:00 sleep window, Normal/Hyper/Beast modes, emergency pause, lost-focus button with causes, 25-minute streak day with 3 freezes and a weekly rest day, 2-minute door and its streak, recovery challenge, 60 reminder lines, 7 pm streak alert, shutdown ritual and daily score, goal bar, floating timer | Built and tested; native parts untested on device |
| Polish: light theme, sound and screen settings, PDF portfolio, celebration banner, accessibility guard test, original artwork | Built and tested; sounds, brightness and PDF share untested on device |
| Phase 4 without Firebase: social logic, fake backend, Firestore rules with 15 emulator tests, Friends screen, account deletion | Built and tested against a fake; **not connected to a real Firebase project** |

## Numbers
- Tests: 270 Flutter tests (unit and widget) plus 15 Firestore-rules tests on the real emulator.
- CI: the APK job was green through run 33 (the rename). Runs 34 and later were still building when this was written.
- APK: see the newest release at https://github.com/WinCoreTech/challenger-timer/releases

## Needs a real phone (never run on a device)
Timer foreground service, exact alarms, full-screen alarm, call-style rescue, app blocker and
overlay, SMS, floating timer, widget, quick tile, camera, voice, noise and cue sounds,
brightness, wake-on-finish, haptics, and now the launcher, themed and notification icons.
The 30-step checklist is at the end of PROGRESS.md.

## Needs the owner
See `docs/OWNER_TODO.md`: run the phone checklist, check the name "Productivity Go" for the
Play Store and as a trademark, look at the icons, create the Firebase project
(`docs/FIREBASE_SETUP.md`), and a signing key when a Play Store build is wanted.

## Cut or not done, and why
- Parallel subagents on worktrees: tried earlier; all three stopped on a usage limit before
  producing code, so work was done in the main session.
- Light screenshots for every screen, more tile artwork, a high-contrast option, haptic tuning,
  a file picker for backup loading (paste only): not done.
- Live Firebase sync, Google sign-in, push nudges: need the Firebase file.
- Phase 5 (WhatsApp API, AI coach, college leagues, Hindi and Marathi, Play Store beta): not started.
- 100 of the 702 original features are only partly built, 44 need a backend, 4 are blocked by Android.

## Things to know
- The streak rule changed: a day now needs one session of 25+ minutes, so existing streaks may drop.
- The package id stays `com.wincoretech.challenger_timer` so new builds install over old ones.
