/// Persuasion features (601 to 701). Every one of them sits behind the
/// pressure dial (701): Gentle, Firm or Relentless. Raising the dial is
/// instant, lowering takes 24 hours, and it never starts above Gentle.
/// None of them may schedule anything inside the sleep window. Pure Dart.
library;

import 'dart:convert';

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';
import 'flags.dart';
import 'rules.dart';
import 'stats.dart';
import 'tools.dart';

/// Dial level each feature needs. Anything not listed needs only Gentle.
const firmFeatures = {601, 603, 610, 611, 615, 616, 620, 621, 624, 629, 634, 635, 636, 648, 682, 683, 684, 695, 696, 697, 698, 700};
const relentlessFeatures = {633, 637, 641};

Pressure needFor(int n) => relentlessFeatures.contains(n)
    ? Pressure.relentless
    : firmFeatures.contains(n)
        ? Pressure.firm
        : Pressure.gentle;

class Dial {
  const Dial(this.level, {this.lowerTo, this.lowerAt});
  factory Dial.parse(String? s) {
    if (s == null) return const Dial(0);
    final j = jsonDecode(s) as Map;
    return Dial(j['level'] as int, lowerTo: j['lowerTo'] as int?, lowerAt: j['lowerAt'] as int?);
  }
  final int level;
  final int? lowerTo, lowerAt;

  /// The level in force now: a pending lowering applies only after its time.
  int effective(int nowMs) => lowerAt != null && nowMs >= lowerAt! ? lowerTo! : level;
  bool pending(int nowMs) => lowerAt != null && nowMs < lowerAt!;

  Dial set(int to, int nowMs) {
    final cur = effective(nowMs);
    if (to >= cur) return Dial(to.clamp(0, 2));
    return Dial(cur, lowerTo: to.clamp(0, 2), lowerAt: nowMs + offDelayMs);
  }

  Dial cancel(int nowMs) => Dial(effective(nowMs));
  String encode() => jsonEncode({'level': level, 'lowerTo': lowerTo, 'lowerAt': lowerAt});
}

Dial dialOf(DayView v) => Dial.parse(v.kv['pressure']);
bool dialAllows(DayView v, int n) => n < 601 || n > 700 || dialOf(v).effective(v.now.ms) >= needFor(n).index;

// ---- loss and ownership ---------------------------------------------------------
/// 601: of the 100 points in the wallet, what was left when the first
/// session of [day] started (they drain evenly over the day).
int depositKept(DayView v, int day) {
  Event? first;
  for (final e in v.type(Ev.sessionStart)) {
    if (e.day == day) {
      first = e;
      break;
    }
  }
  if (first == null) return 0;
  return (100 * dayFractionLeft(first.moment, v.dayEndHour)).round().clamp(0, 100);
}

/// 616: 3x at your wake hour, falling a quarter per hour to 1x.
double fallingMultiplier(DayView v, Moment at) {
  final hours = ((at.minuteOfDay - v.settingInt('wakeHour', 7) * 60) % 1440) / 60;
  return (3 - 0.25 * hours).clamp(1.0, 3.0);
}

/// 605: minutes worked on the days of the current streak.
int streakMinutes(DayView v) {
  var n = 0;
  var d = v.showedUpDays.contains(v.today) ? v.today : v.today - 1;
  var left = v.master.current;
  while (left > 0 && d > v.today - 2000) {
    if (v.showedUpDays.contains(d)) {
      left--;
      n += v.type(Ev.sessionDone).where((e) => e.day == d).fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
    }
    d--;
  }
  return n;
}

/// 606: exactly what is lost if today ends with no session.
List<String> lossPreview(DayView v) => v.workedToday
    ? const ['Nothing is at risk. Today is done.']
    : [
        if (v.bonusAtRisk) 'The 100 XP bonus you are holding',
        if (v.master.current > 0) v.master.freezesLeft > 0 ? 'One of your ${v.master.freezesLeft} freezes' : 'Your ${v.master.current}-day streak gets paused',
        if (wagers(v).any((w) => w.state == 'open') && v.master.freezesLeft == 0) 'Your open streak wager',
        if (jackpot(v) > 0) 'The jackpot pool of ${jackpot(v)} XP resets',
        'Today\'s daily challenge and quests',
      ];

/// 608: 0 healthy, 1 drooping, 2 wilted. Recovers the day you return.
int plantState(DayView v) => v.workedToday ? 0 : daysAway(v).clamp(0, 2);

/// 623: days with three or more sessions.
Set<int> goldenDays(DayView v) {
  final per = <int, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    per[e.day] = (per[e.day] ?? 0) + 1;
  }
  return {for (final e in per.entries) if (e.value >= 3) e.key};
}

/// 624: streak insurance bought with coins (20 each) adds one freeze.
List<int> insuranceDays(DayView v) => [for (final e in v.type(Ev.tool)) if (e.get<int>('n') == 624) e.day];

/// 685: grows 10 XP per worked day in a row, back to zero after a zero day.
int jackpot(DayView v) {
  var n = 0;
  for (var d = v.workedToday ? v.today : v.today - 1; v.sessionDays.contains(d); d--) {
    n++;
  }
  return n * 10;
}

// ---- commitment ---------------------------------------------------------------------
/// 627/644/650: oaths typed at night and whether the next day had a session.
(int kept, int made) promises(DayView v) {
  final days = {for (final r in v.of('t627')) r.integer('day')}.where((d) => d < v.today);
  return (days.where((d) => v.sessionDays.contains(d + 1)).length, days.length);
}

/// 644: each kept promise allows a slightly bigger one.
int nextPromiseMinutes(DayView v) => (2 + promises(v).$1).clamp(2, 60);

/// 640: booked sessions (tool 639) that were followed by a session that day.
(int attended, int booked) attendanceRecord(DayView v) {
  final days = {for (final r in v.of('t639')) r.integer('day')}.where((d) => d < v.today);
  return (days.where(v.sessionDays.contains).length, days.length);
}

/// 645: starts within 10 minutes of the cue time.
int onCueStarts(DayView v) {
  var n = 0;
  for (final e in firstStartMinute(v).entries) {
    final cue = (rulesCue(v, e.key) - v.dayEndHour * 60) % 1440;
    if ((e.value - cue).abs() <= 10) n++;
  }
  return n;
}

/// 646: days since the last day with nothing logged.
int daysSinceZero(DayView v) {
  final nz = nonZeroDays(v);
  var n = 0;
  for (var d = nz.contains(v.today) ? v.today : v.today - 1; nz.contains(d); d--) {
    n++;
  }
  return n;
}

// ---- curiosity hooks: every one opens only by working --------------------------------
int _hash(String s) => s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

const hiddenLines = [
  'The first draft of anything is allowed to be bad.',
  'A page a day is a book a year.',
  'You do not rise to your goals. You fall to your habits.',
  'Clarity comes from doing, not from thinking about doing.',
  'The work you avoid is usually twenty minutes long.',
  'Small and daily beats large and someday.',
  'Nobody remembers the mood. Everybody keeps the result.',
  'Starting is a skill. You are practising it right now.',
];

/// 676/677: one line per session, fixed by the session id.
String hiddenLine(String sid) => hiddenLines[_hash(sid) % hiddenLines.length];

const story = [
  'Meera found the notebook on the last bench of the library, wedged behind the radiator. It had her name on the cover. She had never seen it before.',
  'The first page held one line in her own handwriting: "Day 1. Two minutes. Done." The date was three weeks in the future.',
  'She laughed, put it in her bag, and forgot it until the next evening, when a second line had appeared under the first.',
  'The new line described what she had done that afternoon: opened the DBMS file, read one page, closed it. She had told no one.',
  'On the fourth day the notebook was ahead of her again. It said she would solve one problem before dinner. She solved it out of spite.',
  'By the second week she noticed the handwriting getting steadier. The lines were short. None of them mentioned how she felt.',
  'One page was different. It was torn at the corner and said only: "You will skip tomorrow. Come back the day after. That is the important page."',
  'She did skip. The next morning the notebook was blank where the entry should be, and for the first time she missed it.',
  'She came back. The page filled itself as her pen touched the paper: "Day 15. Returned." Underlined twice.',
  'In the back cover she found a library slip, stamped a year from now, signed by someone with her initials and a job title she did not have yet.',
  'She turned to the last written page. It said: "The notebook only writes what you already did." Below it, the page was empty.',
  'Meera uncapped her pen. Whatever came next, she understood, she would have to write it first. (The story continues as far as you do.)',
];

/// 678: paragraphs unlocked so far: one per finished session.
List<String> storySoFar(DayView v) => story.take(v.type(Ev.sessionDone).length.clamp(0, story.length)).toList();

/// 679: a guaranteed chest on every fifth finished session.
int toFifthChest(DayView v) => 5 - v.type(Ev.sessionDone).length % 5;

/// 680: 5 to 25 XP per saved proof, fixed by the proof's session id.
int spinFor(String sid) => 5 + _hash('spin$sid') % 5 * 5;

/// 681: about one session in a hundred is legendary.
bool legendary(String sid) => _hash('rare$sid') % 100 == 0;

/// 682/683: today's double hour (between 8 and 21).
int doubleHour(int day) => 8 + (day * 7919) % 14;

/// 687: weekdays (1..7) that have had a session.
Set<int> weekdaySet(DayView v) => {for (final d in v.sessionDays) weekdayOf(d)};

/// 688/689: pieces revealed, one per finished session.
int piecesRevealed(DayView v, int total) => v.type(Ev.sessionDone).length % (total + 1);

List<(String, int)> pressureXp(DayView v) {
  final out = <(String, int)>[];
  bool on(int n) => v.flagOn(n) && dialAllows(v, n);
  final done = v.type(Ev.sessionDone).toList();
  if (on(601)) {
    final lost = v.sessionDays.where((d) => d < v.today).fold(0, (a, d) => a + (100 - depositKept(v, d)));
    if (lost > 0) out.add(('Deposit drained before first start', -lost));
  }
  if (on(616)) {
    var x = 0.0;
    final seen = <int>{};
    for (final e in v.type(Ev.sessionStart)) {
      if (seen.add(e.day)) x += (fallingMultiplier(v, e.moment) - 1) * xpStart;
    }
    if (x >= 1) out.add(('Early-in-the-day multiplier', x.round()));
  }
  if (on(679)) {
    final n = done.length ~/ 5;
    if (n > 0) out.add(('Fifth-session chests', n * 20));
  }
  if (on(680)) {
    final x = v.type(Ev.proof).fold(0, (a, e) => a + spinFor(e.get<String>('sid') ?? ''));
    if (x > 0) out.add(('Reward spins', x));
  }
  if (on(682)) {
    final n = v.type(Ev.sessionStart).where((e) => e.moment.hour == doubleHour(e.day)).length;
    if (n > 0) out.add(('Double hour', n * xpStart));
  }
  if (on(684)) {
    var n = 0;
    final opens = v.type(Ev.appOpen).toList();
    for (final s in v.type(Ev.sessionStart)) {
      if (opens.any((o) => o.ts <= s.ts && s.ts - o.ts <= 5 * msPerMinute)) n++;
    }
    if (n > 0) out.add(('Started within five minutes of opening', n * 10));
  }
  if (on(685)) {
    // Paid out each time a run of worked days reaches a multiple of seven.
    var run = 0, paid = 0;
    final days = v.sessionDays.toList()..sort();
    for (final (i, d) in days.indexed) {
      run = i > 0 && days[i - 1] == d - 1 ? run + 1 : 1;
      if (run % 7 == 0) paid += 70;
    }
    if (paid > 0) out.add(('Jackpot pools paid', paid));
  }
  if (on(603)) {
    for (final e in v.toolEvents(603)) {
      final days = [e.day, e.day + 1, e.day + 2];
      if (v.today > e.day + 2 && days.every(v.sessionDays.contains)) out.add(('Rank trial kept', 100));
    }
  }
  return out;
}

/// 603: a trial of the next rank is running and still intact.
bool rankTrialLive(DayView v) {
  final e = v.toolEvents(603).lastOrNull;
  if (e == null || v.today > e.day + 2) return false;
  return [for (var d = e.day; d < v.today; d++) d].every(v.sessionDays.contains);
}

final Map<String, Stat> pressureStats = {
  'streakHours': (v) => ['${(streakMinutes(v) / 60).toStringAsFixed(1)} h', 'of work built this ${v.master.current}-day streak'],
  'lossPreview': (v) => [v.workedToday ? 'Safe' : 'At day end', ...lossPreview(v)],
  'golden': (v) => ['${goldenDays(v).length}', 'golden days: three or more sessions in one day', 'A second, rarer chain.'],
  'jackpot': (v) => ['${jackpot(v)} XP', 'in the pool. It grows 10 a day and pays out 70 on every seventh day in a row.', 'A day with no session empties it.'],
  'promise': (v) {
    final (k, m) = promises(v);
    return ['$k of $m', 'promises kept (a typed oath followed by a session the next day)', 'Your next promise can be ${nextPromiseMinutes(v)} minutes.'];
  },
  'noShow': (v) {
    final (a, b) = attendanceRecord(v);
    return [b == 0 ? '-' : '${(a * 100 / b).round()}%', 'attendance at sessions you booked with yourself ($a of $b)'];
  },
  'label': (v) => [onCueStarts(v) >= 5 ? 'Early Starter' : '${onCueStarts(v)} of 5', onCueStarts(v) >= 5 ? 'Earned: five starts within ten minutes of your cue. A name to live up to.' : 'Start within ten minutes of your cue time five times to earn "Early Starter".'],
  'sinceZero': (v) => ['${daysSinceZero(v)}', 'days since a zero', 'The widget can show this number: switch it on below.'],
  'story': (v) {
    final s = storySoFar(v);
    return s.isEmpty ? ['Locked', 'The first paragraph opens with your first finished session.'] : ['Part ${s.length} of ${story.length}', ...s, if (s.length < story.length) 'The next part opens with your next session.'];
  },
  'nearMiss': (v) => ['${toFifthChest(v)}', toFifthChest(v) == 1 ? 'more session to the chest' : 'more sessions to the chest', 'Every fifth finished session opens one worth 20 XP.'],
  'doubleHour': (v) => ['${two(doubleHour(v.today))}:00', 'is today\'s double hour: a session started in it pays its start XP twice', 'A different hour every day.'],
  'weekdays': (v) {
    const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final s = weekdaySet(v);
    return ['${s.length} of 7', for (var i = 1; i <= 7; i++) '${s.contains(i) ? '✓' : '○'} ${n[i - 1]}'];
  },
  'ladder': (v) => [
        v.rank.rank.name,
        for (final (i, r) in v.ranks.indexed) i <= v.rank.index + 1 ? '${i + 1}. ${r.name}${i == v.rank.index + 1 ? ' (next, at ${r.xp} XP)' : ''}' : '${i + 1}. ???',
      ],
  'diary': (v) => [
        'Last 14 days',
        for (var d = v.today; d > v.today - 14; d--) '${dayLabel(d)}: ${v.showedUpDays.contains(d) ? '${v.type(Ev.sessionDone).where((e) => e.day == d).length} sessions' : '(blank page)'}',
      ],
  'glass': (v) => ['Tomorrow', 'Behind the glass: tomorrow\'s daily challenge (40 XP) and quests (30 XP).', v.workedToday ? 'You worked today, so the pool and streak carry into it.' : 'A session today carries your streak and jackpot into it.'],
};
