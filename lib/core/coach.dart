/// First week (501 to 525), rule-based coach (526 to 550), routines and
/// staying power (551 to 600). Pure Dart. The "coach" here is fixed rules
/// over the user's own log: it never guesses and never invents data.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'planning.dart';
import 'stats.dart';
import 'tools.dart';

/// Logical day of onboarding, or null.
int? firstDay(DayView v) => v.type(Ev.onboarded).firstOrNull?.day;

/// Days since onboarding, 0 on the first day.
int dayIndex(DayView v) => v.today - (firstDay(v) ?? v.today);

/// 505 to 511: the seven week-one missions and whether each is done.
List<(String, bool)> weekOne(DayView v) => [
      ('Day 1: one 2-minute session', v.type(Ev.sessionDone).isNotEmpty),
      ('Day 2: leave a parking note', v.type(Ev.parkingNote).isNotEmpty),
      ('Day 3: save your first proof', v.type(Ev.proof).isNotEmpty),
      ('Day 4: plan tomorrow tonight', v.type(Ev.planSet).isNotEmpty),
      ('Day 5: one 15-minute session', v.type(Ev.sessionDone).any((e) => (e.get<num>('minutes') ?? 0) >= 15)),
      ('Day 6: add a buddy', (v.kv[K.buddyPhone] ?? '').isNotEmpty),
      ('Day 7: weekly review and first rank-up', v.toolEvents(184).isNotEmpty && v.rank.index >= 1),
    ];

/// 522: around day three motivation dips, and that is normal.
bool dayThreeDip(DayView v) => v.type(Ev.onboarded).isNotEmpty && (dayIndex(v) == 2 || dayIndex(v) == 3);

/// 521: more reminders in week one, fewer after, unless the user chose a cap.
int defaultReminderCap(DayView v) => dayIndex(v) < 7 ? 3 : 2;

/// 528: open tasks ordered by due date, then smaller first.
List<Rec> autoPriority(DayView v) {
  final open = v.of(Kind.task).where((t) => !t.flag('done')).toList();
  int due(Rec t) => t.data['due'] is int ? t.integer('due') : 1 << 30;
  open.sort((a, b) => due(a) != due(b) ? due(a).compareTo(due(b)) : a.integer('est').compareTo(b.integer('est')));
  return open;
}

/// 527: a draft for today: the top tasks placed into today's free slots.
List<String> morningPlan(DayView v) {
  final slots = freeSlots(v, weekdayOf(v.today));
  final tasks = autoPriority(v).take(slots.length.clamp(1, 3)).toList();
  if (tasks.isEmpty) return ['First step: ${v.nextStep}', 'No open tasks. Add one on the Plan tab.'];
  return [
    for (final (i, t) in tasks.indexed)
      '${i < slots.length ? hhmm(slots[i].$1) : 'Later'}: ${t.str('title')}'
          '${t.data['due'] is int ? ' (due ${dayLabel(t.integer('due'))})' : ''}',
  ];
}

/// 529: turns a vague title into a physical first action using fixed patterns.
String rewriteTask(String title) {
  final t = title.trim();
  final m = RegExp(r'^(study|learn|revise|do|work on|prepare|finish|complete)\s+(.+)$', caseSensitive: false).firstMatch(t);
  if (m == null) return t;
  final what = m.group(2)!;
  return switch (m.group(1)!.toLowerCase()) {
    'study' || 'learn' || 'revise' => 'Open the $what notes and read the first page',
    'prepare' => 'Write the three headings for $what on a blank page',
    _ => 'Open $what and do the first small part',
  };
}

/// 531: a calm reply to a typed excuse, matched by keyword.
String excuseReply(String excuse) {
  final e = excuse.toLowerCase();
  if (e.contains('tired') || e.contains('sleepy')) return 'Then do the tired version: two minutes, sitting down, the easiest part. Tired work still counts.';
  if (e.contains('time') || e.contains('late') || e.contains('busy')) return 'Two minutes fits inside any day. The day ends at 3 am here, so there is still room.';
  if (e.contains('mood') || e.contains('feel')) return 'You do not need the mood. The mood usually shows up a minute after you start.';
  if (e.contains('tomorrow') || e.contains('later')) return 'Tomorrow-you will say the same thing. Do a single small piece now and tomorrow gets lighter.';
  if (e.contains('know') || e.contains('where') || e.contains('how')) return 'Then the task is: write down what you do not know. That is a real first step.';
  if (e.contains('perfect') || e.contains('good enough') || e.contains('bad')) return 'It only has to exist. Make it ugly on purpose, then fix one thing.';
  return 'Fair. And still: two minutes costs almost nothing. Start, and stop after two if you want.';
}

/// 543: finds a due date in pasted text. Understands "14 Nov", "14/11",
/// "14-11-2026", "tomorrow" and weekday names. Returns a logical day or null.
int? extractDeadline(String text, int today) {
  final s = text.toLowerCase();
  final t = dateOfDay(today);
  const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  int fix(int y, int m, int d) {
    var day = dayOfDate(y, m, d);
    if (day < today) day = dayOfDate(y + 1, m, d);
    return day;
  }

  var m = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)').firstMatch(s);
  if (m != null) return fix(t.year, months.indexOf(m.group(2)!) + 1, int.parse(m.group(1)!));
  m = RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?').firstMatch(s);
  if (m != null) {
    final y = m.group(3) == null ? t.year : (int.parse(m.group(3)!) % 100) + 2000;
    final mo = int.parse(m.group(2)!), d = int.parse(m.group(1)!);
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) return m.group(3) == null ? fix(y, mo, d) : dayOfDate(y, mo, d);
  }
  if (s.contains('day after tomorrow')) return today + 2;
  if (s.contains('tomorrow')) return today + 1;
  const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  for (final (i, n) in names.indexed) {
    if (s.contains(n)) {
      final ahead = (i + 1 - weekdayOf(today)) % 7;
      return today + (ahead == 0 ? 7 : ahead);
    }
  }
  return null;
}

/// 540: the weekday you most often miss, if today is that day.
String? slumpWarning(DayView v) {
  final by = List.filled(8, 0);
  for (final d in {...v.master.missedDays, ...v.master.frozenDays}) {
    by[weekdayOf(d)]++;
  }
  final worst = by.reduce((a, b) => a > b ? a : b);
  if (worst < 2 || by.indexOf(worst) != weekdayOf(v.today)) return null;
  return 'This is the weekday you most often miss ($worst times). Go small on purpose today: two minutes, early.';
}

/// 541: the time you actually tend to start (median of the last 14 first starts).
int? learnedCue(DayView v) {
  final xs = [for (final e in firstStartMinute(v).entries) if (e.key > v.today - 14) (e.value + v.dayEndHour * 60) % 1440]..sort();
  return xs.length < 5 ? null : xs[xs.length ~/ 2];
}

/// 547: three reflection prompts chosen from how the week went.
List<String> reflectionPrompts(DayView v) {
  final w = weekOf(v.today);
  final days = v.showedUpDays.where((d) => weekOf(d) == w).length;
  return [
    days >= 5 ? 'You showed up $days days this week. What made starting easy?' : 'You showed up $days days this week. What got in the way on the other days?',
    mostPostponedTitle(v) == null ? 'Which task are you glad you started early?' : 'What is it about "${mostPostponedTitle(v)}" that keeps it waiting?',
    v.master.comebacks > 0 ? 'You have come back ${v.master.comebacks} times. What do you tell yourself on the day you return?' : 'What would help you return quickly after a missed day?',
  ];
}

String? mostPostponedTitle(DayView v) {
  final open = v.of(Kind.task).where((t) => !t.flag('done') && t.integer('postponed') + t.integer('moved') > 0).toList()
    ..sort((a, b) => (b.integer('postponed') + b.integer('moved')).compareTo(a.integer('postponed') + a.integer('moved')));
  return open.isEmpty ? null : open.first.str('title');
}

/// 549: fixes (from the feeling tools) that were followed by a finished session the same day.
Map<String, int> whatWorked(DayView v) {
  final m = <String, int>{};
  for (final e in v.type(Ev.tool)) {
    final c = e.get<String>('choice');
    if ((e.get<int>('n') == 277 || e.get<int>('n') == 281) && c != null && v.sessionDays.contains(e.day)) m[c] = (m[c] ?? 0) + 1;
  }
  return m;
}

/// 579: one live tool you have never used, changing weekly.
ToolDef? spotlight(DayView v, Map<int, ToolDef> tools) {
  final used = {for (final e in v.type(Ev.tool)) e.get<int>('n')};
  final unused = tools.values.where((t) => v.on(t.n) && !used.contains(t.n) && t.kind != 'card').toList();
  return unused.isEmpty ? null : unused[weekOf(v.today) % unused.length];
}

/// 582: raise a target after hitting it 80% of the time, lower it under 50%.
int autoDifficulty(int target, int hits, int tries, {int step = 1, int min = 1}) {
  if (tries < 4) return target;
  final rate = hits / tries;
  if (rate >= 0.8) return target + step;
  if (rate < 0.5) return (target - step) < min ? min : target - step;
  return target;
}

/// 596: the minimum feels easy when the last 10 sessions all ran 10+ minutes.
bool minimumFeelsEasy(DayView v) {
  final last = v.type(Ev.sessionDone).toList().reversed.take(10).toList();
  return last.length == 10 && last.every((e) => (e.get<num>('minutes') ?? 0) >= 10);
}

/// 600: reminders are off for 7 days from the day the test was switched on.
bool graduationTestRunning(DayView v) =>
    v.flagOn(600) && v.kv['gradTest'] == '1' && v.today - v.settingInt('gradTestFrom', v.today) < 7;

final Map<String, Stat> coachStats = {
  'spotlight': (v) => ['Open the Toolbox', 'The suggestion is shown at the top of the Toolbox each week.'],
  'weekOne': (v) {
    final m = weekOne(v);
    return ['${m.where((x) => x.$2).length} of 7', for (final (t, ok) in m) '${ok ? '✓' : '○'} $t', 'All seven earns the Starter badge.'];
  },
  'weekOneReport': (v) {
    final f = firstDay(v) ?? v.today;
    bool wk(Event e) => e.day < f + 7;
    return [
      '${v.showedUpDays.where((d) => d < f + 7).length} of 7 days',
      'in your first week',
      '${v.type(Ev.sessionDone).where(wk).length} sessions, ${v.type(Ev.proof).where(wk).length} proofs, ${v.type(Ev.habitTick).where(wk).length} habit ticks',
    ];
  },
  'coachPlan': (v) => ['Draft for today', ...morningPlan(v), 'A draft from your due dates and free slots. Change anything.'],
  'priority': (v) {
    final t = autoPriority(v);
    return t.isEmpty ? ['Nothing open', ''] : [t.first.str('title'), 'comes first: earliest due date, then smallest', for (final x in t.skip(1).take(6)) '• ${x.str('title')}'];
  },
  'slump': (v) => [slumpWarning(v) == null ? 'No warning today' : 'Heads up', slumpWarning(v) ?? 'Today is not one of the days you usually miss.'],
  'cueLearn': (v) {
    final c = learnedCue(v);
    return c == null
        ? ['Not enough data', 'After five days with a session, this shows when you really tend to start.']
        : [hhmm(c), 'is when you usually start in practice', 'Your cue alarm is set to ${hhmm(v.cueMinute)}. Moving it closer to this may make it easier to obey.'];
  },
  'reflect': (v) => ['This week', ...reflectionPrompts(v)],
  'worked': (v) {
    final w = whatWorked(v);
    return w.isEmpty
        ? ['Nothing recorded yet', 'When you pick a feeling in the Feeling tools and then finish a session that day, it is counted here.']
        : ['What worked before', for (final e in w.entries) '"${e.key}" was followed by a session ${e.value} times'];
  },
  'interview': (v) => [
        '${v.projects.length} projects',
        for (final p in v.projects) ...[
          'What problem does ${p.str('name')} solve, and for whom?',
          'What was the hardest bug or decision in ${p.str('name')}?',
        ],
        if (v.projects.isEmpty) 'Add projects on the Plan tab and questions about them appear here.',
      ],
  'staleness': (v) {
    final last = v.toolEvents(581).lastOrNull;
    return [last == null ? 'Not asked yet' : 'Asked ${dayLabel(last.day)}', 'Is this app still helping? If yes, tap the button. If no, switch on Simple mode or turn features off in Settings.'];
  },
  'audit': (v) => [
        '${v.allHabits.length} habits',
        for (final h in v.allHabits) '${h.str('name')}: ${v.habitDays(h.id).where((d) => d > v.today - 90).length} days in the last 90',
        'Archive the ones that no longer matter. Fewer habits, kept, beat many habits dropped.',
      ],
  'letters': (v) {
    final d = v.master.totalDays;
    const letters = {
      30: 'Thirty days. A month ago you were not sure you could do one. This is real evidence now.',
      100: 'A hundred days. Most people never see this number. Starting is simply what you do.',
      365: 'A year of days. Whoever you were when you installed this would not recognise your Vault.',
    };
    final got = letters.entries.where((e) => d >= e.key).toList();
    return got.isEmpty ? ['$d days', 'Letters arrive at 30, 100 and 365 days shown up.'] : ['${got.length} letters', for (final e in got) '${e.key} days: ${e.value}'];
  },
  'year': (v) {
    final y = dateOfDay(v.today).year;
    bool inY(int d) => dateOfDay(d).year == y;
    final done = v.type(Ev.sessionDone).where((e) => inY(e.day));
    return [
      '$y',
      '${v.showedUpDays.where(inY).length} days shown up',
      '${done.length} sessions, ${(done.fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt()) / 60).toStringAsFixed(1)} hours',
      '${v.type(Ev.proof).where((e) => inY(e.day)).length} proofs, longest streak ${v.master.longest} days',
    ];
  },
  'longGame': (v) {
    final per = <int, int>{};
    for (final e in v.type(Ev.sessionDone)) {
      final y = dateOfDay(e.day).year;
      per[y] = (per[y] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
    }
    return per.isEmpty ? ['No data yet', ''] : ['${per.length} years', for (final e in (per.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) '${e.key}: ${(e.value / 60).toStringAsFixed(1)} hours'];
  },
  'upgrade': (v) => [
        minimumFeelsEasy(v) ? 'Ready for more' : 'Two minutes is right',
        minimumFeelsEasy(v)
            ? 'Your last ten sessions all ran ten minutes or more. If you want, switch on the Ramp ladder. Two minutes will always still count.'
            : 'The minimum is doing its job. No need to raise it.',
      ],
  'gradTest': (v) => [
        graduationTestRunning(v) ? 'Running' : v.kv['gradTest'] == '1' ? 'Finished' : 'Off',
        graduationTestRunning(v)
            ? 'Reminders are off. Day ${v.today - v.settingInt('gradTestFrom', v.today) + 1} of 7.'
            : 'Switch it on to turn every reminder off for a week and see if the habit holds by itself.',
        if (v.kv['gradTest'] == '1')
          'Days shown up since it began: ${v.showedUpDays.where((d) => d >= v.settingInt('gradTestFrom', v.today)).length}.',
      ],
};
