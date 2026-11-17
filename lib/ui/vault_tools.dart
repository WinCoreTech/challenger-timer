import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app/state.dart';
import '../core/day.dart';
import '../core/deadlines.dart';
import '../core/events.dart';
import '../core/extras.dart';
import '../core/vault.dart';
import 'photo.dart';
import 'share.dart';
import 'theme.dart';

Widget _lines(List<String> lines) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (i, l) in lines.indexed)
        Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l, style: TextStyle(fontSize: i == 0 ? 20 : 15, fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w400))),
    ]);

Widget _proofThumb(Rec p) => p.str('type') == 'photo'
    ? Image.file(File(p.str('value')),
        height: 150, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(height: 150, child: Center(child: Text('Photo missing'))))
    : Text(p.str('value'));

class VaultTool extends ConsumerWidget {
  const VaultTool(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final share = ref.read(shareProvider);
    switch (n) {
      case 134:
        final pairs = beforeAfter(v);
        if (pairs.isEmpty) return const Text('Needs two photo proofs in the same project. The first and the latest are shown side by side.', style: TextStyle(color: dim));
        return Column(children: [
          for (final (name, a, b) in pairs) ...[
            Align(alignment: Alignment.centerLeft, child: H(name)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Column(children: [_proofThumb(a), Text(dayLabel(a.integer('day')), style: const TextStyle(color: dim))])),
              const SizedBox(width: 8),
              Expanded(child: Column(children: [_proofThumb(b), Text(dayLabel(b.integer('day')), style: const TextStyle(color: dim))])),
            ]),
            const SizedBox(height: 16),
          ],
        ]);
      case 135:
        return _lines(dailyPage(v, v.today));
      case 136:
        final text = weeklyDigest(v);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(border: cyan, child: Text(text, key: const Key('digest'), style: const TextStyle(fontSize: 16, height: 1.5))),
          const SizedBox(height: 12),
          FilledButton(key: const Key('shareDigest'), onPressed: () => share(text: text), child: const Text('SHARE')),
        ]);
      case 138:
        final items = doneList(v);
        if (items.isEmpty) return const Text('Nothing finished yet. This fills by itself.', style: TextStyle(color: dim));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (day, text) in items.take(100))
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('✓ $text  ·  ${dayLabel(day)}')),
        ]);
      case 139 || 143:
        final items = pinned(v);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.isEmpty) const Text('Pin items from the Vault tab (the pin on each card). They collect here.', style: TextStyle(color: dim)),
          for (final p in items)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [H(dayLabel(p.integer('day')), size: 10), const SizedBox(height: 6), _proofThumb(p)]))),
          if (n == 143 && items.isNotEmpty)
            FilledButton(key: const Key('exportPortfolio'), onPressed: () => share(text: portfolioExport(v)), child: const Text('EXPORT AS TEXT')),
        ]);
      case 144:
        return const ShareCardTool();
      case 131:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Not connected. Automatic GitHub sync needs network access that this build does not have (see BACKEND.md). Nothing is fetched and nothing is counted.',
              style: TextStyle(color: gold)),
          const SizedBox(height: 12),
          const Text('Until then: paste a commit link as proof on the proof screen (LINK). It lands in the Vault like any other proof.'),
          const SizedBox(height: 8),
          Text('Link proofs so far: ${v.proofs.where((p) => p.str('type') == 'link').length}', style: const TextStyle(color: dim)),
        ]);
      case 146 || 147:
        final last = v.settingInt('lastExport', 0);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(backupStale(v) ? Icons.warning_amber : Icons.check_circle, color: backupStale(v) ? gold : cyan),
            const SizedBox(width: 8),
            Expanded(
                child: Text(last == 0
                    ? 'Never backed up.'
                    : 'Last export: ${dayLabel(dayOf(last, v.now.offsetMin, v.dayEndHour))}.')),
          ]),
          const SizedBox(height: 8),
          const Text('Everything is stored on this phone and works offline. Cloud backup is not connected (BACKEND.md). The manual backup is the JSON export: save the file to Drive or send it to yourself.',
              style: TextStyle(color: dim)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.push('/settings'), child: const Text('OPEN SETTINGS TO EXPORT')),
        ]);
      case 142:
        final totals = unitTotals(v);
        if (totals.isEmpty) return const Text('Add a count (words, pages, problems) when you save proof. Lifetime totals appear here.', style: TextStyle(color: dim));
        return Column(children: [
          for (final e in totals.entries)
            ListTile(contentPadding: EdgeInsets.zero, title: Text(e.key.toUpperCase()), trailing: Big('${e.value}', size: 32, color: cyan)),
        ]);
      case 148:
        final items = onThisDay(v);
        if (items.isEmpty) return const Text('Nothing from a month or a year ago today. Keep saving proof and this fills up.', style: TextStyle(color: dim));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (label, p) in items) ...[H(label), const SizedBox(height: 4), _proofThumb(p), const SizedBox(height: 12)],
        ]);
      case 149:
        final photos = v.of('progress').reversed.toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton.icon(
              key: const Key('progressPhoto'),
              onPressed: () async {
                final path = await ref.read(photoProvider)();
                if (path != null) await ref.read(appProvider.notifier).addRec('progress', {'value': path, 'type': 'photo', 'day': v.today});
              },
              icon: const Icon(Icons.photo_camera),
              label: const Text("TAKE THIS WEEK'S PHOTO")),
          const SizedBox(height: 12),
          for (final p in photos) ...[H('Week of ${dayLabel(weekStart(weekOf(p.integer('day'))))}', size: 10), _proofThumb(p), const SizedBox(height: 10)],
        ]);
    }
    return const SizedBox();
  }
}

/// Feature 144: a 9:16 card for a WhatsApp status, saved as a PNG and shared.
class ShareCardTool extends ConsumerStatefulWidget {
  const ShareCardTool({super.key});
  @override
  ConsumerState<ShareCardTool> createState() => _ShareCardState();
}

class _ShareCardState extends ConsumerState<ShareCardTool> {
  final key = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    return Column(children: [
      RepaintBoundary(
          key: key,
          child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                  key: const Key('shareCard'),
                  color: ink,
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const H('Challenger Timer', color: cyan, size: 16),
                    const Spacer(),
                    Poster(PosterArt.flame, size: 120, level: flameLevel(v.master.current)),
                    Big('${v.master.current}', size: 120, color: Colors.white),
                    const H('Days in a row', color: Colors.white, size: 22),
                    const SizedBox(height: 16),
                    Text('${v.starts} starts · ${v.proofs.length} proofs', style: const TextStyle(color: dim, fontSize: 18)),
                    const Spacer(),
                    Text(v.rank.rank.name.toUpperCase(), style: const TextStyle(color: cyan, fontSize: 22, fontWeight: FontWeight.w900)),
                    const Text('Two minutes a day. That is the whole trick.', style: TextStyle(color: dim)),
                  ])))),
      const SizedBox(height: 12),
      FilledButton(
          key: const Key('shareCardButton'),
          onPressed: () async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(p.join((await getTemporaryDirectory()).path, 'challenger-status.png'));
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            await ref.read(shareProvider)(filePath: file.path);
          },
          child: const Text('SAVE AND SHARE AS IMAGE')),
    ]);
  }
}
