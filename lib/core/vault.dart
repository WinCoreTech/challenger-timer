/// Work vault helpers (features 126 to 150). Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'extras.dart';

/// 140: free-text search over proof text, task title, project name and tag.
List<Rec> searchProofs(DayView v, String query, {String? projectId}) {
  final q = query.trim().toLowerCase();
  return [
    for (final p in v.proofs)
      if (projectId == null || p.str('projectId') == projectId)
        if (q.isEmpty ||
            [p.str('value'), p.str('title'), p.str('tag'), p.str('unit'), v.rec(p.str('projectId'))?.str('name') ?? '']
                .any((s) => s.toLowerCase().contains(q)))
          p
  ];
}

/// 139: items pinned as "proof I can do hard things".
List<Rec> pinned(DayView v) => v.proofs.where((p) => p.flag('pinned')).toList();

/// 142: lifetime totals per unit (words, pages, problems).
Map<String, int> unitTotals(DayView v) {
  final m = <String, int>{};
  for (final p in v.proofs) {
    final u = p.str('unit');
    if (u.isNotEmpty) m[u] = (m[u] ?? 0) + p.integer('units');
  }
  return m;
}

/// 148: proof saved on this date one month and one year ago.
List<(String, Rec)> onThisDay(DayView v) {
  final t = dateOfDay(v.today);
  final monthAgo = dayOfDate(t.year, t.month - 1, t.day);
  final yearAgo = dayOfDate(t.year - 1, t.month, t.day);
  return [
    for (final p in v.proofs)
      if (p.integer('day') == monthAgo) ('A month ago', p) else if (p.integer('day') == yearAgo) ('A year ago', p)
  ];
}

/// 147: the vault counts as backed up if an export happened after the
/// newest proof, or within the last 7 days.
bool backupStale(DayView v) {
  if (v.proofs.isEmpty) return false;
  final last = v.settingInt('lastExport', 0);
  return last == 0 || v.now.ms - last > 7 * msPerDay;
}

/// 135: everything done on [day], as plain lines.
List<String> dailyPage(DayView v, int day) {
  final sessions = v.type(Ev.sessionDone).where((e) => e.day == day).toList();
  final minutes = sessions.fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
  final habits = {for (final e in v.type(Ev.habitTick)) if (e.day == day) v.rec(e.get<String>('habitId'))?.str('name') ?? 'Habit'};
  return [
    dayLabel(day),
    '${sessions.length} sessions, $minutes minutes',
    for (final p in v.proofs.where((p) => p.integer('day') == day).toList().reversed)
      '• ${p.str('type') == 'photo' ? 'Photo' : p.str('type') == 'voice' ? 'Voice note' : p.str('value')}'
          '${p.str('title').isEmpty ? '' : ' (${p.str('title')})'}',
    if (habits.isNotEmpty) 'Habits: ${habits.join(', ')}',
    for (final e in v.type(Ev.parkingNote).where((e) => e.day == day)) 'Next step left: ${e.get<String>('text')}',
  ];
}

/// 136: the current week as a shareable text block.
String weeklyDigest(DayView v) {
  final w = weekOf(v.today);
  final days = v.showedUpDays.where((d) => weekOf(d) == w).length;
  final sessions = v.type(Ev.sessionDone).where((e) => weekOf(e.day) == w).toList();
  final minutes = sessions.fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt());
  final proofs = v.proofs.where((p) => weekOf(p.integer('day')) == w).length;
  return [
    '${v.name.isEmpty ? 'My' : "${v.name}'s"} week',
    '$days of 7 days shown up',
    '${sessions.length} sessions, $minutes minutes of work',
    '$proofs pieces of proof saved',
    'Streak: ${v.master.current} days',
    'Rank: ${v.rank.rank.name}',
  ].join('\n');
}

/// 138: finished things, newest first: done tasks and saved proof lines.
List<(int day, String text)> doneList(DayView v) {
  final out = <(int, String)>[
    for (final t in v.of(Kind.task))
      if (t.flag('done'))
        (t.data['doneTs'] is int ? dayOf(t.integer('doneTs'), v.now.offsetMin, v.dayEndHour) : v.today, 'Task: ${t.str('title')}'),
    for (final p in v.proofs)
      if (p.str('type') == 'text') (p.integer('day'), p.str('value')),
  ];
  out.sort((a, b) => b.$1.compareTo(a.$1));
  return out;
}

/// 143: chosen items as a Markdown block for a resume or portfolio.
String portfolioExport(DayView v) {
  final items = pinned(v);
  final b = StringBuffer('# Work I can show\n');
  for (final p in items) {
    final proj = v.rec(p.str('projectId'))?.str('name');
    b.writeln('- ${dayLabel(p.integer('day'))}${proj == null ? '' : ' · $proj'}: '
        '${p.str('type') == 'photo' ? 'photo (${p.str('value')})' : p.str('value')}');
  }
  return b.toString();
}

/// 134: for each project with two or more photos, the first and the latest.
List<(String project, Rec before, Rec after)> beforeAfter(DayView v) {
  final by = <String, List<Rec>>{};
  for (final p in v.proofs.reversed) {
    if (p.str('type') == 'photo') (by[p.str('projectId')] ??= []).add(p);
  }
  return [
    for (final e in by.entries)
      if (e.value.length >= 2) (v.rec(e.key)?.str('name') ?? 'No project', e.value.first, e.value.last)
  ];
}
