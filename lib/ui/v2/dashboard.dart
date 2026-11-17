import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/settings.dart';
import '../../core/v2_dash.dart';
import '../../core/v2_day.dart';
import '../theme.dart';

/// Reference 5.1: a dashboard of tiles with the rank bar along the bottom.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final ach = ref.watch(achievementsProvider);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720 || size.width > size.height;
    final muted = v.prefOn(S.muted);

    Widget tile(String id, String title, IconData icon, String route, {String? value, bool warn = false}) => Semantics(
        button: true,
        label: '$title${value == null ? '' : ', $value'}${warn ? ', needs attention' : ''}',
        child: Material(
            color: panel,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                key: Key('tile-$id'),
                onTap: () => context.push(route),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 84),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(icon, color: cyan, size: 28),
                          const SizedBox(width: 10),
                          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: H(title, color: Colors.white, size: 14))),
                          if (value != null) const SizedBox(width: 10),
                          if (value != null)
                            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300)))),
                          if (warn) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.warning_amber, key: Key('backupWarning'), color: gold)),
                        ]))))));

    final work = Material(
        color: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: cyan, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            key: const Key('tile-work'),
            onTap: () => context.push('/work'),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Expanded(child: H('Work', color: Colors.white, size: 26)),
                    IconButton(
                        key: const Key('muteToggle'),
                        tooltip: muted ? 'Sound is off' : 'Sound is on',
                        onPressed: () => app.setSetting(S.muted, muted ? '0' : '1'),
                        icon: Icon(muted ? Icons.volume_off : Icons.volume_up, color: dim)),
                  ]),
                  SizedBox(height: wide ? 180 : 110, child: const Center(child: Poster(PosterArt.hourglass, size: 110))),
                  Text(workSlogan(v), key: const Key('slogan'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                  if (goal(v) case final g?) ...[
                    const SizedBox(height: 12),
                    Text('${g.text}: ${g.hours.toStringAsFixed(1)} of ${g.target} h', key: const Key('goalCard'), style: const TextStyle(color: dim)),
                    const SizedBox(height: 4),
                    Bar(g.progress, height: 6),
                  ],
                ]))));

    final tiles = [
      tile('projects', 'Projects', Icons.folder_open, '/projects', value: '${v.projects.length}'),
      tile('achievements', 'Achievements', Icons.military_tech, '/achievements', value: '${ach.where((a) => a.earned(v.metrics)).length}/${ach.length}'),
      tile('stats', 'Stats', Icons.bar_chart, '/stats'),
      tile('schedule', 'Schedule', Icons.event_note, '/schedule'),
      tile('streaks', 'Streaks', Icons.local_fire_department, '/streaks', value: '${v.master.current}'),
      tile('vault', 'Vault', Icons.inventory_2, '/vault', value: '${v.proofs.length}'),
      tile('plan', 'Plan', Icons.checklist, '/plan'),
      tile('shutdown', 'Shutdown', Icons.nightlight_round, '/shutdown', value: shutdownDone(v) ? 'done' : '${dailyScore(v, v.today)}'),
      tile('settings', 'Settings', Icons.settings, '/prefs'),
      tile('backup', 'Backup', Icons.save_alt, '/backup', warn: v.kv[S.lastBackup] == null),
      tile('about', 'About', Icons.info_outline, '/about'),
    ];
    Widget grid(int cols) => LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
        });

    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 4, child: SingleChildScrollView(child: work)),
                        const SizedBox(width: 12),
                        Expanded(flex: 6, child: SingleChildScrollView(child: grid(MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 1 : 2))),
                      ])
                    : ListView(children: [work, const SizedBox(height: 10), grid(size.width < 380 || MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 1 : 2)]))),
        bottomNavigationBar: SafeArea(
            child: InkWell(
                key: const Key('rankBar'),
                onTap: () => context.push('/ranks'),
                child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))),
                    child: Row(children: [
                      const H('Your rank', size: 11),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(v.ladderRank.name.toUpperCase(),
                              key: const Key('rankName'), overflow: TextOverflow.ellipsis, style: const TextStyle(color: cyan, fontWeight: FontWeight.w800, letterSpacing: 1))),
                      const Icon(Icons.chevron_right, color: dim),
                    ])))));
  }
}
