/// Data-driven tools. Many features are a prompt, a list, a checklist, a
/// counter, a rating, a preset habit, a preset session, a card or a computed
/// stat. Those are defined in assets/tools.json and rendered by one screen.
/// Pure Dart.
library;

import 'dart:convert';

import 'engine.dart';
import 'events.dart';
import 'streak_engine.dart';

class ToolDef {
  const ToolDef({
    required this.n,
    required this.kind,
    required this.title,
    this.intro = '',
    this.prompts = const [],
    this.items = const [],
    this.choices = const [],
    this.unit = '',
    this.max = 5,
    this.minutes = 2,
    this.task = '',
    this.habit = '',
    this.body = '',
    this.stat = '',
    this.xp = 0,
    this.time = false,
    this.setKey = '',
    this.setLabel = '',
    this.setOptions = const [],
    this.action = '',
    String? optKey,
  }) : optKey = optKey ?? setKey;
  factory ToolDef.fromJson(Map<String, Object?> j) => ToolDef(
        n: j['n'] as int,
        kind: j['kind'] as String,
        title: j['title'] as String,
        intro: j['intro'] as String? ?? '',
        prompts: (j['prompts'] as List?)?.cast<String>() ?? const [],
        items: (j['items'] as List?)?.cast<String>() ?? const [],
        choices: (j['choices'] as List?)?.cast<String>() ?? const [],
        unit: j['unit'] as String? ?? '',
        max: j['max'] as int? ?? 5,
        minutes: j['minutes'] as int? ?? 2,
        task: j['task'] as String? ?? '',
        habit: j['habit'] as String? ?? '',
        body: j['body'] as String? ?? '',
        stat: j['stat'] as String? ?? '',
        xp: j['xp'] as int? ?? 0,
        time: j['time'] == true,
        setKey: j['setKey'] as String? ?? '',
        setLabel: j['setLabel'] as String? ?? '',
        setOptions: (j['setOptions'] as List?)?.cast<int>() ?? const [],
        action: j['action'] as String? ?? '',
        optKey: j['optKey'] as String?,
      );

  /// Feature number this tool implements.
  final int n;

  /// card | single | log | list | check | count | rate | habit | session | stat
  final String kind;
  final String title, intro;
  final List<String> prompts, items, choices;
  final String unit;
  final int max, minutes;
  final String task, habit, body, stat;

  /// Small XP paid per entry (0 for most: rewards are for sessions and proof).
  final int xp;

  /// Log entries carry a time of day and become daily reminders.
  final bool time;

  /// Optional setting shown on the tool: kv key, label and numeric choices.
  /// For kind "toggle" the key holds '1' or '0'; for "dayflag" it holds a day.
  final String setKey, setLabel;
  final List<int> setOptions;

  /// Stat tools may carry one button that logs a plain tool event.
  final String action;

  /// kv key the numeric choices write to (defaults to [setKey]).
  final String optKey;

  String get recKind => 't$n';
  String get kvKey => 't.$n';
}

const toolKinds = {
  'card', 'single', 'log', 'list', 'check', 'count', 'rate', 'habit', 'session', 'stat', 'toggle', 'dayflag', 'special'
};

Map<int, ToolDef> parseTools(String json) =>
    {for (final j in jsonDecode(json) as List) (j as Map)['n'] as int: ToolDef.fromJson(j.cast<String, Object?>())};

extension ToolView on DayView {
  Iterable<Event> toolEvents(int n) => type(Ev.tool).where((e) => e.get<int>('n') == n);
  Set<int> toolDays(int n) => {for (final e in toolEvents(n)) e.day};
  StreakResult toolStreak(int n) => computeStreak(toolDays(n), today);
  int toolSum(int n, {int? day}) => toolEvents(n)
      .where((e) => day == null || e.day == day)
      .fold(0, (a, e) => a + (e.get<num>('add') ?? 0).toInt());

  /// Latest rating per day, oldest first.
  List<(int, int)> toolRatings(int n) {
    final m = <int, int>{};
    for (final e in toolEvents(n)) {
      final v = e.get<num>('value');
      if (v != null) m[e.day] = v.toInt();
    }
    return [for (final d in m.keys.toList()..sort()) (d, m[d]!)];
  }

  /// Checklist items ticked on [day].
  Set<int> checked(int n, int day) =>
      {for (final e in toolEvents(n)) if (e.day == day && e.get<int>('item') != null) e.get<int>('item')!};

  /// Days on which every item of a checklist was ticked.
  Set<int> checkCompleteDays(ToolDef t) {
    final per = <int, Set<int>>{};
    for (final e in toolEvents(t.n)) {
      final i = e.get<int>('item');
      if (i != null) (per[e.day] ??= {}).add(i);
    }
    return {for (final e in per.entries) if (e.value.length >= t.items.length) e.key};
  }

  List<String> single(ToolDef t) {
    final s = kv[t.kvKey];
    if (s == null) return List.filled(t.prompts.length, '');
    final l = (jsonDecode(s) as List).cast<String>();
    return [for (var i = 0; i < t.prompts.length; i++) i < l.length ? l[i] : ''];
  }

  List<Rec> toolRecs(ToolDef t) => of(t.recKind).reversed.toList();
  Rec? habitFor(ToolDef t) {
    for (final h in habits) {
      if (h.integer('feature') == t.n || h.str('name').toLowerCase() == t.habit.toLowerCase()) return h;
    }
    return null;
  }
}
