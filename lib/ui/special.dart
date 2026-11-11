import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/engine.dart';
import '../core/extras.dart';
import 'theme.dart';

/// Feature 4: 5-4-3-2-1, then the timer starts on its own.
Future<bool> fiveSecondLaunch(BuildContext context) async =>
    await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const _Launch()) ?? false;

class _Launch extends StatefulWidget {
  const _Launch();
  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  int n = 5;
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (n <= 1) {
        t?.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => n--);
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
      backgroundColor: ink,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Big('$n', size: 200, color: cyan, key: const Key('launchCount')),
        const SizedBox(height: 24),
        const Text('No time to argue with yourself.', style: TextStyle(color: dim, fontSize: 16)),
        const SizedBox(height: 24),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
      ]));
}

/// Feature 9: the same short sequence every time: sound, one breath, tap.
class RitualScreen extends ConsumerStatefulWidget {
  const RitualScreen({super.key});
  @override
  ConsumerState<RitualScreen> createState() => _RitualState();
}

class _RitualState extends ConsumerState<RitualScreen> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  bool ready = false;
  @override
  void initState() {
    super.initState();
    ref.read(nativeProvider).tone();
    a.forward().whenComplete(() {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    return Scaffold(
        appBar: AppBar(title: const Text('START RITUAL')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Same three steps every time: the sound, one slow breath, one tap. After a few weeks the sequence itself says "work now".',
                  style: TextStyle(color: dim)),
              const Spacer(),
              Center(
                  child: AnimatedBuilder(
                      animation: a,
                      builder: (_, _) {
                        final t = a.value < 0.5 ? a.value * 2 : (1 - a.value) * 2; // in, then out
                        return Container(
                            width: 120 + 120 * t,
                            height: 120 + 120 * t,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cyan, width: 6)),
                            alignment: Alignment.center,
                            child: H(ready ? 'Ready' : a.value < 0.5 ? 'Breathe in' : 'Breathe out', color: Colors.white));
                      })),
              const Spacer(),
              FilledButton(
                  key: const Key('ritualStart'),
                  onPressed: ready
                      ? () async {
                          await app.startSession();
                          if (context.mounted) context.go('/timer');
                        }
                      : null,
                  child: Text(ready ? 'TAP TO START ${v.doorMinutes} MIN' : 'ONE BREATH FIRST')),
              SwitchListTile(
                  key: const Key('ritualToggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use this before every start from Home'),
                  subtitle: const Text('Off keeps Home at a single tap.', style: TextStyle(color: dim, fontSize: 12)),
                  value: v.kv['ritual'] == '1',
                  onChanged: (x) => app.setSetting('ritual', x ? '1' : '0')),
            ])));
  }
}

/// Feature 14: cannot choose, so the dice chooses.
class DiceTool extends ConsumerStatefulWidget {
  const DiceTool({super.key, this.random});
  final Random? random;
  @override
  ConsumerState<DiceTool> createState() => _DiceState();
}

class _DiceState extends ConsumerState<DiceTool> {
  String? pick;
  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final options = diceOptions(v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final o in options)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(border: o == pick ? cyan : null, child: Text(o, style: const TextStyle(fontSize: 16)))),
      const SizedBox(height: 12),
      OutlinedButton.icon(
          key: const Key('diceRoll'),
          onPressed: () => setState(() => pick = rollDice(options, widget.random ?? Random())),
          icon: const Icon(Icons.casino),
          label: Text(pick == null ? 'ROLL' : 'ROLL AGAIN')),
      if (pick != null) ...[
        const SizedBox(height: 12),
        FilledButton(
            key: const Key('diceStart'),
            onPressed: () async {
              await app.startSession(title: pick);
              if (context.mounted) context.go('/timer');
            },
            child: Text('START ${v.doorMinutes} MIN ON IT')),
      ],
    ]);
  }
}

/// Screens for tools of kind "special", by feature number.
Widget specialTool(int n, DayView v) => switch (n) {
      14 => const DiceTool(),
      _ => const Text('Not available.'),
    };
