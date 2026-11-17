import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/day.dart';
import '../../core/engine.dart';
import '../../core/events.dart';
import '../../core/extras.dart';
import '../../core/focus.dart';
import '../../core/settings.dart';
import '../../core/tree.dart';
import '../theme.dart';
import 'projects_screen.dart';

/// Status line by state. Our own words: strict coach, dry, never shaming.
String workStatus(DayView v) {
  if (v.pendingProof != null) return 'Session finished. Log what you did, then go again or stop for real.';
  final last = v.events.reversed.where((e) => e.day == v.today && (e.type == Ev.sessionAbandon || e.type == Ev.sessionDone)).firstOrNull;
  if (last?.type == Ev.sessionAbandon) return 'Session canceled. Nothing logged, nothing lost. The button still works.';
  if (v.workedToday) return 'Work is on the board today. Another round is optional and it counts.';
  return 'Nothing started yet today. One press and the clock does the rest.';
}

/// Average per day over the last 7 days: minutes, or sessions when [count].
double weekAverage(DayView v, {required bool count}) {
  var n = 0;
  for (final e in v.type(Ev.sessionDone)) {
    if (e.day > v.today - 7 && e.day <= v.today) n += count ? 1 : (e.get<num>('minutes') ?? 0).toInt();
  }
  return n / 7;
}

/// Reference 5.2 and 5.3: one screen, idle or working.
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});
  @override
  ConsumerState<WorkScreen> createState() => _WorkState();
}

class _WorkState extends ConsumerState<WorkScreen> with SingleTickerProviderStateMixin {
  Timer? _t;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (!mounted || ref.read(viewProvider).active == null) return;
      await ref.read(appProvider.notifier).completeIfDue();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// 6.1: a task label is required. The last one is offered so it is one tap.
  Future<void> _start(DayView v, App app) async {
    final pid = v.kv[K.lastProject];
    final mode = modeOf(v.pref(S.focusMode));
    final label = await askText(context, mode.id == 'beast' ? 'Goal for this session' : 'What is this session for?',
        initial: mode.id == 'beast' ? '' : v.kv['lastLabel'] ?? v.nextStep, hint: 'One line', ok: 'START');
    if (label == null) return;
    if (label.trim().isEmpty) {
      if (mounted) toast(context, 'One line is enough. It keeps the session honest.');
      return;
    }
    await app.setKv('lastLabel', label.trim());
    await app.startSession(minutes: v.workMinutes(pid), projectId: pid, source: 'work', title: label.trim(), meta: {'mode': mode.id});
  }

  String? _driftSid;

  Future<void> _lateDialog(DayView v, App app) async {
    final late = v.type(Ev.lateFinish).last.get<int>('ms') ?? 0;
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: panel,
                title: const H('A countdown finished late', color: Colors.white, size: 16),
                content: Text('The last session ended ${(late / 1000).round()} seconds after it should have. '
                    'That is usually the phone saving battery by putting this app to sleep.\n\n'
                    '1. Open the battery page for this app.\n2. Choose "Unrestricted" or "Don\'t optimise".\n'
                    '3. If your phone has an Autostart switch, allow it too.'),
                actions: [
                  TextButton(
                      key: const Key('lateHide'),
                      onPressed: () {
                        app.setSetting(S.hideLateWarning, '1');
                        Navigator.pop(ctx);
                      },
                      child: const Text('HIDE THIS WARNING')),
                  FilledButton(
                      key: const Key('lateFix'),
                      onPressed: () {
                        app.native.openSettings('battery');
                        Navigator.pop(ctx);
                      },
                      child: const Text('SHOW ME HOW')),
                ]));
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final s = v.active;
    final muted = v.prefOn(S.muted);
    final running = s != null;
    if (running && v.prefOn(S.stayAway) && !s.isBreak) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
        appBar: AppBar(
            title: Text(!running ? 'WORK' : s.isBreak ? 'BREAK' : s.paused ? 'PAUSED' : 'WORKING', key: const Key('workTitle')),
            actions: [
              if (!running && v.lateWarning)
                IconButton(key: const Key('lateWarning'), tooltip: 'A countdown finished late', onPressed: () => _lateDialog(v, app), icon: const Icon(Icons.warning_amber, color: gold)),
              if (!running && v.prefOn(S.enableNotes))
                IconButton(
                    key: const Key('workNotes'),
                    tooltip: 'Notes',
                    onPressed: () async {
                      final n = await askText(context, 'Notes', initial: v.kv['workNote'] ?? '', hint: 'Anything worth remembering');
                      if (n != null) await app.setKv('workNote', n.trim());
                    },
                    icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  key: const Key('workMute'),
                  tooltip: muted ? 'Sound is off' : 'Sound is on',
                  onPressed: () => app.setSetting(S.muted, muted ? '0' : '1'),
                  icon: Icon(muted ? Icons.volume_off : Icons.volume_up)),
            ],
            bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: cyan))),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: running
                    ? _running(v, s, app)
                    : wide
                        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: _left(v, app)),
                            const SizedBox(width: 24),
                            Expanded(child: SingleChildScrollView(child: _rows(v, app))),
                          ])
                        : ListView(children: [_left(v, app), const SizedBox(height: 20), _rows(v, app)]))));
  }

  Widget _left(DayView v, App app) {
    final need = v.ladder.minutesToAdvance;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(workStatus(v), key: const Key('workStatus'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300, height: 1.3)),
      const SizedBox(height: 24),
      if (v.pendingProof != null) ...[
        FilledButton(key: const Key('workProof'), onPressed: () => context.push('/proof'), child: const Text('LOG WHAT I DID')),
        const SizedBox(height: 12),
      ],
      OutlinedButton(
          key: const Key('workStart'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 88)),
          onPressed: () => _start(v, app),
          child: Text('START\nWORK SESSION', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, letterSpacing: 2))),
      const SizedBox(height: 8),
      Center(child: Text('${v.workMinutes(v.kv[K.lastProject])} minutes', style: const TextStyle(color: dim))),
      if (lastFocusScore(v) != null && v.pendingProof != null)
        Center(child: Text('Focus score for that one: ${lastFocusScore(v)} of 100', key: const Key('focusScore'), style: const TextStyle(color: cyan))),
      const SizedBox(height: 16),
      const H('Focus mode'),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in focusModes.values)
          ChoiceChip(key: Key('mode-${m.id}'), label: Text(m.name.toUpperCase()), selected: v.pref(S.focusMode) == m.id, onSelected: (_) => app.setSetting(S.focusMode, m.id)),
      ]),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(modeOf(v.pref(S.focusMode)).about, style: const TextStyle(color: dim, fontSize: 12))),
      if (need != null && !v.prefOn(S.casualMode)) ...[
        const SizedBox(height: 20),
        Panel(
            key: const Key('rankBanner'),
            child: Text(need == 0 ? 'Rank line reached. The next finished minute promotes you.' : '$need more ${need == 1 ? 'minute' : 'minutes'} today to advance in rank.',
                style: const TextStyle(color: cyan, fontWeight: FontWeight.w700))),
      ],
    ]);
  }

  Widget _rows(DayView v, App app) {
    final count = v.prefOn(S.showCount);
    final avg = weekAverage(v, count: count);
    Widget row(String label, String value, {VoidCallback? onTap, Key? key, IconData? icon}) => InkWell(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    H(label, size: 11),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300)),
                  ])),
                  if (icon != null) Icon(icon, color: dim),
                ]))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row('Current project', v.rec(v.kv[K.lastProject])?.str('name') ?? 'No project',
          key: const Key('workProject'),
          icon: Icons.arrow_drop_down,
          onTap: () async {
            final id = await pickProject(context, ref);
            if (id != null) await app.setKv(K.lastProject, id.isEmpty ? null : id);
          }),
      const Divider(height: 1),
      row(count ? 'Work sessions completed today' : 'Time worked today', count ? '${v.sessionsToday}' : hm(v.minutesToday),
          key: const Key('workToday'), icon: Icons.swap_horiz, onTap: () => app.setSetting(S.showCount, count ? '0' : '1')),
      const Divider(height: 1),
      row('Daily average (last 7 days)', count ? '${avg.toStringAsFixed(1)} sessions' : hm(avg.round()), key: const Key('workAverage')),
      const Divider(height: 1),
      row('Your rank', v.ladderRank.name, key: const Key('workRank'), icon: Icons.chevron_right, onTap: () => context.push('/ranks')),
    ]);
  }

  Widget _running(DayView v, ActiveSession s, App app) {
    final now = ref.read(clockProvider)().ms;
    final left = s.remainingMs(now);
    final sec = (left / 1000).ceil();
    final loop = v.prefOn(S.loop);
    final clock = Text('${two(sec ~/ 60)}:${two(sec % 60)}',
        key: const Key('workCountdown'),
        style: TextStyle(
            fontSize: 140, fontWeight: FontWeight.w200, height: 1, color: s.isBreak ? cyan : Colors.white, fontFeatures: const [FontFeature.tabularFigures()]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.isBreak ? 'Rest. Stand up, look far away, come back.' : s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: dim, fontSize: 16)),
      const Spacer(),
      Center(
          child: FittedBox(
              child: v.prefOn(S.stayAway) && !s.isBreak
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Opacity(opacity: 0.45 + 0.55 * _pulse.value, child: child),
                      child: DefaultTextStyle.merge(style: const TextStyle(color: Color(0xFFFF5252)), child: clock))
                  : clock)),
      const SizedBox(height: 12),
      Center(
          child: IconButton(
              key: const Key('workLoop'),
              iconSize: 36,
              tooltip: loop ? 'Continuous mode is on: work, break, work' : 'Continuous mode is off',
              onPressed: () => app.setSetting(S.loop, loop ? '0' : '1'),
              icon: Icon(Icons.loop, color: loop ? cyan : dim))),
      Center(child: Text(loop ? 'Continuous: the break and the next session start by themselves.' : 'Single session.', style: const TextStyle(color: dim, fontSize: 12))),
      if (!s.isBreak) ...[
        const SizedBox(height: 8),
        if (_driftSid == s.sid)
          Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
            for (final c in driftCauses)
              ActionChip(
                  key: Key('cause-$c'),
                  label: Text(c),
                  onPressed: () {
                    app.log(Ev.tool, {'n': driftCauseTool, 'sid': s.sid, 'cause': c});
                    setState(() => _driftSid = null);
                  }),
          ])
        else
          Center(
              child: TextButton(
                  key: const Key('workDrift'),
                  onPressed: () {
                    app.log(Ev.tool, {'n': 92, 'sid': s.sid});
                    setState(() => _driftSid = s.sid);
                  },
                  child: Text('LOST FOCUS · ${wanderCount(v, sid: s.sid)}'))),
        Wrap(alignment: WrapAlignment.center, children: [
          if (s.paused)
            FilledButton(key: const Key('workResume'), onPressed: app.resumeSession, child: const Text('RESUME'))
          else ...[
            if (s.pauses < (s.meta['mode'] == null ? 2 : modeOf(s.meta['mode'] as String?).pauses))
              TextButton(
                  key: const Key('workPause'),
                  onPressed: () async {
                    final why = await askText(context, 'Pause for what?', hint: 'Door, water, a question', ok: 'PAUSE');
                    if (why != null && why.trim().isNotEmpty) await app.pauseSession(why.trim());
                  },
                  child: const Text('PAUSE')),
            if (!emergencyUsedToday(v))
              TextButton(key: const Key('workEmergency'), onPressed: app.emergencyPause, child: const Text('EMERGENCY PAUSE')),
          ],
        ]),
      ],
      const Spacer(),
      Center(
          child: IconButton(
              key: const Key('workCancel'),
              iconSize: 48,
              tooltip: s.isBreak ? 'End the break' : 'Cancel this session',
              onPressed: () async {
                if (s.isBreak) return app.stopSession();
                if (await confirm(context, 'Cancel this session?', 'A canceled session logs no time. The clock is still running if you would rather keep going.',
                    ok: 'CANCEL IT', cancel: 'KEEP GOING')) {
                  await app.stopSession(reason: 'cancel');
                }
              },
              icon: const Icon(Icons.close, color: Color(0xFFFF5252)))),
    ]);
  }
}
