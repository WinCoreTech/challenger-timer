import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/social.dart';
import '../theme.dart';

/// Friends, nudges, duels and the weekly board (plan v2 6.9). Reachable only
/// when "Friends and sharing" is switched on. With no server connected it says
/// so and shows nothing.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsState();
}

class _FriendsState extends ConsumerState<FriendsScreen> {
  Profile? me;
  List<Friend> friends = const [];
  List<Duel> duels = const [];
  List<BoardRow> board = const [];
  String? message;
  final code = TextEditingController();

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  SocialBackend get net => ref.read(socialProvider);

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
      message = null;
    } on SocialUnavailable catch (e) {
      message = '$e';
    } on SocialError catch (e) {
      message = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final v = ref.read(viewProvider);
    friends = await net.friends();
    duels = await net.duels();
    await net.settleDuels(v.today);
    final names = {me!.uid: me!.name, for (final f in friends) if (f.state == LinkState.accepted || f.state == LinkState.muted) f.uid: f.name};
    final rows = <String, List<DayRow>>{};
    final from = v.today - ((v.today + 3) % 7), to = from + 6;
    for (final uid in names.keys) {
      rows[uid] = await net.daysOf(uid, from, to);
    }
    board = weeklyBoard(names, rows, from, to);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    return Scaffold(
        appBar: AppBar(title: const Text('FRIENDS'), actions: [
          if (me != null) IconButton(key: const Key('friendsRefresh'), tooltip: 'Refresh', onPressed: () => _run(_refresh), icon: const Icon(Icons.refresh)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(net.live ? 'Connected.' : 'Friends run on a connection that is not set up yet, so nothing is shared and nobody is listed.',
              key: const Key('friendsStatus'), style: const TextStyle(color: dim)),
          if (message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message!, key: const Key('friendsMessage'), style: const TextStyle(color: gold))),
          const SizedBox(height: 12),
          if (me == null)
            FilledButton(
                key: const Key('friendsSignIn'),
                onPressed: () => _run(() async {
                      me = await net.signIn(v.name.isEmpty ? 'Me' : v.name);
                      await net.publishDay(dayRowOf(v, me!.uid, v.today));
                      await _refresh();
                    }),
                child: const Text('SIGN IN WITH GOOGLE'))
          else ...[
            Panel(
                border: accent,
                child: Row(children: [
                  Expanded(child: Text('Your invite code: ${me!.inviteCode}', key: const Key('myCode'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                ])),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(key: const Key('friendCode'), controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Friend\'s code'))),
              const SizedBox(width: 8),
              FilledButton(
                  key: const Key('friendAdd'),
                  onPressed: () => _run(() async {
                        if (!validInviteCode(code.text)) throw const SocialError('A code is 8 letters and numbers.');
                        await net.requestFriend(code.text);
                        code.clear();
                        await _refresh();
                      }),
                  child: const Text('ADD')),
            ]),
            const SizedBox(height: 16),
            const H('Friends'),
            if (friends.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No friends yet. Share your code, or enter theirs.', style: TextStyle(color: dim))),
            for (final f in friends)
              ListTile(
                  key: Key('friend-${f.uid}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.name),
                  subtitle: Text(switch (f.state) { LinkState.pending => 'Waiting for an answer', LinkState.muted => 'Muted', _ => 'Friends' }, style: const TextStyle(color: dim)),
                  trailing: PopupMenuButton<String>(
                      tooltip: 'Actions for ${f.name}',
                      onSelected: (a) => _run(() async {
                            switch (a) {
                              case 'accept':
                                await net.respond(f.uid, accept: true);
                              case 'decline':
                                await net.respond(f.uid, accept: false);
                              case 'nudge':
                                await net.nudge(f.uid, v.today);
                              case 'duel':
                                await net.challenge(f.uid, v.today);
                              case 'mute':
                                await net.setLink(f.uid, LinkState.muted);
                              case 'block':
                                await net.setLink(f.uid, LinkState.blocked);
                              case 'unfriend':
                                await net.unfriend(f.uid);
                            }
                            await _refresh();
                          }),
                      itemBuilder: (_) => [
                            if (f.state == LinkState.pending) ...const [PopupMenuItem(value: 'accept', child: Text('Accept')), PopupMenuItem(value: 'decline', child: Text('Decline'))]
                            else ...const [
                              PopupMenuItem(value: 'nudge', child: Text('Nudge (once a day)')),
                              PopupMenuItem(value: 'duel', child: Text('Challenge to a one-day duel')),
                              PopupMenuItem(value: 'mute', child: Text('Mute')),
                              PopupMenuItem(value: 'unfriend', child: Text('Remove friend')),
                            ],
                            const PopupMenuItem(value: 'block', child: Text('Block')),
                          ])),
            if (duels.isNotEmpty) ...[
              const SizedBox(height: 12),
              const H('Duels'),
              for (final d in duels)
                ListTile(
                    key: Key('duel-${d.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.state == DuelState.finished ? (d.winner == null ? 'Draw' : d.winner == me!.uid ? 'You won' : 'They won') : d.state.name),
                    subtitle: d.state == DuelState.finished ? Text('${d.fromMinutes} against ${d.toMinutes} minutes', style: const TextStyle(color: dim)) : null,
                    trailing: d.state == DuelState.invited && d.to == me!.uid
                        ? TextButton(onPressed: () => _run(() async {
                              await net.answerDuel(d.id, accept: true);
                              await _refresh();
                            }), child: const Text('ACCEPT'))
                        : null),
            ],
            if (board.length > 1) ...[
              const SizedBox(height: 12),
              const H('This week'),
              for (final r in board)
                ListTile(
                    key: Key('board-${r.uid}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Text('${r.position}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    title: Text(r.name),
                    subtitle: Text('${r.days} days · ${r.minutes} min', style: const TextStyle(color: dim)),
                    trailing: Text(r.move > 0 ? 'moves up' : r.move < 0 ? 'moves down' : '', style: const TextStyle(color: accent))),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
                key: const Key('friendsDelete'),
                style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold, width: 2)),
                onPressed: () async {
                  final t = await askText(context, 'Delete your account?', hint: 'Type DELETE', ok: 'DELETE');
                  if (t?.trim().toUpperCase() != 'DELETE') return;
                  await _run(() async {
                    await net.deleteAccount();
                    me = null;
                    friends = const [];
                    duels = const [];
                    board = const [];
                  });
                  await app.setSetting('social', '0');
                },
                child: const Text('DELETE MY ACCOUNT AND SHARED DATA')),
          ],
        ]));
  }
}
