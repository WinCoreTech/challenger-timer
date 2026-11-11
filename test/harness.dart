import 'dart:io';

import 'package:challenger_timer/app/native.dart';
import 'package:challenger_timer/app/state.dart';
import 'package:challenger_timer/core/day.dart';
import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/rules.dart';
import 'package:challenger_timer/data/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A clock the test moves by hand. Starts at 10:00 local (UTC+5:30).
class TestClock {
  TestClock([DateTime? utcWall]) {
    final w = utcWall ?? DateTime.utc(2026, 11, 11, 10);
    ms = w.millisecondsSinceEpoch - offsetMin * msPerMinute;
  }
  late int ms;
  int offsetMin = 330;
  Moment call() => Moment(ms, offsetMin);
  void advance(Duration d) => ms += d.inMilliseconds;

  /// Jumps to the given local wall time (must not go backwards in tests).
  void setWall(int y, int mo, int d, int h, [int mi = 0]) =>
      ms = DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch - offsetMin * msPerMinute;
}

final ranks = parseRanks(File('assets/ranks.json').readAsStringSync());
final achievements = parseAchievements(File('assets/achievements.json').readAsStringSync());

class Rig {
  Rig({MemoryStore? store, TestClock? clock})
      : store = store ?? MemoryStore(),
        clock = clock ?? TestClock() {
    container = ProviderContainer(overrides: [
      storeProvider.overrideWithValue(this.store),
      nativeProvider.overrideWithValue(native),
      clockProvider.overrideWithValue(this.clock.call),
      ranksProvider.overrideWithValue(ranks),
      achievementsProvider.overrideWithValue(achievements),
    ]);
  }
  final MemoryStore store;
  final TestClock clock;
  final FakeNative native = FakeNative();
  late final ProviderContainer container;
  App get app => container.read(appProvider.notifier);
  DayView get v => app.view;

  /// Runs one whole session of [minutes] and leaves proof pending.
  Future<void> session({int minutes = 2}) async {
    await app.startSession(minutes: minutes);
    clock.advance(Duration(minutes: minutes));
    await app.completeIfDue();
  }
}
