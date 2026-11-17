import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/events.dart';
import '../core/game.dart';
import '../core/pressure.dart';
import '../core/rules.dart';
import '../core/tools.dart';
import 'photo.dart';
import 'theme.dart';

/// Features 601 to 701 that need their own widget.
class PressureTool extends ConsumerStatefulWidget {
  const PressureTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<PressureTool> createState() => _PressureState();
}

class _PressureState extends ConsumerState<PressureTool> {
  int yes = 0;
  final List<Offset?> ink_ = [];
  bool rec = false;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final native = ref.read(nativeProvider);
    switch (widget.n) {
      case 701:
        final d = dialOf(v);
        final now = v.now.ms;
        const names = ['GENTLE', 'FIRM', 'RELENTLESS'];
        const about = [
          'Gentle: things you own and curiosity hooks. Nothing chases you.',
          'Firm: adds loss features, honest buttons, a 30-second skip wait, a sticky notice and the double hour.',
          'Relentless: adds auto-start at cue time and lock windows that cannot be undone the same day. Your sleep window is still never touched.',
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(key: Key('dial-$i'), label: Text(names[i]), selected: d.effective(now) == i, onSelected: (_) => app.setPressure(i)),
          ]),
          const SizedBox(height: 12),
          for (final a in about) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(a, style: const TextStyle(color: dim))),
          if (d.pending(now))
            Panel(
                border: gold,
                child: Row(children: [
                  Expanded(child: Text('Lowering to ${names[d.lowerTo!]} in ${countdown(d.lowerAt! - now)}. Until then ${names[d.level]} stays on.', key: const Key('dialPending'))),
                  TextButton(key: const Key('dialCancel'), onPressed: app.cancelPressureChange, child: const Text('KEEP IT')),
                ])),
          const Text('Turning the dial up is instant. Turning it down takes 24 hours, so it cannot be done in a weak moment. It starts on Gentle and you are the only one who can raise it.',
              style: TextStyle(color: dim, fontSize: 12)),
        ]);
      case 608:
        final st = plantState(v);
        final name = v.single(const ToolDef(n: 618, kind: 'single', title: '', prompts: ['', ''])).last;
        return Column(children: [
          SizedBox(
              height: 200,
              child: Center(
                  child: Transform.rotate(
                      angle: st * 0.5,
                      child: Icon(Icons.local_florist, key: const Key('plant'), size: 150 - st * 30.0, color: st == 0 ? accent : st == 1 ? gold : dim)))),
          Text('${name.isEmpty ? 'Your plant' : name} is ${const ['doing well', 'drooping a little', 'wilted, and waiting for you'][st]}.', style: const TextStyle(fontSize: 18)),
          const Text('It perks up the day you do a session. It cannot die.', style: TextStyle(color: dim)),
        ]);
      case 624:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Coins: ${coins(v)}. Insurance bought: ${insuranceDays(v).length}.'),
          const SizedBox(height: 8),
          FilledButton(
              key: const Key('insure'),
              onPressed: coins(v) < 20 ? null : () => app.log(Ev.tool, {'n': 624, 'coins': 20}),
              child: const Text('BUY ONE EXTRA FREEZE FOR 20 COINS')),
        ]);
      case 603:
        final live = rankTrialLive(v);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(live ? 'On trial: you are wearing the next rank. A session each day for three days keeps 100 XP toward it.' : 'Try on the next rank for three days. Do a session on each of the three days and you keep 100 XP toward it.'),
          const SizedBox(height: 8),
          FilledButton(key: const Key('trial'), onPressed: live || v.rank.next == null ? null : () => app.log(Ev.tool, {'n': 603}), child: Text(live ? 'TRIAL RUNNING' : 'START A 3-DAY TRIAL')),
        ]);
      case 632:
        const qs = ['Is the phone in your hand?', 'Can you see the next tiny step?', 'Is two minutes shorter than a song?'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (yes < 3) ...[
            Text(qs[yes], key: const Key('yesQ'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            FilledButton(key: const Key('yesBtn'), onPressed: () => setState(() => yes++), child: const Text('YES')),
          ] else
            FilledButton(
                key: const Key('yesStart'),
                onPressed: () async {
                  await app.startSession(source: 'yes');
                  if (context.mounted) context.go('/timer');
                },
                child: Text('THEN START ${v.doorMinutes} MIN')),
        ]);
      case 628:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Tomorrow: ${v.tomorrowPlan?.task ?? 'no first task set yet (Plan tab)'}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          GestureDetector(
              onPanUpdate: (d) => setState(() => ink_.add(d.localPosition)),
              onPanEnd: (_) => ink_.add(null),
              child: Container(key: const Key('signPad'), height: 160, color: panel, child: CustomPaint(painter: _Sign(ink_), size: Size.infinite))),
          Row(children: [
            TextButton(onPressed: () => setState(ink_.clear), child: const Text('CLEAR')),
            const Spacer(),
            FilledButton(
                key: const Key('signSave'),
                onPressed: ink_.length < 10
                    ? null
                    : () async {
                        await app.log(Ev.tool, {'n': 628, 'forDay': v.today + 1, 'strokes': ink_.length});
                        if (context.mounted) toast(context, 'Signed.');
                      },
                child: const Text('SIGN IT')),
          ]),
          Text('Signed plans so far: ${v.toolEvents(628).length}', style: const TextStyle(color: dim)),
        ]);
      case 629 || 630:
        final voice = widget.n == 629;
        final key = voice ? 'alarmVoice' : 'alarmImage';
        final has = (v.kv[key] ?? '').isNotEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(has ? 'Saved. It is used at your next cue alarm.' : 'Nothing saved yet.'),
          const SizedBox(height: 8),
          FilledButton.icon(
              key: Key(voice ? 'promiseRec' : 'deskSelfie'),
              onPressed: () async {
                if (!voice) {
                  final path = await ref.read(photoProvider)();
                  if (path != null) await app.setSetting(key, path);
                  return;
                }
                if (rec) {
                  await native.recStop();
                  setState(() => rec = false);
                  return;
                }
                if (!(await native.status())['mic']! && !await native.requestPermission('mic')) return;
                final path = await ref.read(voicePathProvider)();
                if (await native.recStart(path)) {
                  await app.setSetting(key, path);
                  setState(() => rec = true);
                }
              },
              icon: Icon(voice ? (rec ? Icons.stop : Icons.mic) : Icons.photo_camera),
              label: Text(voice ? (rec ? 'STOP' : 'RECORD MY PROMISE (20 S)') : 'PHOTOGRAPH ME AT MY DESK')),
          if (has) TextButton(onPressed: () => app.setSetting(key, ''), child: const Text('REMOVE')),
        ]);
      case 637:
        final sw = v.sw('sw.ulysses');
        final on = sw.effective(v.now.ms);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(on ? 'On: your blocked apps are locked from ${v.settingInt('lockFromHour', 22)}:00 to ${v.settingInt('lockToHour', 6)}:00 every day.' : 'Off.'),
          if (sw.pendingOff(v.now.ms)) Text('Switching off in ${countdown(sw.msUntilOff(v.now.ms))}.', style: const TextStyle(color: gold)),
          const SizedBox(height: 8),
          if (!on)
            FilledButton(key: const Key('ulyssesOn'), onPressed: () => app.switchOn('sw.ulysses'), child: const Text('SWITCH ON'))
          else if (sw.pendingOff(v.now.ms))
            OutlinedButton(onPressed: () => app.switchCancelOff('sw.ulysses'), child: const Text('KEEP IT ON'))
          else
            OutlinedButton(key: const Key('ulyssesOff'), onPressed: () => app.switchRequestOff('sw.ulysses'), child: const Text('SWITCH OFF (TAKES 24 HOURS)')),
        ]);
      case 641:
        final until = v.settingInt('vaultUntil', 0);
        final locked = until > v.now.ms;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(locked ? 'Vault closed until ${dayLabel(dayOf(until, v.now.offsetMin, v.dayEndHour))}. Your blocked apps stay locked all day until then.' : 'Vault open.'),
          const SizedBox(height: 8),
          for (final d in const [3, 7, 14])
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                    key: Key('vault-$d'),
                    onPressed: locked
                        ? null
                        : () async {
                            if (await confirm(context, 'Lock for $d days?', 'This cannot be shortened once set. Phone, launcher and settings always stay open. Only the apps on your blocked list are locked.', ok: 'LOCK THEM')) {
                              await app.setSetting('vaultUntil', '${v.now.ms + d * msPerDay}');
                            }
                          },
                    child: Text('LOCK MY BLOCKED APPS FOR $d DAYS'))),
        ]);
      case 688 || 689:
        final total = widget.n == 688 ? 30 : 100;
        final cols = widget.n == 688 ? 6 : 10;
        final got = piecesRevealed(v, total);
        return Column(children: [
          Text('$got of $total ${widget.n == 688 ? 'pieces' : 'squares cleared'}. One per finished session.', key: const Key('pieces')),
          const SizedBox(height: 8),
          AspectRatio(
              aspectRatio: 1,
              child: Stack(children: [
                const Positioned.fill(child: Poster(PosterArt.hourglass, size: 300)),
                GridView.count(crossAxisCount: cols, physics: const NeverScrollableScrollPhysics(), children: [
                  for (var i = 0; i < total; i++) Container(margin: const EdgeInsets.all(0.5), color: i < got ? Colors.transparent : panel),
                ]),
              ])),
        ]);
    }
    return const SizedBox();
  }
}

class _Sign extends CustomPainter {
  _Sign(this.pts);
  final List<Offset?> pts;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < pts.length; i++) {
      if (pts[i - 1] != null && pts[i] != null) canvas.drawLine(pts[i - 1]!, pts[i]!, p);
    }
  }

  @override
  bool shouldRepaint(_Sign old) => true;
}
