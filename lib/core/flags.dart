/// Feature flags. The single config file is assets/features.json (built by
/// tools/gen_features.py): one entry per feature, each with its own "on" flag.
/// A user can override any flag in Settings; overrides live in kv "flag.N".
library;

import 'dart:convert';

class Feature {
  const Feature(this.n, this.name, this.desc, this.sec, this.status, this.rank, this.v1, this.on);
  final int n;
  final String name, desc, sec, status;

  /// Rank index at which this feature appears (feature 492).
  final int rank;

  /// Part of Version 1: always available, even in Simple mode.
  final bool v1;
  final bool on;
  bool get built => status != 'todo';
}

class Catalog {
  Catalog(this.all) : _by = {for (final f in all) f.n: f};
  factory Catalog.parse(String json) => Catalog([
        for (final j in jsonDecode(json) as List)
          Feature(j['n'] as int, j['name'] as String, j['desc'] as String, j['sec'] as String,
              j['status'] as String, j['rank'] as int? ?? 0, j['v1'] == true, j['on'] != false)
      ]);
  static final empty = Catalog(const []);
  final List<Feature> all;
  final Map<int, Feature> _by;
  Feature? operator [](int n) => _by[n];
  List<String> get sections => {for (final f in all) f.sec}.toList();
}

/// Pressure dial (feature 701) levels, in rising order.
enum Pressure { gentle, firm, relentless }

/// Decides whether feature [n] is live right now.
bool featureLive(
  Catalog catalog,
  int n, {
  required Map<String, String> kv,
  required int rankIndex,
  required bool simpleMode,
}) {
  final f = catalog[n];
  if (f == null) return false;
  if (f.v1) return true;
  if (simpleMode || !f.built) return false;
  final o = kv['flag.$n'];
  if (o != null) return o == '1';
  if (!f.on) return false;
  return rankIndex >= f.rank || kv['unlockAll'] == '1';
}
