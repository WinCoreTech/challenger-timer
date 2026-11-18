/// Friends, shared streaks, duels, nudges and weekly boards (plan v2 6.9).
///
/// Privacy (rule R7): only [DayRow] summaries ever leave the phone. They hold
/// a day number, qualifying minutes, session count, streak length and rank.
/// No names of projects, no notes, no photos. Everything here is off until the
/// user switches social on. Pure Dart; the network sits behind [SocialBackend].
library;

import 'engine.dart';
import 'events.dart';

/// What one person shares per day.
class DayRow {
  const DayRow(this.uid, this.day, this.minutes, this.sessions, this.streak, this.rank);
  factory DayRow.fromJson(Map<String, Object?> j) =>
      DayRow(j['uid'] as String, j['day'] as int, j['minutes'] as int, j['sessions'] as int, j['streak'] as int, j['rank'] as int);
  final String uid;
  final int day, minutes, sessions, streak, rank;
  Map<String, Object?> toJson() => {'uid': uid, 'day': day, 'minutes': minutes, 'sessions': sessions, 'streak': streak, 'rank': rank};
}

/// The summary of [day] for sharing. Nothing else about the day is included.
DayRow dayRowOf(DayView v, String uid, int day) {
  final done = v.type(Ev.sessionDone).where((e) => e.day == day);
  return DayRow(uid, day, done.fold(0, (a, e) => a + (e.get<num>('minutes') ?? 0).toInt()), done.length, v.master.current, v.ladder.index);
}

enum LinkState { pending, accepted, muted, blocked }

class Friend {
  const Friend(this.uid, this.name, this.state, {this.rank = 0});
  final String uid, name;
  final LinkState state;
  final int rank;
}

class Profile {
  const Profile(this.uid, this.name, this.inviteCode);
  final String uid, name, inviteCode;
}

/// Invite codes: 8 characters, no look-alikes (0/O, 1/I), derived from the uid
/// so the same person always has the same code.
String inviteCodeFor(String uid) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  var h = 7;
  for (final c in uid.codeUnits) {
    h = (h * 131 + c) & 0x7fffffff;
  }
  final b = StringBuffer();
  var x = h;
  for (var i = 0; i < 8; i++) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    b.write(alphabet[(x >> 8) % alphabet.length]);
  }
  return b.toString();
}

bool validInviteCode(String s) => RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(s.trim().toUpperCase());

/// Shared streak: both people had a qualifying day, on each of these days in a row,
/// counted back from [today]. A day counts when its row has minutes >= [minMinutes].
int sharedStreak(List<DayRow> mine, List<DayRow> theirs, int today, {int minMinutes = 25}) {
  final a = {for (final r in mine) if (r.minutes >= minMinutes) r.day};
  final b = {for (final r in theirs) if (r.minutes >= minMinutes) r.day};
  var d = a.contains(today) && b.contains(today) ? today : today - 1;
  var n = 0;
  while (a.contains(d) && b.contains(d)) {
    n++;
    d--;
  }
  return n;
}

// ---- nudges -------------------------------------------------------------------
/// One nudge per friend per day. A nudge is a short fixed line, never free text.
const nudgeLines = [
  'Your friend is thinking of you. Two minutes?',
  'A small nudge from a friend: the timer is free right now.',
  'Someone you know started today. Your turn when ready.',
];

bool canNudge({required List<int> sentDays, required int today, required LinkState link}) => link == LinkState.accepted && !sentDays.contains(today);

// ---- duels ----------------------------------------------------------------------
enum DuelState { invited, active, finished, declined }

class Duel {
  const Duel(this.id, this.from, this.to, this.day, this.state, {this.fromMinutes, this.toMinutes});
  final String id, from, to;
  final int day;
  final DuelState state;
  final int? fromMinutes, toMinutes;

  /// The winner's uid, or null for a draw or a duel that is not finished.
  String? get winner {
    if (state != DuelState.finished || fromMinutes == null || toMinutes == null || fromMinutes == toMinutes) return null;
    return fromMinutes! > toMinutes! ? from : to;
  }

  Duel finish(int a, int b) => Duel(id, from, to, day, DuelState.finished, fromMinutes: a, toMinutes: b);
  Duel withState(DuelState s) => Duel(id, from, to, day, s, fromMinutes: fromMinutes, toMinutes: toMinutes);
}

/// A duel lasts one logical day and can only be settled after that day is over.
bool duelSettled(Duel d, int today) => d.state == DuelState.active && today > d.day;

// ---- weekly boards ----------------------------------------------------------------
class BoardRow {
  const BoardRow(this.uid, this.name, this.minutes, this.days, this.position, this.move);
  final String uid, name;
  final int minutes, days, position;

  /// +1 promoted, -1 demoted, 0 stays, for the next week.
  final int move;
}

/// Ranks friends by days shown up first (consistency), then minutes. Top third
/// moves up a tier, bottom third moves down. Boards of fewer than 3 never move.
List<BoardRow> weeklyBoard(Map<String, String> names, Map<String, List<DayRow>> rows, int weekFrom, int weekTo, {int minMinutes = 25}) {
  final stats = <String, (int minutes, int days)>{};
  for (final e in names.entries) {
    final mine = (rows[e.key] ?? const []).where((r) => r.day >= weekFrom && r.day <= weekTo);
    stats[e.key] = (mine.fold(0, (a, r) => a + r.minutes), mine.where((r) => r.minutes >= minMinutes).length);
  }
  final order = names.keys.toList()
    ..sort((a, b) {
      final x = stats[a]!, y = stats[b]!;
      return y.$2 != x.$2 ? y.$2.compareTo(x.$2) : y.$1 != x.$1 ? y.$1.compareTo(x.$1) : a.compareTo(b);
    });
  final n = order.length;
  final third = n ~/ 3;
  return [
    for (final (i, uid) in order.indexed)
      BoardRow(uid, names[uid]!, stats[uid]!.$1, stats[uid]!.$2, i + 1, n < 3 ? 0 : i < third ? 1 : i >= n - third ? -1 : 0)
  ];
}

// ---- the backend boundary -----------------------------------------------------------
class SocialUnavailable implements Exception {
  const SocialUnavailable();
  @override
  String toString() => 'Friends need a connection that is not set up yet. Nothing is shared.';
}

class SocialError implements Exception {
  const SocialError(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class SocialBackend {
  /// True when a real server is behind this. The fake used in tests says false.
  bool get live;
  Future<Profile> signIn(String displayName);
  Future<void> signOut();

  /// Account deletion: removes the profile, day rows, links, nudges and duels.
  Future<void> deleteAccount();
  Future<void> publishDay(DayRow row);
  Future<List<Friend>> friends();

  /// Redeem someone's code: creates a pending link that they must accept.
  Future<void> requestFriend(String code);
  Future<void> respond(String uid, {required bool accept});
  Future<void> setLink(String uid, LinkState state);
  Future<void> unfriend(String uid);
  Future<List<DayRow>> daysOf(String uid, int fromDay, int toDay);
  Future<void> nudge(String uid, int today);
  Future<List<Duel>> duels();
  Future<Duel> challenge(String uid, int day);
  Future<void> answerDuel(String id, {required bool accept});
  Future<void> settleDuels(int today);
}

/// What the app uses until a Firebase project is connected: it refuses
/// everything with a plain message and never invents a friend or a number.
class UnavailableSocial implements SocialBackend {
  const UnavailableSocial();
  @override
  bool get live => false;
  Never _no() => throw const SocialUnavailable();
  @override
  Future<Profile> signIn(String displayName) async => _no();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}
  @override
  Future<void> publishDay(DayRow row) async => _no();
  @override
  Future<List<Friend>> friends() async => const [];
  @override
  Future<void> requestFriend(String code) async => _no();
  @override
  Future<void> respond(String uid, {required bool accept}) async => _no();
  @override
  Future<void> setLink(String uid, LinkState state) async => _no();
  @override
  Future<void> unfriend(String uid) async => _no();
  @override
  Future<List<DayRow>> daysOf(String uid, int fromDay, int toDay) async => const [];
  @override
  Future<void> nudge(String uid, int today) async => _no();
  @override
  Future<List<Duel>> duels() async => const [];
  @override
  Future<Duel> challenge(String uid, int day) async => _no();
  @override
  Future<void> answerDuel(String id, {required bool accept}) async => _no();
  @override
  Future<void> settleDuels(int today) async {}
}
