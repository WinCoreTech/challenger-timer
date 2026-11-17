import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/v2_day.dart';
import '../theme.dart';

/// A short pop-in banner for a promotion or streak milestone. Tap to dismiss;
/// it also never comes back once seen. Honours the system "remove animations" setting.
class CelebrationBanner extends ConsumerWidget {
  const CelebrationBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final c = celebrationOf(v);
    if (c == null || v.kv['seenCelebration'] == c.key) return const SizedBox.shrink();
    final still = MediaQuery.disableAnimationsOf(context);
    final card = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
            liveRegion: true,
            label: '${c.title}. ${c.line}. Tap to dismiss.',
            child: Panel(
                key: const Key('celebration'),
                border: gold,
                onTap: () => ref.read(appProvider.notifier).setKv('seenCelebration', c.key),
                child: Row(children: [
                  const Poster(PosterArt.flame, size: 48, color: gold),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    H(c.title, color: gold, size: 16),
                    const SizedBox(height: 4),
                    Text(c.line, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ])),
                  const Icon(Icons.close, color: dim),
                ]))));
    return still
        ? card
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (_, t, child) => Transform.scale(scale: t, alignment: Alignment.topCenter, child: Opacity(opacity: t.clamp(0.0, 1.0), child: child)),
            child: card);
  }
}
