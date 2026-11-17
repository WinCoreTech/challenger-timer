# Reference spec

Recorded by the owner from the reference app (v1.13.4, landscape tablet) and written into the
master prompt of 16 Nov 2026. We reproduce structure and behaviour only. Its name, artwork,
icons, sentences, rank names and achievement names are not copied (rule R1).

Look: dark theme, thin light type, uppercase titles, accent colour, hairline under app bars.

## 5.1 Home (dashboard, replaces bottom tabs)
- Grid of tiles. Large WORK tile: original artwork, a one-line slogan that rotates by state
  (ready, worked today, rank close, returning after a gap), a mute toggle. Opens WORK.
- PROJECTS tile with the project count. ACHIEVEMENTS tile with earned/total.
- Smaller tiles: STATS, SCHEDULE, SETTINGS, BACKUP (warning mark while no backup was ever
  made), ABOUT. Ours: STREAKS, VAULT, PLAN, FRIENDS (hidden until social is on).
- Bottom bar: "YOUR RANK" and the rank name with a chevron; opens RANKS.
- Phone: scrolling 2-column grid. Tablet or landscape: tall WORK tile left, others right.

## 5.2 Work (idle)
- Left: status line by state (ready, canceled, finished). Rank banner: "N more minutes today
  to advance in rank".
- Right, four rows: CURRENT PROJECT (opens picker); TIME WORKED TODAY (tap toggles to
  SESSIONS COMPLETED TODAY, and the average row switches units with it); DAILY AVERAGE
  (LAST 7 DAYS); YOUR RANK.
- One outlined button: START WORK SESSION.
- Icons: warning triangle (only after a late finish), pencil (notes, if enabled), mute.

## 5.3 Work (running)
- Title WORKING. Large thin countdown. Loop toggle (work, break, work). Red X cancels.
- Cancel returns to idle with a "canceled" status line and logs a canceled session, no XP.
- Native foreground service owns the clock. Survives app kill and reboot.
- Late finish: if the finish runs more than 5 s after the expected end, record it and show
  the warning triangle. Its dialog explains battery saving, with SHOW ME HOW (battery
  settings plus three steps) and HIDE THIS WARNING (hidden until the next late finish).
- "Robust countdown timer" setting uses a stricter alarm-clock finish path.
- Optional stay-away mode: full-screen pulsing timer.

## 5.4 Project picker
Popup with search, a "no project" entry, parents with indented children, selection highlighted.

## 5.5 Projects
Filter by name, sort, add, help. Rows: name and total time worked. Children indented.
Two row colours: worked in the last 7 days, or dormant; legend in help. Edit, archive, delete.

## 5.6 Edit project
Name; parent (none allowed); work, short break and long break durations. Each defaults to
the global setting and overrides it. No cycles.

## 5.7 Achievements
Unearned rows show as unknown and do not expand. Earned rows expand to a description and
the date earned. Triggers: first finished session; start then cancel; 2, 4, 8 hours in a
day; 10+ sessions; session after a 4+ day break; two weeks without demotion; regaining a
lost rank; plus our streak, proof and door achievements. Toast when earned (silent in
casual mode).

## 5.8 Stats
Ranges: all-time, year by year, month by month, last 30 days, week by week, last 7 days,
day by day, user defined. Back and forward step periods. Empty period: one short message.
With data: consistency % first, then time per project, by weekday, by hour, sessions per
day, average session, longest day, drift trend.

## 5.9 Ranks, promotion and demotion (our own algorithm)
- Ladder: unreached ranks beyond the next show as unknown, lower ranks dimmed, current
  highlighted. Help explains the rules.
- Rank score = exponentially decayed sum of daily worked minutes, half-life 5 days.
- Promotion when score >= threshold. Demotion when the score stays below the current
  rank's floor for 3 consecutive days, never on rest, sick, exam or freeze days.
- "Minutes needed today to advance" = smallest m with score + m >= next threshold.
- XP stays as a separate system.

## 5.10 Schedule
Empty state with CREATE SCHEDULE and help. Work blocks per weekday: project, start, length,
reminder at start. "Today's blocks" strip on WORK.

## 5.11 Settings (defaults)
workSessionMinutes 25 · almostCompleteSound off · overtimeStep off (1/5/10) ·
shortBreakMinutes 5 · longBreakMinutes 15 · longBreakEvery 5 (resets after 3 h idle) ·
weekStartsOn Monday · sortProjectsBy last activity · enableNotes on · casualMode off ·
notificationSound default · soundChannel media/notification/alarm · completeVolume 50 ·
tickingVolume off · otherSoundsVolume 50 · keepScreenOn on · screenDuringCountdown device
default · turnOnScreenOnComplete on · robustCountdown off · language device default ·
reset privacy settings · stayAwayMode off.
Ours: pressureDial Firm, sleepWindow 00:00 to 04:00, focusMode Normal, dailyLimitHours,
remindersPerDay 5, tone pack, theme, text size.

## 5.12 Backup
Make backup (share sheet, one JSON file with a format version), make redacted backup
(names, notes and proof text replaced), load backup (validate, summarise, confirm, rebuild
rank from events), wipe data with typed confirmation, "last backup" date, and a warning
that the file is saved nowhere unless sent somewhere.

## 5.13 About
Name, version, what's new, plain description, honesty note, every permission explained.

## 5.14 Not shown in the recording (design ourselves)
Finished-session screen, break screens, filled stats, schedule editor, sort and help
popups, onboarding, empty and error states.
