import '../core/social.dart';

/// An in-memory "server" shared by several fake clients, so two people can be
/// simulated in one test. It enforces the same rules the Firestore security
/// rules do, which is what the tests check.
class FakeServer {
  final profiles = <String, Profile>{};
  final byCode = <String, String>{};
  final days = <String, Map<int, DayRow>>{};
  final links = <String, Map<String, LinkState>>{}; // owner -> other -> state (as the owner sees it)
  final nudges = <String, Set<int>>{}; // "from>to" -> days
  final duels = <String, Duel>{};
  int _seq = 0;
  String nextId() => 'd${_seq++}';

  FakeSocial client(String uid, {bool online = true}) => FakeSocial(this, uid);
}

class FakeSocial implements SocialBackend {
  FakeSocial(this.server, this.uid);
  final FakeServer server;
  final String uid;
  bool _in = false;

  @override
  bool get live => false;

  void _need() {
    if (!_in) throw const SocialError('Sign in first.');
  }

  LinkState? _link(String a, String b) => server.links[a]?[b];
  bool _friends(String a, String b) => _link(a, b) == LinkState.accepted && _link(b, a) == LinkState.accepted;

  @override
  Future<Profile> signIn(String displayName) async {
    final p = server.profiles[uid] ?? Profile(uid, displayName, inviteCodeFor(uid));
    server.profiles[uid] = p;
    server.byCode[p.inviteCode] = uid;
    _in = true;
    return p;
  }

  @override
  Future<void> signOut() async => _in = false;

  @override
  Future<void> deleteAccount() async {
    _need();
    final p = server.profiles.remove(uid);
    if (p != null) server.byCode.remove(p.inviteCode);
    server.days.remove(uid);
    server.links.remove(uid);
    for (final m in server.links.values) {
      m.remove(uid);
    }
    server.nudges.removeWhere((k, _) => k.startsWith('$uid>') || k.endsWith('>$uid'));
    server.duels.removeWhere((_, d) => d.from == uid || d.to == uid);
    _in = false;
  }

  @override
  Future<void> publishDay(DayRow row) async {
    _need();
    if (row.uid != uid) throw const SocialError('You can only publish your own days.');
    (server.days[uid] ??= {})[row.day] = row;
  }

  @override
  Future<List<Friend>> friends() async {
    _need();
    return [
      for (final e in (server.links[uid] ?? const <String, LinkState>{}).entries)
        if (e.value != LinkState.blocked && server.profiles[e.key] != null)
          Friend(e.key, server.profiles[e.key]!.name, e.value == LinkState.accepted && _link(e.key, uid) != LinkState.accepted ? LinkState.pending : e.value,
              rank: (server.days[e.key]?.values.fold<int>(0, (a, r) => r.rank > a ? r.rank : a)) ?? 0)
    ];
  }

  @override
  Future<void> requestFriend(String code) async {
    _need();
    final other = server.byCode[code.trim().toUpperCase()];
    if (other == null) throw const SocialError('No one has that code. Check it and try again.');
    if (other == uid) throw const SocialError('That is your own code.');
    if (_link(other, uid) == LinkState.blocked) throw const SocialError('No one has that code. Check it and try again.');
    (server.links[uid] ??= {})[other] = LinkState.accepted;
    // The other side stays pending until they accept.
    (server.links[other] ??= {}).putIfAbsent(uid, () => LinkState.pending);
  }

  @override
  Future<void> respond(String other, {required bool accept}) async {
    _need();
    if (_link(uid, other) != LinkState.pending) throw const SocialError('There is no request from that person.');
    if (accept) {
      server.links[uid]![other] = LinkState.accepted;
    } else {
      server.links[uid]!.remove(other);
      server.links[other]?.remove(uid);
    }
  }

  @override
  Future<void> setLink(String other, LinkState state) async {
    _need();
    (server.links[uid] ??= {})[other] = state;
  }

  @override
  Future<void> unfriend(String other) async {
    _need();
    server.links[uid]?.remove(other);
    server.links[other]?.remove(uid);
  }

  @override
  Future<List<DayRow>> daysOf(String other, int fromDay, int toDay) async {
    _need();
    // Reads are allowed only between accepted friends, and never from a muted or blocked side.
    if (other != uid && !(_friends(uid, other))) throw const SocialError('Not allowed: you are not friends.');
    return [for (final r in (server.days[other] ?? const <int, DayRow>{}).values) if (r.day >= fromDay && r.day <= toDay) r];
  }

  @override
  Future<void> nudge(String other, int today) async {
    _need();
    final key = '$uid>$other';
    final sent = server.nudges[key] ?? <int>{};
    if (!canNudge(sentDays: sent.toList(), today: today, link: _friends(uid, other) ? LinkState.accepted : LinkState.pending)) {
      throw SocialError(_friends(uid, other) ? 'One nudge per friend per day. Tomorrow is fine.' : 'You can only nudge friends.');
    }
    if (_link(other, uid) == LinkState.muted) {
      // Muted: accepted silently, delivered to no one.
    }
    (server.nudges[key] ??= {}).add(today);
  }

  @override
  Future<List<Duel>> duels() async {
    _need();
    return [for (final d in server.duels.values) if (d.from == uid || d.to == uid) d];
  }

  @override
  Future<Duel> challenge(String other, int day) async {
    _need();
    if (!_friends(uid, other)) throw const SocialError('You can only challenge friends.');
    if (server.duels.values.any((d) => (d.from == uid || d.to == uid) && (d.from == other || d.to == other) && d.day == day && d.state != DuelState.declined)) {
      throw const SocialError('There is already a duel with that friend for that day.');
    }
    final d = Duel(server.nextId(), uid, other, day, DuelState.invited);
    server.duels[d.id] = d;
    return d;
  }

  @override
  Future<void> answerDuel(String id, {required bool accept}) async {
    _need();
    final d = server.duels[id];
    if (d == null || d.to != uid || d.state != DuelState.invited) throw const SocialError('That duel is not waiting for you.');
    server.duels[id] = d.withState(accept ? DuelState.active : DuelState.declined);
  }

  @override
  Future<void> settleDuels(int today) async {
    _need();
    for (final d in server.duels.values.toList()) {
      if (!duelSettled(d, today) || (d.from != uid && d.to != uid)) continue;
      final a = server.days[d.from]?[d.day]?.minutes ?? 0;
      final b = server.days[d.to]?[d.day]?.minutes ?? 0;
      server.duels[d.id] = d.finish(a, b);
    }
  }
}
