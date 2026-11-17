import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/ui/v2/about_screen.dart';
import 'package:challenger_timer/ui/v2/achievements_screen.dart';
import 'package:challenger_timer/ui/v2/backup_screen.dart';
import 'package:challenger_timer/ui/v2/dashboard.dart';
import 'package:challenger_timer/ui/v2/projects_screen.dart';
import 'package:challenger_timer/ui/v2/ranks_screen.dart';
import 'package:challenger_timer/ui/v2/schedule_screen.dart';
import 'package:challenger_timer/ui/v2/settings_v2.dart';
import 'package:challenger_timer/ui/v2/shutdown_screen.dart';
import 'package:challenger_timer/ui/v2/stats_screen.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

/// Accessibility guards (plan v2 section 6.10): every tappable control must be
/// at least 48 dp and every icon-only button must have a name a screen reader can say.
void main() {
  testWidgets('every v2 screen: touch targets are 48 dp and icon buttons are named', (t) async {
    final r = Rig(streakMin: 25);
    await r.session(minutes: 25);
    await r.app.addRec(Kind.project, {'name': 'DSA'});
    final handle = t.ensureSemantics();
    final screens = <Widget>[
      const DashboardScreen(), const WorkScreen(), const RanksScreen(), const AchievementsScreen(), const ProjectsScreen(),
      const StatsScreen(), const SettingsV2Screen(), const BackupScreen(), const AboutScreen(), const ScheduleScreen(), const ShutdownScreen(),
    ];
    for (final s in screens) {
      await pumpTool(t, r, s);
      await t.pump(const Duration(milliseconds: 600));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline), reason: '${s.runtimeType} tap targets');
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline), reason: '${s.runtimeType} labels');
    }
    handle.dispose();
    await pumpTool(t, r, const SizedBox());
  });
}
