import 'dart:async';

import 'package:challenger_timer/core/engine.dart';
import 'package:challenger_timer/core/events.dart';
import 'package:challenger_timer/ui/settings.dart';
import 'package:challenger_timer/ui/shell.dart';
import 'package:challenger_timer/ui/timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Future<void> pumpApp(WidgetTester t, Rig r, {List<String>? shared}) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final c = ProviderContainer(parent: r.container, overrides: [
    photoProvider.overrideWithValue(() async => '/tmp/fake-proof.jpg'),
    shareProvider.overrideWithValue(({String? text, String? filePath}) async => shared?.add(text ?? filePath ?? '')),
  ]);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const ChallengerApp()));
  await t.pumpAndSettle();
}

/// Removes the app so its periodic timers stop before the test ends.
Future<void> closeApp(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump();
}

Future<Rig> onboardedRig() async {
  final r = Rig();
  await r.app.setKv(K.name, 'Winzo');
  await r.app.log(Ev.onboarded);
  return r;
}

void main() {
  testWidgets('onboarding: three answers, one permission, straight into a 2-minute session', (t) async {
    final r = Rig();
    await pumpApp(t, r);
    expect(find.text('WHAT SHOULD WE CALL YOU?'), findsOneWidget);
    await t.enterText(find.byKey(const Key('obName')), 'Winzo');
    await t.tap(find.byKey(const Key('obNext')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('obHabit')), 'Open the book');
    await t.tap(find.byKey(const Key('obNext')));
    await t.pumpAndSettle();
    expect(find.text('09:00'), findsOneWidget);
    await t.tap(find.byKey(const Key('obNext')));
    await t.pumpAndSettle();
    // One plain-language permission request, nothing else.
    expect(find.text('ONE PERMISSION'), findsOneWidget);
    await t.tap(find.text('CONTINUE'));
    await t.pump(const Duration(milliseconds: 600));
    expect(r.native.calls.where((c) => c.startsWith('request:')), ['request:notifications']);
    // Inside the first session.
    expect(find.byKey(const Key('countdown')), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(r.v.onboarded, isTrue);
    expect(r.v.name, 'Winzo');
    expect(r.v.habits.single.str('name'), 'Open the book');
    expect(r.v.active!.minutes, 2);
    await closeApp(t);
  });

  testWidgets('daily loop: dashboard, Work, start, finish, proof, back on the dashboard', (t) async {
    final r = await onboardedRig();
    await pumpApp(t, r);
    expect(find.byKey(const Key('tile-work')), findsOneWidget);
    expect(find.text('PROFESSIONAL POSTPONER'), findsOneWidget);
    await t.tap(find.byKey(const Key('tile-work')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('workStart')));
    await t.pumpAndSettle();
    await t.tap(find.text('START'));
    await t.pump(const Duration(milliseconds: 600));
    expect(r.v.active, isNotNull, reason: 'the label is prefilled, so starting is two taps');
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('WORKING'), findsOneWidget);

    r.clock.advance(const Duration(minutes: 24, seconds: 1));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('00:59'), findsOneWidget);

    r.clock.advance(const Duration(seconds: 59));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(r.v.workedToday, isTrue);
    expect(find.textContaining('Session finished'), findsOneWidget);

    await t.tap(find.byKey(const Key('workProof')));
    await t.pumpAndSettle();
    // Empty proof is refused, kindly.
    await t.ensureVisible(find.byKey(const Key('proofSave')));
    await t.tap(find.byKey(const Key('proofSave')));
    await t.pump();
    expect(find.textContaining('One line is enough'), findsOneWidget);
    await t.enterText(find.byKey(const Key('proofValue')), 'Read two pages of OS notes');
    await t.enterText(find.byKey(const Key('parkingNote')), 'Open OS notes to page 14');
    await t.ensureVisible(find.byKey(const Key('proofSave')));
    await t.tap(find.byKey(const Key('proofSave')));
    await t.pumpAndSettle();
    if (find.byKey(const Key('receiptDone')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('receiptDone')));
      await t.pumpAndSettle();
    }

    // Back on the dashboard: streak 1, parking note stored, rank moved up.
    expect(r.v.nextStep, 'Open OS notes to page 14');
    expect(find.descendant(of: find.byKey(const Key('tile-streaks')), matching: find.text('1')), findsOneWidget);
    expect(find.text(ranks[1].name.toUpperCase()), findsOneWidget);

    // The proof is in the Vault.
    await t.tap(find.byKey(const Key('tile-vault')));
    await t.pumpAndSettle();
    expect(find.text('Read two pages of OS notes'), findsOneWidget);
    await closeApp(t);
  });

  testWidgets('photo proof uses the camera path and link proof is validated', (t) async {
    final r = await onboardedRig();
    await r.session();
    await pumpApp(t, r);
    await t.tap(find.byKey(const Key('tile-work')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('workProof')));
    await t.pumpAndSettle();
    await t.tap(find.text('LINK'));
    await t.pump();
    await t.enterText(find.byKey(const Key('proofValue')), 'not a link');
    await t.tap(find.byKey(const Key('proofSave')));
    await t.pump();
    expect(find.textContaining('does not look like a link'), findsOneWidget);
    expect(r.v.proofs, isEmpty);
    await t.tap(find.text('PHOTO'));
    await t.pump();
    await t.tap(find.byKey(const Key('takePhoto')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('proofSave')));
    await t.tap(find.byKey(const Key('proofSave')));
    await t.pumpAndSettle();
    expect(r.v.proofs.single.str('type'), 'photo');
    expect(r.v.proofs.single.str('value'), '/tmp/fake-proof.jpg');
    await closeApp(t);
  });

  testWidgets('streaks tab: lives, habit tick and a new habit', (t) async {
    final r = await onboardedRig();
    final h = await r.app.addRec(Kind.habit, {'name': 'Open the book'});
    await pumpApp(t, r);
    await t.tap(find.byKey(const Key('tile-streaks')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('lives')), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
    await t.tap(find.byKey(Key('tick-${h.id}')));
    await t.pumpAndSettle();
    expect(r.v.habitStreak(h.id).current, 1);
    expect(r.v.master.current, 1);
    expect(find.byKey(Key('tick-${h.id}')), findsNothing);
    await t.tap(find.byKey(const Key('addHabit')));
    await t.pumpAndSettle();
    expect(find.text('WEEK ONE IS FOR ONE HABIT'), findsOneWidget);
    await t.tap(find.text('ADD ANYWAY'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'One commit');
    await t.tap(find.text('ADD'));
    await t.pumpAndSettle();
    expect(r.v.habits.length, 2);
    await closeApp(t);
  });

  testWidgets('plan tab: set the first task, then it shows locked after 10 pm', (t) async {
    final r = await onboardedRig();
    r.clock.setWall(2026, 11, 11, 20);
    await pumpApp(t, r);
    await t.ensureVisible(find.byKey(const Key('tile-plan')));
    await t.tap(find.byKey(const Key('tile-plan')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('planTask')), 'Open notebook to page 12');
    await t.tap(find.byKey(const Key('planSave')));
    await t.pump();
    expect(r.v.tomorrowPlan!.task, 'Open notebook to page 12');
    expect(find.byKey(const Key('planLock')), findsNothing);
    r.clock.setWall(2026, 11, 11, 22, 5);
    await t.pump(const Duration(seconds: 16)); // the app ticker notices the time
    await t.pump();
    expect(find.byKey(const Key('planLock')), findsOneWidget);
    expect(find.byKey(const Key('planTask')), findsNothing);
    expect(find.text('Open notebook to page 12'), findsOneWidget);
    await closeApp(t);
  });

  testWidgets('settings: delayed off switch shows a countdown and can be cancelled', (t) async {
    final r = await onboardedRig();
    await pumpApp(t, r);
    unawaited(r.container.read(routerProvider).push('/me'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('xpTotal')), findsOneWidget);
    await t.tap(find.byKey(const Key('openSettings')));
    await t.pumpAndSettle();
    final off = find.byKey(const Key('off-${K.swRescue}'));
    await t.scrollUntilVisible(off, 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(off);
    await t.pumpAndSettle();
    await t.tap(off);
    await t.pumpAndSettle();
    await t.tap(find.text('START 24H COUNTDOWN'));
    await t.pumpAndSettle();
    expect(r.v.isOn(K.swRescue), isTrue, reason: 'still on during the 24 hours');
    expect(find.textContaining('Off in 24h 00m'), findsOneWidget);
    await t.tap(find.byKey(const Key('cancel-${K.swRescue}')));
    await t.pumpAndSettle();
    expect(r.v.sw(K.swRescue).pendingOff(r.clock.ms), isFalse);
    expect(find.byKey(const Key('off-${K.swRescue}')), findsOneWidget);
    await closeApp(t);
  });

  testWidgets('settings: buddy report falls back to the share sheet without SMS permission', (t) async {
    final r = await onboardedRig();
    await r.app.setKv(K.buddyName, 'Asha');
    await r.app.setKv(K.buddyPhone, '+911234567890');
    final shared = <String>[];
    await pumpApp(t, r, shared: shared);
    unawaited(r.container.read(routerProvider).push('/me'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('openSettings')));
    await t.pumpAndSettle();
    final send = find.byKey(const Key('sendReport'));
    await t.scrollUntilVisible(send, 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(send);
    await t.pumpAndSettle();
    await t.tap(send);
    await t.pumpAndSettle();
    expect(r.native.sms, isEmpty);
    expect(shared.single, contains('Winzo did not start a session today'));
    await closeApp(t);
  });

  testWidgets('turning on the blocker asks for apps, then one permission at a time', (t) async {
    final r = await onboardedRig();
    await pumpApp(t, r);
    unawaited(r.container.read(routerProvider).push('/me'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('openSettings')));
    await t.pumpAndSettle();
    final on = find.byKey(const Key('on-${K.swBlock}'));
    await t.scrollUntilVisible(on, 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(on);
    await t.pumpAndSettle();
    await t.tap(on);
    await t.pumpAndSettle();
    await t.tap(find.text('Reels'));
    await t.pump();
    await t.tap(find.text('DONE'));
    await t.pumpAndSettle();
    expect(find.text('ALLOW USAGE ACCESS'), findsOneWidget);
    await t.tap(find.text('CONTINUE'));
    await t.pumpAndSettle();
    expect(find.text('ALLOW DISPLAY OVER OTHER APPS'), findsOneWidget);
    await t.tap(find.text('NOT NOW'));
    await t.pumpAndSettle();
    await t.tap(find.text('NOT NOW')); // notifications reason
    await t.pumpAndSettle();
    expect(r.native.calls, contains('settings:usage'));
    expect(r.native.calls, isNot(contains('settings:overlay')));
    expect(r.v.blockedApps, ['com.example.reels']);
    expect(r.v.isOn(K.swBlock), isTrue);
    await closeApp(t);
  });

  testWidgets('a session that ended while the app was closed opens on the DONE screen', (t) async {
    final r = await onboardedRig();
    await r.app.startSession(minutes: 15);
    r.clock.advance(const Duration(minutes: 20));
    await pumpApp(t, r);
    expect(find.text('DONE.'), findsOneWidget);
    expect(r.v.minutesToday, 15);
    await closeApp(t);
  });

  testWidgets('"Start 2 min" from the alarm lands on the running timer', (t) async {
    final r = await onboardedRig();
    r.native.launchAction = {'action': 'start2', 'source': 'cue', 'startMs': r.clock.ms};
    await pumpApp(t, r);
    expect(find.byKey(const Key('countdown')), findsOneWidget);
    expect(r.v.active!.source, 'cue');
    await closeApp(t);
  });
}
