/// Computed read-outs used by "stat" tools and the insights screens. Each
/// function returns lines of plain text: the first is the headline. Pure Dart.
library;

import 'challenges.dart';
import 'day.dart';
import 'deadlines.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'game.dart';
import 'planning.dart';
import 'projects.dart';
import 'tools.dart';
import 'streak_engine.dart';

typedef Stat = List<String> Function(DayView v);

String _plural(int n, String one, [String? many]) => n == 1 ? '1 $one' : '$n ${many ?? '${one}s'}';

Iterable<Event> _done(DayView v) => v.type(Ev.sessionDone);
int _minutes(Iterable<Event> e) => e.fold(0, (a, x) => a + (x.get<num>('minutes') ?? 0).toInt());

/// First session start per day: day -> minute of day.
Map<int, int> firstStartMinute(DayView v) {
  final m = <int, int>{};
  for (final e in v.type(Ev.sessionStart)) {
    // Minutes after the day boundary, so 01:00 sorts after 23:00.
    final mins = (e.moment.minuteOfDay - v.dayEndHour * 60) % 1440;
    if (!m.containsKey(e.day) || mins < m[e.day]!) m[e.day] = mins;
  }
  return m;
}

/// Feature 3: days the app was opened before the chosen hour.
Set<int> openedEarlyDays(DayView v) {
  final by = v.settingInt('openBy', 10) * 60;
  return {
    for (final e in v.type(Ev.appOpen))
      if (e.moment.minuteOfDay < by && e.moment.minuteOfDay >= v.dayEndHour * 60) e.day
  };
}

/// Feature 24 and 438: average minutes between the cue time and the first start.
double? startDelay(DayView v, {int lastDays = 14}) {
  final first = firstStartMinute(v);
  final delays = <int>[];
  for (final e in first.entries) {
    if (e.key <= v.today - lastDays) continue;
    final cue = (rulesCue(v, e.key) - v.dayEndHour * 60) % 1440;
    delays.add(e.value > cue ? e.value - cue : 0);
  }
  if (delays.isEmpty) return null;
  return delays.reduce((a, b) => a + b) / delays.length;
}

int rulesCue(DayView v, int day) {
  for (final e in v.events.reversed) {
    if (e.type == Ev.planSet && e.get<int>('forDay') == day) return e.get<int>('cueMinute') ?? v.cueMinute;
  }
  return v.cueMinute;
}

/// Feature 25: days with any real action logged.
Set<int> nonZeroDays(DayView v) => {
      for (final e in v.events)
        if (const {Ev.sessionDone, Ev.habitTick, Ev.proof, Ev.taskDone, Ev.tool}.contains(e.type)) e.day
    };

/// Feature 69 and 443: share of the last [days] days with a finished session or tick.
int consistency(DayView v, {int days = 30}) {
  final n = [for (var d = v.today - days + 1; d <= v.today; d++) d].where(v.showedUpDays.contains).length;
  return (n * 100 / days).round();
}

List<String> _streakLines(DayView v, Set<int> days, String what) {
  final s = computeStreak(days, v.today, rules: v.streakRules);
  return ['${s.current}', 'days in a row $what', 'Longest: ${s.longest}. Total: ${s.totalDays}.'];
}

/// Feature 35: days with a session started before noon.
Set<int> beforeNoonDays(DayView v) => {
      for (final e in v.type(Ev.sessionStart))
        if (e.moment.minuteOfDay < 12 * 60 && e.moment.minuteOfDay >= v.dayEndHour * 60) e.day
    };

/// Feature 36: tasks finished 24 hours or more before their due day ends.
List<Rec> earlySubmissions(DayView v) => [
      for (final t in v.of(Kind.task))
        if (t.flag('done') && t.data['due'] is int && t.data['doneTs'] is int)
          if (dayEndWallMs(t.integer('due'), v.dayEndHour) - (t.integer('doneTs') + v.now.offsetMin * msPerMinute) >= msPerDay) t
    ];

/// Feature 37: days that had a locked first task and a finished session.
Set<int> planKeptDays(DayView v) => {
      for (final e in v.type(Ev.planSet))
        if (v.sessionDays.contains(e.get<int>('forDay'))) e.get<int>('forDay')!
    };

/// Feature 38: days the "I am up" tap came no later than 30 minutes after target.
Set<int> wakeOnTimeDays(DayView v) {
  final target = v.settingInt('wakeTarget', 7) * 60;
  return {
    for (final e in v.type(Ev.tool))
      if (e.get<int>('n') == 38 && e.moment.minuteOfDay <= target + 30 && e.moment.minuteOfDay >= v.dayEndHour * 60) e.day
  };
}

/// Feature 63: the weekday and the autopsy reason that repeat most.
List<String> missPattern(DayView v) {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final byDay = List.filled(7, 0);
  for (final d in {...v.master.missedDays, ...v.master.frozenDays}) {
    byDay[weekdayOf(d) - 1]++;
  }
  final reasons = <String, int>{};
  for (final e in v.type(Ev.tool)) {
    final c = e.get<String>('choice');
    if (e.get<int>('n') == 62 && c != null) reasons[c] = (reasons[c] ?? 0) + 1;
  }
  final total = byDay.fold(0, (a, b) => a + b);
  if (total == 0) return ['No misses yet', 'Nothing to find a pattern in. Good problem to have.'];
  final top = byDay.indexOf(byDay.reduce((a, b) => a > b ? a : b));
  final lines = [names[top], 'is your most-missed day (${byDay[top]} of $total missed days).'];
  if (reasons.isNotEmpty) {
    final r = reasons.entries.reduce((a, b) => a.value >= b.value ? a : b);
    lines.add('Most common reason you gave: "${r.key}" (${r.value} times).');
  }
  lines.add('Idea: shrink that day to the tiny version in advance.');
  return lines;
}

List<String> _challenge(Challenge c, [String extra = '']) => [
      c.done ? 'Done' : '${c.have} / ${c.need}',
      c.title,
      if (c.xp > 0) c.done ? 'Paid ${c.xp} XP.' : 'Pays ${c.xp} XP when finished.',
      if (extra.isNotEmpty) extra,
    ];

final Map<String, Stat> stats = {
  'level': (v) {
    final l = levelFor(v.xpTotal);
    return ['Level $l', '${xpForLevel(l + 1) - v.xpTotal} XP to level ${l + 1}', 'A slow curve on purpose. It rewards years, not one big week.'];
  },
  'quests': (v) {
    final q = dailyQuests(v, v.today);
    return ['${q.where((x) => x.$2).length} of 3', for (final (t, ok) in q) '${ok ? '✓' : '○'} $t', '10 XP each. All three also pay 5 coins.'];
  },
  'chest': (v) => [
        '${v.type(Ev.sessionDone).where((e) => chestFor(e.get<String>('sid') ?? '') > 0).length} chests',
        'opened so far. About one finished session in four has one.',
        '${sinceChest(v)} sessions since the last one.',
      ],
  'records': (v) {
    final r = records(v);
    return [
      '${r.bestDayMinutes} min',
      r.bestDay < 0 ? 'Your best day will show here.' : 'is your best day (${dayLabel(r.bestDay)})',
      'Best week: ${r.bestWeekMinutes} min',
      'Longest streak: ${r.longestStreak} days',
      'Longest session: ${r.longestSession} min',
    ];
  },
  'season': (v) {
    final s = seasons(v);
    return ['${s.now} vs ${s.last} min', 'this 12-week season against the last one at the same point', 'The only rival is your last season.'];
  },
  'combo': (v) => ['x${combo(v)}', 'sessions finished today', 'Each one raises the combo. It resets when the day ends.'],
  'skills': (v) {
    final t = skillTrees(v);
    return t.isEmpty
        ? ['No projects', 'Each project is a skill. Hours in it move it up: 1, 10, 50, 100, 500, 1000.']
        : ['${t.length} skills', for (final (n, h, tier) in t) '$n: ${h.toStringAsFixed(1)} h · tier $tier of 6'];
  },
  'prestige': (v) => [
        '${'★' * prestige(v)}${prestige(v) == 0 ? 'No stars yet' : ''}',
        'Each time you pass ${v.ranks.last.name}, you earn a star and climb the ladder again.',
        'Everything you unlocked stays unlocked.',
      ],
  'focus': (v) {
    final f = averageFocus(v);
    return f == null ? ['-', 'No sessions yet.'] : ['$f', 'average focus score out of 100', '100 minus 15 per pause and 5 per noticed wander.'];
  },
  'deep': (v) => [
        '${deepMinutes(v, day: v.today)} / ${deepTarget(v)} min',
        'of deep work today (sessions marked DEEP on the Timer tab)',
        'Lifetime deep work: ${(deepMinutes(v) / 60).toStringAsFixed(1)} hours. The target stops at 4 hours a day on purpose.',
      ],
  'confirm': (v) {
    final ok = v.type(Ev.tool).any((e) => e.get<int>('n') == 177 && e.day == v.today);
    return [ok ? 'Confirmed' : 'Not yet', 'First task today: ${v.nextStep}', 'Alarm at ${hhmm(v.todayPlan?.cueMinute ?? v.cueMinute)}.'];
  },
  'capacity': (v) {
    final cap = dailyCapacity(v);
    final asked = deadlines(v).fold(0, (a, t) => a + t.quota);
    return [
      '$cap min a day',
      'is your real pace over the last 14 days (never shown below 25)',
      'Your deadlines ask for $asked minutes today.',
      asked > cap ? 'That is more than your history supports. Cut scope or start earlier, rather than promise more.' : 'That fits.',
    ];
  },
  'slots': (v) {
    final s = freeSlots(v, weekdayOf(v.today));
    return [
      '${s.length} free slots today',
      for (final (a, b) in s) '${hhmm(a)} to ${hhmm(b)} (${b - a} min)',
      'Leave the last one empty as a buffer for overruns.',
      'Add your classes in the Timetable tool so the gaps are real.',
    ];
  },
  'peak': (v) {
    final p = peakHour(v);
    return p == null
        ? ['No data yet', 'After a few sessions this shows the hour you get the most done.']
        : ['${two(p)}:00', 'is the hour you have done the most work in', 'Put the hardest task there. Keep easy admin for the slow hours.'];
  },
  'targets': (v) {
    final t = weeklyTargets(v);
    return t.isEmpty
        ? ['No targets', 'Set sessions per week for a project in the Weekly targets tool.']
        : ['${t.where((x) => x.$2 >= x.$3).length} of ${t.length} hit', for (final (n, have, need) in t) '$n: $have of $need sessions this week'];
  },
  'scoreboard': (v) {
    final s = scoreboard(v);
    return ['${s['Minutes']} min', 'of work this week', for (final e in s.entries) '${e.key}: ${e.value}'];
  },
  'planActual': (v) => [
        'Last 7 days',
        for (final (d, p, a) in planVsActual(v))
          '${dayLabel(d)}: planned ${p == null ? '-' : hhmm(p)}, started ${a == null ? '-' : hhmm(a)}',
      ],
  'estRatio': (v) {
    final r = estimateRatio(v);
    return [
      '${r.toStringAsFixed(1)}x',
      'is how long your tasks really take compared with your guesses',
      'So a 50-minute guess is more like ${correctedEstimate(v, 50)} minutes for you.',
      'Based on finished tasks that had an estimate and logged sessions.',
    ];
  },
  'openLoops': (v) {
    final l = openLoops(v);
    return ['${l.length}', 'half-done tasks waiting for you', for (final t in l) '• ${t.str('title')}'];
  },
  'load': (v) {
    final cal = loadCalendar(v);
    final busy = cal.where((w) => w.count > 0).toList();
    if (busy.isEmpty) return ['Clear', 'No due dates in the next 8 weeks. Give tasks a due date on the Plan tab.'];
    return [
      '${busy.length} busy weeks',
      for (final w in busy)
        'Week of ${dayLabel(weekStart(w.week))}: ${w.count} due, ${w.minutes} min left'
            '${w.collision ? '. Three or more land together: start the earliest one now.' : ''}',
    ];
  },
  'debt': (v) {
    final d = deadlines(v).fold(0, (a, t) => a + t.debt);
    return ['$d min', 'behind an even pace, across all deadlines', d == 0 ? 'Nothing owed. Enjoy it.' : 'One session takes ${d < sessionSize ? d : sessionSize} minutes off this number.'];
  },
  'firstTouch': (v) {
    final open = deadlines(v).where((t) => t.firstTouchOpen).toList();
    return [
      '${open.length}',
      'new tasks still waiting for their first 5 minutes (within 24 hours of being added)',
      for (final t in open) '• ${t.task.str('title')}',
    ];
  },
  'dayOne': (v) {
    final all = deadlines(v, open: false);
    return ['${all.where((t) => t.dayOne).length} of ${all.length}', 'tasks with a due date were touched on the day they were added'];
  },
  'buffer': (v) {
    final (early, total) = submissionBuffer(v);
    return ['$early of $total', 'finished tasks beat their due date by 12 hours or more', 'The goal is a calm last evening.'];
  },
  'neck': (v) {
    final n = deadlines(v).where((t) => t.neckLevel).toList();
    return [
      n.isEmpty ? 'All clear' : '${n.length} at neck level',
      n.isEmpty ? 'Every deadline still fits in the time left at your usual pace.' : 'These need more than your usual pace allows. Shrinking the task is allowed.',
      for (final t in n) '• ${t.task.str('title')}: ${t.left} min left, ${t.daysLeft} days',
    ];
  },
  'daily': (v) => _challenge(dailyChallenge(v, v.today), 'A new one every day.'),
  'boss': (v) => _challenge(weeklyBoss(v, weekOf(v.today)), 'Judged on Sunday night. Next week it asks for one more than this week.'),
  'campaign': (v) => _challenge(monthlyCampaign(v, monthKey(v.today))),
  'mission': (v) {
    final m = missionCard(v, v.today);
    return m == null ? ['No mission today', 'Missions turn up on some days only. Check back tomorrow.'] : _challenge(m);
  },
  'beat': (v) => _challenge(beatYesterday(v)),
  'ghost': (v) {
    final g = ghostRace(v);
    if (g.bestDay < 0) return ['No ghost yet', 'After your first full day there will be a best day to race.'];
    return [
      '${g.youNow} vs ${g.ghostNow} min',
      'You today against your best day (${dayLabel(g.bestDay)}) at this same hour.',
      'That day ended on ${g.bestTotal} minutes.',
      g.youNow >= g.ghostNow ? 'You are ahead of your own ghost.' : 'The ghost is ahead. One session narrows it.',
    ];
  },
  'wander': (v) => ['${wanderCount(v)}', 'times you noticed your mind drift and came back', 'Noticing is the skill. There is no penalty for a tap.'],
  'overruns': (v) => ['${breakOverruns(v)}', 'breaks that ran over', 'Counted only so you can see it. Nothing is taken away.'],
  'comebacks': (v) => ['${v.master.comebacks}', 'times you came back after a miss', 'Coming back is the skill. This number is worth more than the streak.'],
  'missPattern': missPattern,
  'freshStart': (v) {
    final f = freshStart(v.today, birthday: v.kv['t.65'] == null ? '' : v.single(const ToolDef(n: 65, kind: 'single', title: '', prompts: [''])).first);
    return [f == null ? 'Not today' : 'Today', f == null ? 'Next clean page: the coming Monday or the 1st, whichever is sooner.' : 'It is $f: a natural day to start a fresh page.'];
  },
  'beforeNoon': (v) => _streakLines(v, beforeNoonDays(v), 'with a session started before noon'),
  'earlySubmit': (v) {
    final n = earlySubmissions(v).length;
    return ['$n', 'tasks finished a full day or more before they were due', 'Give a task a due date by opening it from the Plan tab.'];
  },
  'planKept': (v) => _streakLines(v, planKeptDays(v), 'with the planned first task followed by a session'),
  'wake': (v) => _streakLines(v, wakeOnTimeDays(v), 'up within 30 minutes of your target'),
  'review': (v) => _streakLines(v, {for (final e in v.type(Ev.tool)) if (e.get<int>('n') == 426) e.day}, 'with the evening reflection done'),
  'upload': (v) => _streakLines(v, {for (final e in v.type(Ev.proof)) e.day}, 'with proof saved'),
  'chain': (v) => ['${inDayChain(v)}', 'sessions back to back today', 'A new session within 15 minutes of the last one extends the chain.'],
  'openStreak': (v) {
    final s = computeStreak(openedEarlyDays(v), v.today);
    return [
      '${s.current}',
      'days in a row opened before ${hhmm(v.settingInt('openBy', 10) * 60)}',
      'Longest: ${s.longest}. Opening the app is the smallest start there is.',
    ];
  },
  'startCount': (v) => ['${v.starts}', 'times started, ever', 'This number only goes up.'],
  'startDelay': (v) {
    final d = startDelay(v);
    if (d == null) return ['-', 'No sessions in the last 14 days yet.'];
    return [
      '${d.round()} min',
      'average gap between your cue time and your first start (last 14 days)',
      d < 10 ? 'That is close to on-the-dot.' : 'The goal is only to shrink it a little each week.',
    ];
  },
  'noZero': (v) {
    final nz = nonZeroDays(v);
    return [
      nz.contains(v.today) ? 'Not a zero' : 'Still open',
      nz.contains(v.today) ? 'Today already has something logged.' : 'Any one logged action keeps today from being a zero.',
      '${_plural(nz.length, 'non-zero day')} so far.',
    ];
  },
  'totalDays': (v) => ['${v.master.totalDays}', 'days shown up in total', 'Never resets, whatever the streak does.'],
  'consistency': (v) => ['${consistency(v)}%', 'of the last 30 days had a session or a habit tick'],
  'lifetime': (v) => [
        '${v.starts} starts',
        '${(_minutes(_done(v)) / 60).toStringAsFixed(1)} hours of work',
        _plural(v.type(Ev.proof).length, 'proof upload'),
        '${_plural(v.master.totalDays, 'day')} shown up',
      ],
};
