import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/state.dart';
import 'theme.dart';

/// Slow breathing for a fixed time (features 208, 223, 283, 560).
class BreathTool extends StatefulWidget {
  const BreathTool(this.seconds, {super.key, this.box = false});
  final int seconds;
  final bool box;
  @override
  State<BreathTool> createState() => _BreathState();
}

class _BreathState extends State<BreathTool> {
  Timer? t;
  int left = 0;
  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void _go() {
    setState(() => left = widget.seconds);
    t?.cancel();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left <= 1) t?.cancel();
      setState(() => left--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = (widget.seconds - left) ~/ 4 % (widget.box ? 4 : 2);
    final label = widget.box ? const ['Breathe in', 'Hold', 'Breathe out', 'Hold'][step] : const ['Breathe in', 'Breathe out'][step];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (left > 0) ...[
        Center(child: Big('$left', size: 96, color: accent, key: const Key('breathLeft'))),
        Center(child: H(label, color: Colors.white, size: 20)),
      ] else
        FilledButton(key: const Key('breathStart'), onPressed: _go, child: Text('BREATHE FOR ${widget.seconds} SECONDS')),
    ]);
  }
}

/// Features 207, 214, 215: today's pickups and where the time went.
class UsageTool extends ConsumerStatefulWidget {
  const UsageTool(this.n, {super.key});
  final int n;
  @override
  ConsumerState<UsageTool> createState() => _UsageState();
}

class _UsageState extends ConsumerState<UsageTool> {
  Map<String, Object?>? data;
  @override
  void initState() {
    super.initState();
    ref.read(nativeProvider).usage().then((d) {
      if (mounted) setState(() => data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return const Text('Reading...');
    if (d['granted'] != true) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('This needs usage access, the same permission the app blocker uses. The numbers are read on the phone and never leave it.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => ref.read(nativeProvider).openSettings('usage'), child: const Text('OPEN USAGE ACCESS SETTINGS')),
      ]);
    }
    final apps = ((d['apps'] as List?) ?? const []).cast<Map>();
    final top = widget.n == 215 ? apps.take(3) : apps;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.n == 207) ...[Big('${d['pickups']}', size: 72, color: accent, key: const Key('pickups')), const H('Unlocks today')],
      if (widget.n == 214) ...[Big('${d['total']} min', size: 56, color: accent), const H('Screen time today')],
      if (widget.n != 207)
        for (final a in top) ListTile(contentPadding: EdgeInsets.zero, title: Text('${a['label']}'), trailing: Text('${a['minutes']} min', style: const TextStyle(fontWeight: FontWeight.w800))),
    ]);
  }
}

/// Feature 202: apps that are never blocked.
class AllowTool extends ConsumerStatefulWidget {
  const AllowTool({super.key});
  @override
  ConsumerState<AllowTool> createState() => _AllowState();
}

class _AllowState extends ConsumerState<AllowTool> {
  List<Map<String, String>> apps = const [];
  @override
  void initState() {
    super.initState();
    ref.read(nativeProvider).listApps().then((a) {
      if (mounted) setState(() => apps = a);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final cur = v.kv['allowApps'] == null ? <String>{} : (jsonDecode(v.kv['allowApps']!) as List).cast<String>().toSet();
    return Column(children: [
      for (final a in apps)
        CheckboxListTile(
            key: Key('allow-${a['package']}'),
            contentPadding: EdgeInsets.zero,
            value: cur.contains(a['package']),
            title: Text(a['label'] ?? ''),
            onChanged: (on) {
              on == true ? cur.add(a['package']!) : cur.remove(a['package']);
              ref.read(appProvider.notifier).setSetting('allowApps', jsonEncode(cur.toList()..sort()));
            }),
    ]);
  }
}
