import 'dart:io';

import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/core/portfolio.dart';
import 'package:challenger_timer/core/settings.dart';
import 'package:challenger_timer/core/stats.dart';
import 'package:challenger_timer/core/v2_day.dart';
import 'package:challenger_timer/ui/v2/work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'batch01_test.dart' show pumpTool;
import 'harness.dart';

void main() {
  group('A1 sound and screen settings reach the timer', () {
    test('cues obey volume, channel and mute; zero is silent', () async {
      final r = Rig();
      r.app.playCue('complete');
      expect(r.native.calls, contains('tone'));
      await r.app.setKv(S.completeVolume, '0');
      r.native.calls.clear();
      r.app.playCue('complete');
      expect(r.native.calls, isEmpty);
      r.app.playCue('tick');
      expect(r.native.calls, isEmpty, reason: 'ticking defaults to off');
      await r.app.setKv(S.tickingVolume, '30');
      await r.app.setKv(S.soundChannel, 'alarm');
      r.app.playCue('tick');
      expect(r.native.calls, ['tone:tick:30:alarm']);
      await r.app.setKv(S.muted, '1');
      r.native.calls.clear();
      r.app.playCue('tick');
      expect(r.native.calls, isEmpty);
    });
    test('keep screen on and brightness follow the settings while a session runs', () async {
      final r = Rig();
      await r.app.setKv(S.screenDuringCountdown, 'dim');
      await r.app.startSession(minutes: 25, source: 'work');
      expect(r.native.calls, containsAll(['keepOn:true', 'brightness:0.15']));
      r.clock.advance(const Duration(minutes: 25));
      await r.app.completeIfDue();
      expect(r.native.calls.last == 'tone' || r.native.calls.contains('brightness:-1.0'), isTrue);
      expect(r.native.calls, contains('keepOn:false'));
      r.native.calls.clear();
      await r.app.setKv(S.keepScreenOn, '0');
      await r.app.setKv(S.screenDuringCountdown, 'device');
      await r.app.startSession(minutes: 25, source: 'work');
      expect(r.native.calls, containsAll(['keepOn:false', 'brightness:-1.0']));
      expect(r.native.lastSync['wakeOnDone'], isTrue);
      await r.app.setSetting(S.screenOnComplete, '0');
      expect(r.native.lastSync['wakeOnDone'], isFalse);
    });
  });

  testWidgets('almost-complete cue fires once in the last 30 seconds; overtime offers N more', (t) async {
    final r = Rig();
    await r.app.setKv(S.almostSound, '1');
    await r.app.setKv(S.overtimeStep, '5');
    await r.app.startSession(minutes: 2, source: 'work');
    await pumpTool(t, r, const WorkScreen());
    r.clock.advance(const Duration(seconds: 80));
    await t.pump(const Duration(milliseconds: 300));
    expect(r.native.calls.where((c) => c.startsWith('tone:almost')), isEmpty);
    r.clock.advance(const Duration(seconds: 15));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(r.native.calls.where((c) => c.startsWith('tone:almost')).length, 1);
    r.clock.advance(const Duration(seconds: 30));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(r.v.workedToday, isTrue);
    await t.tap(find.byKey(const Key('workOvertime')));
    await t.pump(const Duration(milliseconds: 300));
    expect(r.v.active!.minutes, 5);
    await pumpTool(t, r, const SizedBox());
  });

  group('A2 deadlines and portfolio', () {
    test('on-time streak counts tasks finished by their due day, newest first', () async {
      final r = Rig();
      final p = await r.app.addRec(Kind.project, {'name': 'Lab'});
      Future<Rec> task(String n, int due) => r.app.addRec(Kind.task, {'projectId': p.id, 'title': n, 'done': false, 'due': r.v.today + due});
      final a = await task('A', 1);
      final b = await task('B', -1); // already late
      final c = await task('C', 2);
      await r.app.toggleTask(r.v.rec(a.id)!);
      r.clock.advance(const Duration(minutes: 1));
      await r.app.toggleTask(r.v.rec(b.id)!);
      r.clock.advance(const Duration(minutes: 1));
      await r.app.toggleTask(r.v.rec(c.id)!);
      expect(deadlineResults(r.v), [true, false, true]);
      expect(onTimeStreak(r.v), 1);
      expect(projectDeadlines(r.v).single, ('Lab', 1, 3));
      expect(stats['deadlines']!(r.v).first, '1');
    });
    test('portfolio PDF is a real PDF with the proof in it and no network needed', () async {
      final r = Rig();
      await r.app.setKv('name', 'Winzo');
      await r.session(minutes: 25);
      await r.app.saveProof(type: 'text', value: 'Solved the graph problem');
      final bytes = await buildPortfolioPdf(r.v);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      File('/tmp/portfolio-test.pdf').writeAsBytesSync(bytes);
    });
  });
}
