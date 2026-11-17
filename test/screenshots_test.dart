// Renders every main screen to docs/screens/*.png with real fonts.
// Run: SHOTS=1 flutter test test/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/ui/light.dart';
import 'package:challenger_timer/ui/theme.dart';
import 'package:challenger_timer/ui/v2/achievements_screen.dart';
import 'package:challenger_timer/ui/v2/dashboard.dart';
import 'package:challenger_timer/ui/v2/projects_screen.dart';
import 'package:challenger_timer/ui/v2/ranks_screen.dart';
import 'package:challenger_timer/ui/v2/settings_v2.dart';
import 'package:challenger_timer/ui/v2/shutdown_screen.dart';
import 'package:challenger_timer/ui/v2/stats_screen.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

final shots = Platform.environment['SHOTS'] == '1';

Future<void> loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/fl/flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String n) async => ByteData.view(File('$dir/$n').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final n in ['Roboto-Regular.ttf', 'Roboto-Light.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf', 'Roboto-Thin.ttf']) {
    if (File('$dir/$n').existsSync()) roboto.addFont(f(n));
  }
  await roboto.load();
  // Styles with no explicit family fall back to the test font, so register
  // Roboto under that name too.
  for (final fam in ['FlutterTest', 'Ahem']) {
    final l = FontLoader(fam);
    for (final n in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf', 'Roboto-Thin.ttf', 'Roboto-Light.ttf']) {
      l.addFont(f(n));
    }
    await l.load();
  }
  final icons = FontLoader('MaterialIcons')..addFont(f('MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  testWidgets('screenshots', (t) async {
    if (!shots) return;
    await loadFonts();
    final key = GlobalKey();
    var light = false;
    Future<void> shot(Rig r, String name, Widget w, {Size size = const Size(1080, 2340), double dpr = 2.5}) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = dpr;
      await t.pumpWidget(UncontrolledProviderScope(
          container: r.container,
          child: RepaintBoundary(
              key: key,
              child: MaterialApp(debugShowCheckedModeBanner: false, theme: appTheme(font: 'Roboto'),
                  home: ThemeSwitch(setting: light ? 'light' : 'dark', child: KeyedSubtree(key: UniqueKey(), child: w))))));
      await t.pump(const Duration(milliseconds: 400));
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: dpr);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('docs/screens/$name${light ? '-light' : ''}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // A believable two weeks of use.
    final r = Rig(streakMin: 25, clock: TestClock(DateTime.utc(2026, 11, 3, 9)));
    await r.app.setKv('name', 'Winzo');
    await r.app.log(Ev.onboarded);
    final sem = await r.app.addRec(Kind.project, {'name': 'Semester 5'});
    final dbms = await r.app.addRec(Kind.project, {'name': 'DBMS mini project', 'parentId': sem.id});
    final dsa = await r.app.addRec(Kind.project, {'name': 'DSA practice', 'workMin': 50});
    await r.app.addRec(Kind.project, {'name': 'Hackathon idea'});
    for (var d = 0; d < 14; d++) {
      if (d == 5 || d == 9) {
        r.clock.advance(const Duration(days: 1));
        continue;
      }
      for (final (p, m) in [(dbms.id, 25), (dsa.id, 50), if (d.isEven) (dbms.id, 25)]) {
        await r.app.startSession(minutes: m, projectId: p, source: 'work', title: 'Work', meta: {'mode': 'normal'});
        r.clock.advance(Duration(minutes: m));
        await r.app.completeIfDue();
        await r.app.saveProof(type: 'text', value: 'Did the thing');
        r.clock.advance(const Duration(minutes: 20));
      }
      r.clock.setWall(2026, 11, 4 + d, 9);
    }
    await r.app.setKv(K.lastProject, dbms.id);
    await shot(r, '01-dashboard', const DashboardScreen());
    await shot(r, '02-work', const WorkScreen());
    await shot(r, '04-ranks', const RanksScreen());
    await shot(r, '05-projects', const ProjectsScreen());
    await shot(r, '06-stats', const StatsScreen());
    await shot(r, '07-achievements', const AchievementsScreen());
    await shot(r, '08-settings', const SettingsV2Screen());
    await r.app.setKv('goalText', 'Placement prep');
    await r.app.setKv('goalHours', '300');
    await shot(r, '10-shutdown', const ShutdownScreen());
    await shot(r, '01-dashboard', const DashboardScreen());
    await shot(r, '09-dashboard-tablet', const DashboardScreen(), size: const Size(2560, 1600), dpr: 2);
    await r.app.startSession(minutes: 25, projectId: dbms.id, source: 'work', title: 'Draw the ER diagram', meta: {'mode': 'normal'});
    r.clock.advance(const Duration(seconds: 2));
    await shot(r, '03-working', const WorkScreen());
    light = true;
    for (final (n, w) in [('01-dashboard', const DashboardScreen()), ('02-work', const WorkScreen()), ('05-projects', const ProjectsScreen()), ('06-stats', const StatsScreen()), ('08-settings', const SettingsV2Screen())]) {
      await shot(r, n, w);
    }
    await t.pumpWidget(const SizedBox());
    t.view.reset();
  });
}
