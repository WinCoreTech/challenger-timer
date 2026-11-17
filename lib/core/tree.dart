/// Nested projects (reference spec 5.4 to 5.6). Pure Dart.
library;

import 'day.dart';
import 'engine.dart';
import 'events.dart';
import 'settings.dart';

class ProjectRow {
  const ProjectRow(this.project, this.depth, this.minutes, this.lastDay);
  final Rec project;
  final int depth;

  /// Minutes on this project and everything under it.
  final int minutes;

  /// Last day with a finished session here or below, or null.
  final int? lastDay;

  /// Worked in the last 7 days (the "active" row colour).
  bool activeOn(int today) => lastDay != null && today - lastDay! < 7;
}

List<Rec> childrenOf(DayView v, String? parentId) =>
    v.projects.where((p) => p.str('parentId') == (parentId ?? '')).toList();

Set<String> descendants(DayView v, String id) {
  final out = <String>{};
  void walk(String p) {
    for (final c in childrenOf(v, p)) {
      if (out.add(c.id)) walk(c.id);
    }
  }

  walk(id);
  return out;
}

/// A project cannot become its own ancestor.
bool canSetParent(DayView v, String id, String? parentId) =>
    parentId == null || parentId.isEmpty || (parentId != id && !descendants(v, id).contains(parentId));

/// Projects as a flat, indented list: parents followed by their children.
/// [sort] is 'activity' (most recent first), 'name' or 'time'. [filter]
/// keeps a project if it or any descendant matches.
List<ProjectRow> projectRows(DayView v, {String? sort, String filter = ''}) {
  final own = <String, int>{}, last = <String, int>{};
  for (final e in v.type(Ev.sessionDone)) {
    final p = e.get<String>('projectId');
    if (p == null) continue;
    own[p] = (own[p] ?? 0) + (e.get<num>('minutes') ?? 0).toInt();
    if (e.day > (last[p] ?? -1)) last[p] = e.day;
  }
  int total(String id) => (own[id] ?? 0) + descendants(v, id).fold(0, (a, d) => a + (own[d] ?? 0));
  int? lastDay(String id) {
    final ds = [id, ...descendants(v, id)].map((x) => last[x]).whereType<int>();
    return ds.isEmpty ? null : ds.reduce((a, b) => a > b ? a : b);
  }

  final q = filter.trim().toLowerCase();
  bool matches(Rec p) =>
      q.isEmpty || p.str('name').toLowerCase().contains(q) || descendants(v, p.id).any((d) => v.rec(d)!.str('name').toLowerCase().contains(q));
  final mode = sort ?? v.pref(S.sortProjectsBy);
  int cmp(Rec a, Rec b) => switch (mode) {
        'name' => a.str('name').toLowerCase().compareTo(b.str('name').toLowerCase()),
        'time' => total(b.id).compareTo(total(a.id)),
        _ => (lastDay(b.id) ?? -1).compareTo(lastDay(a.id) ?? -1),
      };
  final out = <ProjectRow>[];
  void add(String? parent, int depth) {
    for (final p in childrenOf(v, parent)..sort(cmp)) {
      if (!matches(p)) continue;
      out.add(ProjectRow(p, depth, total(p.id), lastDay(p.id)));
      add(p.id, depth + 1);
    }
  }

  add(null, 0);
  // Orphans (parent archived or deleted) show at the top level.
  final shown = {for (final r in out) r.project.id};
  for (final p in v.projects.where((p) => !shown.contains(p.id) && v.rec(p.str('parentId')) == null && p.str('parentId').isNotEmpty)) {
    if (matches(p)) out.add(ProjectRow(p, 0, total(p.id), lastDay(p.id)));
  }
  return out;
}

String hm(int minutes) => minutes >= 60 ? '${minutes ~/ 60}h ${two(minutes % 60)}m' : '${minutes}m';
