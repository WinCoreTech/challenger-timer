import 'package:challenger_timer/app/state.dart';
import 'package:challenger_timer/core/social.dart';
import 'package:challenger_timer/data/fake_social.dart';
import 'package:challenger_timer/ui/v2/dashboard.dart';
import 'package:challenger_timer/ui/v2/friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Future<void> pumpWith(WidgetTester t, Rig r, Widget w, SocialBackend net) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final c = ProviderContainer(parent: r.container, overrides: [socialProvider.overrideWithValue(net)]);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: w)));
  await t.pump();
}

void main() {
  testWidgets('social is off by default: no Friends tile until it is switched on', (t) async {
    final r = Rig(streakMin: 25);
    await pumpWith(t, r, const DashboardScreen(), const UnavailableSocial());
    expect(find.byKey(const Key('tile-friends')), findsNothing);
    await r.app.setSetting('social', '1');
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('tile-friends')), findsOneWidget);
  });

  testWidgets('with no server it says so, shows nobody and shares nothing', (t) async {
    final r = Rig(streakMin: 25);
    await pumpWith(t, r, const FriendsScreen(), const UnavailableSocial());
    expect(find.textContaining('not set up yet'), findsOneWidget);
    await t.tap(find.byKey(const Key('friendsSignIn')));
    await t.pump();
    expect(find.textContaining('Nothing is shared'), findsOneWidget);
    expect(find.byKey(const Key('myCode')), findsNothing);
  });

  testWidgets('with the fake server: sign in, add a friend, accept, nudge, duel and board', (t) async {
    final server = FakeServer();
    final ben = server.client('uid-ben');
    await ben.signIn('Ben');
    await ben.publishDay(const DayRow('uid-ben', 20400, 30, 1, 2, 0));
    final r = Rig(streakMin: 25);
    await r.session(minutes: 25);
    final me = server.client('uid-me');
    await pumpWith(t, r, const FriendsScreen(), me);
    await t.tap(find.byKey(const Key('friendsSignIn')));
    await t.pumpAndSettle();
    expect(find.text('Your invite code: ${inviteCodeFor('uid-me')}'), findsOneWidget);
    await t.enterText(find.byKey(const Key('friendCode')), 'bad');
    await t.tap(find.byKey(const Key('friendAdd')));
    await t.pump();
    expect(find.textContaining('8 letters and numbers'), findsOneWidget);
    await t.enterText(find.byKey(const Key('friendCode')), inviteCodeFor('uid-ben'));
    await t.tap(find.byKey(const Key('friendAdd')));
    await t.pumpAndSettle();
    expect(find.text('Waiting for an answer'), findsOneWidget, reason: 'the friend still has to accept');
    await ben.respond('uid-me', accept: true);
    await t.tap(find.byKey(const Key('friendsRefresh')));
    await t.pumpAndSettle();
    expect(find.text('Friends'), findsWidgets);
    final menu = find.descendant(of: find.byKey(const Key('friend-uid-ben')), matching: find.byType(PopupMenuButton<String>));
    await t.tap(menu);
    await t.pumpAndSettle();
    await t.tap(find.text('Nudge (once a day)'));
    await t.pumpAndSettle();
    await t.tap(menu);
    await t.pumpAndSettle();
    await t.tap(find.text('Nudge (once a day)'));
    await t.pumpAndSettle();
    expect(find.textContaining('One nudge per friend per day'), findsOneWidget);
    await t.tap(menu);
    await t.pumpAndSettle();
    await t.tap(find.text('Challenge to a one-day duel'));
    await t.pumpAndSettle();
    expect(find.text('invited'), findsOneWidget);
    expect(await ben.duels(), hasLength(1));
    // Delete the account: needs the typed word, then removes the shared data.
    await t.ensureVisible(find.byKey(const Key('friendsDelete')));
    await t.tap(find.byKey(const Key('friendsDelete')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'DELETE');
    await t.tap(find.text('DELETE').last);
    await t.pumpAndSettle();
    expect(server.profiles.containsKey('uid-me'), isFalse);
    expect(server.days.containsKey('uid-me'), isFalse);
    expect(r.v.kv['social'], '0');
    expect(find.byKey(const Key('friendsSignIn')), findsOneWidget);
  });
}
