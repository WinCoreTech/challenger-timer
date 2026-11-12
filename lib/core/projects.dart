/// Projects and task breakdown (features 151 to 175). Pure Dart.
library;

import 'deadlines.dart';
import 'engine.dart';
import 'events.dart';
import 'rules.dart';

List<Rec> openTasks(DayView v, String projectId) => v.tasksOf(projectId).where((t) => !t.flag('done')).toList();

/// 173: a task is blocked while the task it depends on is not done.
bool blocked(DayView v, Rec task) {
  final dep = v.rec(task.str('after'));
  return dep != null && !dep.flag('done');
}

/// 155: the first open, unblocked task, frog first (162).
Rec? nextAction(DayView v, String projectId) {
  final open = openTasks(v, projectId).where((t) => !blocked(v, t)).toList();
  if (open.isEmpty) return null;
  return open.firstWhere((t) => t.flag('frog'), orElse: () => open.first);
}

/// 170: progress that starts at 10 percent.
double headStart(DayView v, String projectId) {
  final all = v.tasksOf(projectId);
  if (all.isEmpty) return 0.1;
  return 0.1 + 0.9 * all.where((t) => t.flag('done')).length / all.length;
}

/// 171: sessions left across the project's open tasks, from their estimates.
int projectSessionsLeft(DayView v, String projectId) =>
    openTasks(v, projectId).fold(0, (a, t) => a + TaskMath(v, t).sessionsLeft);

/// 167: open tasks whose title does not start with an action verb.
bool vague(Rec task) => !task.flag('done') && !startsWithVerb(task.str('title'));

/// 157: your own ratio of actual to estimated minutes over finished tasks.
double estimateRatio(DayView v) {
  var est = 0, actual = 0;
  for (final t in v.of(Kind.task)) {
    if (!t.flag('done') || t.integer('est') == 0) continue;
    final a = taskMinutes(v, t.id);
    if (a == 0) continue;
    est += t.integer('est');
    actual += a;
  }
  return est == 0 ? 1 : actual / est;
}

int correctedEstimate(DayView v, int guess) => (guess * estimateRatio(v)).round();

/// 172: tasks with time logged that are not finished.
List<Rec> openLoops(DayView v) =>
    [for (final t in v.of(Kind.task)) if (!t.flag('done') && taskMinutes(v, t.id) > 0) t];

/// 163: at most three active projects.
const wipLimit = 3;
bool wipFull(DayView v) => v.on(163) && v.projects.length >= wipLimit;

/// 159: quadrant 0 do now, 1 schedule, 2 quick or delegate, 3 drop.
int quadrant(Rec t) => (t.flag('urgent') ? 0 : 1) + (t.flag('important') ? 0 : 2);

/// 154 local fallback: split pasted text into steps by lines, bullets, numbers and sentences.
List<String> splitAssignment(String text) => text
    .split(RegExp(r'\n|(?<=[.;?!])\s+'))
    .map((s) => s.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*'), '').trim())
    .where((s) => s.length > 2)
    .toList();

/// 168: project templates.
const templates = <String, List<String>>{
  'Lab record': ['Open the lab manual to the experiment', 'Write the aim and apparatus', 'Draw the circuit or diagram', 'Copy the readings table', 'Write the result and get it signed'],
  'Assignment': ['Read the questions once', 'Write the answer to the easiest question', 'Draft the remaining answers badly', 'Fix the worst answer', 'Submit it'],
  'Exam prep': ['List the units', 'Read unit 1 notes', 'Solve one past paper question', 'Write a one-page formula sheet', 'Do a timed past paper'],
  'Hackathon': ['Write the idea in one sentence', 'Sketch the screens on paper', 'Build the one core feature', 'Record a 60-second demo', 'Write the README'],
};

/// 166: bonus XP for finishing dreaded tasks (dread 4 or 5).
List<(String, int)> projectXp(DayView v) {
  if (!v.flagOn(166)) return const [];
  final n = v.of(Kind.task).where((t) => t.flag('done') && t.integer('dread') >= 4).length;
  return n == 0 ? const [] : [('Dreaded tasks done', n * 30)];
}
