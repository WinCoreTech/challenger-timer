import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/settings.dart';
import 'package:challenger_timer/core/v2_dash.dart';
import 'package:challenger_timer/core/v2_schedule.dart';
import 'package:challenger_timer/ui/share.dart';
import 'package:challenger_timer/ui/v2/about_screen.dart';
import 'package:challenger_timer/ui/v2/achievements_screen.dart';
import 'package:challenger_timer/ui/v2/backup_screen.dart';
import 'package:challenger_timer/ui/v2/dashboard.dart';
import 'package:challenger_timer/ui/v2/project_edit.dart';
import 'package:challenger_timer/ui/v2/projects_screen.dart';
import 'package:challenger_timer/ui/v2/ranks_screen.dart';
import 'package:challenger_timer/ui/v2/schedule_screen.dart';
import 'package:challenger_timer/ui/v2/settings_v2.dart';
import 'package:challenger_timer/ui/v2/stats_screen.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

final files = <String, String>{};
final shared = <String>[];

Future<void> pump(WidgetTester t, Rig r, Widget w, {Size size = const Size(1080, 2340), double dpr = 2.5, double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = dpr;
  addTearDown(t.view.reset);
  final c = ProviderContainer(parent: r.container, overrides: [
    backupFileProvider.overrideWithValue((name, contents) async {
      files[name] = contents;
      return '/tmp/$name';
    }),
    shareProvider.overrideWithValue(({String? text, String? filePath}) async => shared.add(filePath ?? text ?? '')),
  ]);
  await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: MediaQuery(
          key: UniqueKey(),data: MediaQueryData(size: size / dpr, textScaler: TextScaler.linear(scale)), child: w))));
  await t.pump();
}

/// Lets provider changes made outside the widget tree reach the screen.
Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    files.clear();
    shared.clear();
  });

  testWidgets('dashboard: counts, backup warning, mute, rank bar, slogan', (t) async {
    final r = Rig();
    await r.app.addRec(Kind.project, {'name': 'DSA'});
    await pump(t, r, const DashboardScreen());
    for (final id in ['work', 'projects', 'achievements', 'stats', 'schedule', 'settings', 'backup', 'about', 'streaks', 'vault', 'plan']) {
      expect(find.byKey(Key('tile-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('backupWarning')), findsOneWidget);
    expect(find.text('0/${achievements.length}'), findsOneWidget);
    expect(find.text(ranks.first.name.toUpperCase()), findsOneWidget);
    expect(find.text(workSlogan(r.v)), findsOneWidget);
    await t.tap(find.byKey(const Key('muteToggle')));
    await settle(t);
    expect(r.v.prefOn(S.muted), isTrue);
    await r.app.markExported();
    await r.session(minutes: 25);
    await settle(t);
    expect(find.byKey(const Key('backupWarning')), findsNothing);
    expect(find.text(ranks[1].name.toUpperCase()), findsOneWidget);
    expect(find.textContaining('minutes from the next rank'), findsOneWidget);
  });

  testWidgets('ranks: far ranks unknown, current highlighted with score', (t) async {
    final r = Rig();
    await r.session(minutes: 25);
    await pump(t, r, const RanksScreen());
    await t.scrollUntilVisible(find.byKey(const Key('rank-1')), 300);
    expect(find.textContaining('Score 25. 20 more minutes today to advance.'), findsOneWidget);
    expect(find.text(ranks[2].name.toUpperCase()), findsOneWidget, reason: 'the next rank is shown');
    expect(find.text(ranks[3].name.toUpperCase()), findsNothing, reason: 'beyond the next is hidden');
    expect(ranksHelpText, contains('rest days'));
  });

  testWidgets('achievements: unknown until earned, earned rows expand to a date', (t) async {
    final r = Rig();
    await pump(t, r, const AchievementsScreen());
    expect(find.text('Unknown achievement'), findsWidgets);
    expect(find.text('The Door Opens'), findsNothing);
    await r.session();
    r.clock.advance(const Duration(days: 3));
    await settle(t);
    await t.tap(find.text('The Door Opens'));
    await t.pumpAndSettle();
    expect(find.text('Achieved on 2026/11/11'), findsOneWidget, reason: 'the day it was earned, not today');
    final a = achievements.firstWhere((x) => x.id == 'first_start');
    expect(earnedDay(r.v, a), r.v.today - 3);
    expect(earnedDay(r.v, achievements.firstWhere((x) => x.id == 'streak_30')), isNull);
  });

  testWidgets('projects: nesting, totals, filter, sort, delete re-parents', (t) async {
    final r = Rig();
    final a = await r.app.addRec(Kind.project, {'name': 'Sem 5'});
    final b = await r.app.addRec(Kind.project, {'name': 'DBMS', 'parentId': a.id});
    final c = await r.app.addRec(Kind.project, {'name': 'ER diagram', 'parentId': b.id});
    await r.app.startSession(minutes: 30, projectId: b.id);
    r.clock.advance(const Duration(minutes: 30));
    await r.app.completeIfDue();
    await pump(t, r, const ProjectsScreen());
    expect(find.text('30m'), findsNWidgets(2), reason: 'parent total includes the child');
    await t.enterText(find.byKey(const Key('projFilter')), 'zzz');
    await settle(t);
    expect(find.byKey(const Key('projEmpty')), findsOneWidget);
    await t.enterText(find.byKey(const Key('projFilter')), '');
    await settle(t);
    await t.tap(find.byKey(const Key('projSort')));
    await t.pumpAndSettle();
    await t.tap(find.text('Name'));
    await t.pumpAndSettle();
    expect(r.v.pref(S.sortProjectsBy), 'name');
    await t.tap(find.descendant(of: find.byKey(Key('proj-${b.id}')), matching: find.byType(PopupMenuButton<String>)));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await t.tap(find.text('DELETE'));
    await t.pumpAndSettle();
    expect(r.v.rec(b.id), isNull);
    expect(r.v.rec(c.id)!.str('parentId'), a.id);
  });

  testWidgets('edit project: overrides are saved and cycles are impossible', (t) async {
    final r = Rig();
    final a = await r.app.addRec(Kind.project, {'name': 'Thesis'});
    final b = await r.app.addRec(Kind.project, {'name': 'Chapter 1', 'parentId': a.id});
    await pump(t, r, ProjectEditScreen(a.id));
    await t.tap(find.byKey(const Key('peParent')));
    await t.pumpAndSettle();
    expect(find.text('Chapter 1'), findsNothing, reason: 'a child cannot become the parent');
    await t.tap(find.text('No parent').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('peWork')));
    await t.pumpAndSettle();
    await t.tap(find.text('50 min').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('peName')), 'Thesis v2');
    await t.tap(find.byKey(const Key('peSave')));
    await settle(t);
    expect(r.v.rec(a.id)!.str('name'), 'Thesis v2');
    expect(r.v.workMinutes(b.id), 50);
    await pump(t, r, const ProjectEditScreen('new'));
    await t.tap(find.byKey(const Key('peSave')));
    await settle(t);
    expect(find.text('A project needs a name.'), findsOneWidget);
  });

  testWidgets('project picker returns none or an id', (t) async {
    final r = Rig();
    final a = await r.app.addRec(Kind.project, {'name': 'DSA'});
    await r.session(minutes: 25);
    await r.app.saveProof(type: 'text', value: 'x');
    await pump(t, r, const WorkScreen());
    await t.tap(find.byKey(const Key('workProject')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('pick-${a.id}')));
    await t.pumpAndSettle();
    expect(r.v.kv[K.lastProject], a.id);
    await t.tap(find.byKey(const Key('workProject')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pick-none')));
    await t.pumpAndSettle();
    expect(r.v.kv[K.lastProject], isNull);
    await pump(t, r, const SizedBox());
  });

  testWidgets('stats: empty message, consistency first, stepping back', (t) async {
    final r = Rig();
    await pump(t, r, const StatsScreen());
    expect(find.byKey(const Key('statsEmpty')), findsOneWidget);
    expect(find.byKey(const Key('statsConsistency')), findsNothing);
    await r.session(minutes: 25);
    await settle(t);
    expect(find.text('14%'), findsOneWidget, reason: '1 of the last 7 days');
    await t.tap(find.byKey(const Key('statsRange')));
    await t.pumpAndSettle();
    await t.tap(find.text('Day by day').last);
    await t.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    await t.tap(find.byKey(const Key('statsBack')));
    await settle(t);
    expect(find.byKey(const Key('statsEmpty')), findsOneWidget);
    expect(find.text('10 Nov 2026'), findsOneWidget);
  });

  testWidgets('settings: defaults shown, changes written, privacy reset', (t) async {
    final r = Rig();
    await r.app.setKv('perm.usage', '1');
    await pump(t, r, const SettingsV2Screen());
    expect(find.text('25 min'), findsOneWidget);
    await t.tap(find.byKey(const Key('set-${S.workMin}')));
    await t.pumpAndSettle();
    await t.tap(find.text('50 min').last);
    await t.pumpAndSettle();
    expect(r.v.workMinutes(), 50);
    final casual = find.byKey(const Key('set-${S.casualMode}'));
    await t.scrollUntilVisible(casual, 300, scrollable: find.byType(Scrollable).first);
    await t.tap(casual);
    await settle(t);
    expect(r.v.prefOn(S.casualMode), isTrue);
    final reset = find.byKey(const Key('set-resetPrivacy'));
    await t.scrollUntilVisible(reset, 300, scrollable: find.byType(Scrollable).first);
    await t.tap(reset);
    await t.pumpAndSettle();
    await t.tap(find.text('RESET'));
    await t.pumpAndSettle();
    expect(r.v.kv.containsKey('perm.usage'), isFalse);
  });

  testWidgets('backup: make, redacted, load by paste, refuse garbage', (t) async {
    final r = Rig();
    await r.app.addRec(Kind.project, {'name': 'Secret project'});
    await r.session(minutes: 25);
    await pump(t, r, const BackupScreen());
    expect(find.text('Last backup: never'), findsOneWidget);
    await t.tap(find.byKey(const Key('bkMake')));
    await settle(t);
    expect(shared.single, '/tmp/productivity-go-backup.json');
    expect(r.v.kv[S.lastBackup], isNotNull);
    await t.tap(find.byKey(const Key('bkRedacted')));
    await settle(t);
    expect(files['productivity-go-redacted.json'], isNot(contains('Secret project')));
    final good = files['productivity-go-backup.json']!;
    await r.app.addRec(Kind.project, {'name': 'Added later'});
    await t.enterText(find.byKey(const Key('bkPaste')), 'not a backup');
    await t.tap(find.byKey(const Key('bkLoad')));
    await settle(t);
    expect(find.textContaining('not valid JSON'), findsOneWidget);
    expect(r.v.projects.length, 2, reason: 'nothing changed');
    await t.enterText(find.byKey(const Key('bkPaste')), good);
    await t.tap(find.byKey(const Key('bkLoad')));
    await t.pumpAndSettle();
    await t.tap(find.text('REPLACE'));
    await t.pumpAndSettle();
    expect(r.v.projects.single.str('name'), 'Secret project');
    expect(r.v.minutesToday, 25);
  });

  testWidgets('schedule: create a block and get a reminder for its weekday', (t) async {
    final r = Rig();
    await pump(t, r, const ScheduleScreen());
    expect(find.byKey(const Key('schedCreate')), findsOneWidget);
    await r.app.addRec(blockKind, {'wd': 3, 'minute': 9 * 60, 'len': 25, 'projectId': '', 'remind': true});
    await r.app.addRec(blockKind, {'wd': 3, 'minute': 7 * 60, 'len': 50, 'projectId': '', 'remind': false});
    await settle(t);
    expect(blocksOn(r.v, 3).map((b) => b.integer('minute')), [420, 540]);
    final rem = scheduleReminders(r.v).single;
    expect([rem.minute, rem.days, rem.start], [540, '0010000', true]);
    expect(find.textContaining('09:00'), findsWidgets);
  });

  testWidgets('about lists every permission', (t) async {
    await pump(t, Rig(), const AboutScreen());
    expect(find.text('Version $appVersion'), findsOneWidget);
    expect(permissions.length, 12);
  });

  testWidgets('every v2 screen renders on a tablet in landscape and at 2x text', (t) async {
    final r = Rig();
    final p = await r.app.addRec(Kind.project, {'name': 'A fairly long project name for wrapping'});
    await r.session(minutes: 25);
    final screens = <Widget>[
      const DashboardScreen(), const WorkScreen(), const RanksScreen(), const AchievementsScreen(), const ProjectsScreen(),
      ProjectEditScreen(p.id), const StatsScreen(), const SettingsV2Screen(), const BackupScreen(), const AboutScreen(), const ScheduleScreen(),
    ];
    for (final s in screens) {
      await pump(t, r, s, size: const Size(2560, 1600), dpr: 2);
      expect(t.takeException(), isNull, reason: 'tablet ${s.runtimeType}');
      await pump(t, r, s, scale: 2);
      expect(t.takeException(), isNull, reason: '2x text ${s.runtimeType}');
    }
    await pump(t, r, const SizedBox());
  });
}
