import 'package:challenger_timer/core/settings.dart';
import 'package:challenger_timer/core/v2_day.dart';
import 'package:challenger_timer/ui/light.dart';
import 'package:challenger_timer/ui/v2/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  test('light filter reverses brightness but keeps hue, and applying it twice is the identity', () {
    List<double> apply(List<double> c) {
      final m = [
        [0.574, -1.430, -0.144, 255.0],
        [-0.426, -0.430, -0.144, 255.0],
        [-0.426, -1.430, 0.856, 255.0],
      ];
      return [for (final r in m) (r[0] * c[0] + r[1] * c[1] + r[2] * c[2] + r[3]).clamp(0, 255).toDouble()];
    }

    final navy = apply([10, 16, 32]);
    expect(navy.every((x) => x > 200), isTrue, reason: 'navy background becomes pale: $navy');
    final white = apply([255, 255, 255]);
    expect(white.every((x) => x < 5), isTrue, reason: 'white text becomes near black: $white');
    final orange = apply([255, 138, 31]);
    expect(orange[0] > orange[2], isTrue, reason: 'orange stays orange, not blue: $orange');
    // Ordinary photo colours (skin, sky, foliage, wall) come back; extreme
    // saturation is clamped in the middle and can shift, which is accepted.
    for (final c in [[190.0, 140.0, 120.0], [110.0, 150.0, 190.0], [90.0, 120.0, 70.0], [220.0, 215.0, 205.0]]) {
      final twice = apply(apply(c));
      for (var i = 0; i < 3; i++) {
        expect(twice[i], closeTo(c[i], 4), reason: 'photo colours are restored: $c -> $twice');
      }
    }
  });

  testWidgets('theme setting switches the filter; photos are unfiltered inside it', (t) async {
    final r = Rig();
    bool? seen;
    Widget probe() => Builder(builder: (c) {
          seen = LightMode.of(c);
          return const SizedBox();
        });
    await pumpTool(t, r, ThemeSwitch(setting: 'dark', child: probe()));
    expect([seen, find.byType(ColorFiltered).evaluate().length], [false, 0]);
    await pumpTool(t, r, ThemeSwitch(setting: 'light', child: probe()));
    expect([seen, find.byType(ColorFiltered).evaluate().length], [true, 1]);
    await pumpTool(t, r, ThemeSwitch(setting: 'light', child: const Unfilter(child: SizedBox())));
    expect(find.byType(ColorFiltered).evaluate().length, 2);
  });

  test('celebrations: promotion and streak milestone, once, never in casual mode', () async {
    final r = Rig(streakMin: 25);
    expect(celebrationOf(r.v), isNull);
    await r.session(minutes: 25);
    final c = celebrationOf(r.v)!;
    expect(c.title, 'RANK UP');
    expect(c.line, ranks[1].name);
    expect(celebrationUnseen(r.v), isTrue);
    await r.app.setKv('seenCelebration', c.key);
    expect(celebrationUnseen(r.v), isFalse);
    await r.app.setKv(S.casualMode, '1');
    expect(celebrationOf(r.v), isNull);
    final s = Rig(streakMin: 25);
    for (var i = 0; i < 7; i++) {
      await s.session(minutes: 25);
      await s.app.setKv('seenCelebration', 'x');
      if (i < 6) s.clock.advance(const Duration(days: 1));
    }
    expect(s.v.ladder.changes.where((x) => x.promotion && x.day == s.v.today), isEmpty);
    expect(celebrationOf(s.v)!.title, '7-DAY STREAK');
  });

  testWidgets('dashboard shows the banner and tapping it dismisses it for good', (t) async {
    final r = Rig(streakMin: 25);
    await r.session(minutes: 25);
    await pumpTool(t, r, const DashboardScreen());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('celebration')), findsOneWidget);
    expect(find.text('RANK UP'), findsOneWidget);
    await t.tap(find.byKey(const Key('celebration')));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('celebration')), findsNothing);
    expect(r.v.kv['seenCelebration'], startsWith('rank:'));
  });
}
