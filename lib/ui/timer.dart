import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/extras.dart';
import '../core/tools.dart';
import 'special.dart';
import 'theme.dart';

const presets = [2, 5, 15, 25, 50, 90];

String clock(int ms) {
  final s = (ms / 1000).ceil();
  return '${two(s ~/ 60)}:${two(s % 60)}';
}

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});
  @override
  ConsumerState<TimerScreen> createState() => _TimerState();
}

class _TimerState extends ConsumerState<TimerScreen> {
  Timer? _t;
  int minutes = 2;
  String? projectId;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (!mounted) return;
      if (ref.read(viewProvider).active != null) {
        await ref.read(appProvider.notifier).completeIfDue();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final s = v.active;
    final rest = s == null && v.pendingProof != null;
    return Theme(
        data: appTheme(rest: rest),
        child: Builder(
            builder: (context) => Scaffold(
                body: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: s != null
                            ? _running(context, v, s, app)
                            : rest
                                ? _done(context, v, app)
                                : _idle(context, v, app))))));
  }

  Widget _running(BuildContext context, DayView v, ActiveSession s, App app) {
    final left = s.remainingMs(ref.read(clockProvider)().ms);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const H('Work', size: 28, color: cyan),
      const SizedBox(height: 8),
      Text(s.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const Spacer(),
      Center(child: FittedBox(child: Big(clock(left), size: 120, key: const Key('countdown')))),
      const SizedBox(height: 12),
      Bar(1 - left / (s.minutes * msPerMinute), height: 6),
      const SizedBox(height: 8),
      Center(child: H('${s.minutes} minute session', size: 12)),
      const Spacer(),
      if (v.on(8) && (v.kv['t.8'] ?? '').contains('http'))
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
                key: const Key('playlist'),
                onPressed: () => ref.read(nativeProvider).openUrl(
                    v.single(ref.read(toolsProvider)[8] ?? const ToolDef(n: 8, kind: 'single', title: '', prompts: [''])).first),
                icon: const Icon(Icons.music_note),
                label: const Text('PLAY MY SESSION-ONLY PLAYLIST'))),
      OutlinedButton(
          key: const Key('stop'),
          onPressed: () async {
            final early = (ref.read(clockProvider)().ms - s.startMs) < 2 * msPerMinute;
            final ok = await confirm(
                context,
                'Stop here?',
                early
                    ? 'Under two minutes will not count as a session. No drama, the timer can keep going.'
                    : 'You passed two minutes, so this counts as a finished session.',
                ok: 'STOP',
                cancel: 'KEEP GOING');
            if (ok) await app.stopSession();
          },
          child: const Text('STOP')),
    ]);
  }

  Widget _done(BuildContext context, DayView v, App app) {
    final pending = v.pendingProof!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const H('Rest', size: 28, color: ink),
      const Spacer(),
      const Center(child: Poster(PosterArt.shield, size: 120, color: ink)),
      const SizedBox(height: 16),
      const Center(child: Big('DONE.', size: 72, color: ink)),
      const SizedBox(height: 8),
      Center(
          child: Text('${pending['minutes']} minutes finished. That is a full win.',
              style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w700))),
      const Spacer(),
      FilledButton(
          key: const Key('saveProof'), onPressed: () => context.push('/proof'), child: const Text('SAVE PROOF')),
      const SizedBox(height: 12),
      OutlinedButton(
          key: const Key('fiveMore'),
          onPressed: () => app.startSession(
              minutes: 5, projectId: pending['projectId'] as String?, title: pending['title'] as String?, source: 'five_more'),
          child: const Text('JUST FIVE MORE')),
    ]);
  }

  Widget _idle(BuildContext context, DayView v, App app) {
    final pid = projectId ?? v.kv[K.lastProject];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const H('Timer', size: 28, color: Colors.white),
      const SizedBox(height: 8),
      const Text('Pick a length. Two minutes is a full win.', style: TextStyle(color: dim)),
      const SizedBox(height: 20),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final m in presets)
          ChoiceChip(
              key: Key('preset$m'),
              label: Padding(padding: const EdgeInsets.all(6), child: Text('$m MIN', style: const TextStyle(fontSize: 16))),
              selected: minutes == m,
              onSelected: (_) => setState(() => minutes = m)),
      ]),
      const SizedBox(height: 20),
      if (v.projects.isNotEmpty) ...[
        const H('Project'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final pr in v.projects)
            ChoiceChip(
                label: Text(pr.str('name')),
                selected: pid == pr.id,
                onSelected: (_) => setState(() => projectId = pr.id)),
        ]),
      ],
      const Spacer(),
      Center(child: Big('${two(minutes)}:00', size: 96)),
      const Spacer(),
      Row(children: [
        if (v.on(18))
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.outlined(
                  key: const Key('voiceStart'),
                  tooltip: 'Voice start',
                  onPressed: () async {
                    final heard = await ref.read(nativeProvider).listen();
                    final cmd = heard == null ? null : parseVoice(heard, v.projects);
                    if (cmd == null) {
                      if (context.mounted) toast(context, 'Did not catch a start. Try "start five minutes on DSA".');
                      return;
                    }
                    await app.startSession(minutes: cmd.minutes, projectId: cmd.projectId ?? pid, source: 'voice');
                  },
                  icon: const Icon(Icons.mic))),
        if (v.on(4))
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                  key: const Key('launch5'),
                  onPressed: () async {
                    if (await fiveSecondLaunch(context)) await app.startSession(minutes: minutes, projectId: pid, source: 'launch5');
                  },
                  child: const Text('5·4·3·2·1'))),
        Expanded(
            child: FilledButton(
                key: const Key('timerStart'),
                onPressed: () => app.startSession(minutes: minutes, projectId: pid),
                child: const Text('START'))),
      ]),
    ]);
  }
}

/// Takes a compressed camera photo and returns the saved file path.
final photoProvider = Provider<Future<String?> Function()>((ref) => () async {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
      if (x == null) return null;
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'proof'));
      await dir.create(recursive: true);
      final dest = p.join(dir.path, 'p${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(x.path).copy(dest);
      return dest;
    });

class ProofScreen extends ConsumerStatefulWidget {
  const ProofScreen({super.key});
  @override
  ConsumerState<ProofScreen> createState() => _ProofState();
}

class _ProofState extends ConsumerState<ProofScreen> {
  String type = 'text';
  final value = TextEditingController();
  final note = TextEditingController();
  String? photo;
  String? error;

  @override
  void dispose() {
    value.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = type == 'photo' ? (photo ?? '') : value.text.trim();
    if (v.isEmpty) {
      setState(() => error = type == 'photo' ? 'Take the photo first, or switch to one line.' : 'One line is enough. Anything true.');
      return;
    }
    if (type == 'link' && !RegExp(r'^https?://\S+\.\S+').hasMatch(v)) {
      setState(() => error = 'That does not look like a link yet. It should start with http.');
      return;
    }
    await ref.read(appProvider.notifier).saveProof(type: type, value: v, parkingNote: note.text);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final pending = v.pendingProof;
    if (pending == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('PROOF')),
          body: const Center(child: Text('Nothing waiting. Start a session and the proof step follows.')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('SAVE PROOF')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('${pending['minutes']} minutes done. Leave one piece of evidence.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'text', label: Text('ONE LINE'), icon: Icon(Icons.notes)),
                ButtonSegment(value: 'photo', label: Text('PHOTO'), icon: Icon(Icons.photo_camera)),
                ButtonSegment(value: 'link', label: Text('LINK'), icon: Icon(Icons.link)),
              ],
              selected: {type},
              onSelectionChanged: (s) => setState(() {
                    type = s.first;
                    error = null;
                  })),
          const SizedBox(height: 16),
          if (type == 'photo') ...[
            if (photo != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photo!), height: 220, fit: BoxFit.cover)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                key: const Key('takePhoto'),
                onPressed: () async {
                  final path = await ref.read(photoProvider)();
                  if (path != null) setState(() => photo = path);
                },
                icon: const Icon(Icons.photo_camera),
                label: Text(photo == null ? 'PHOTOGRAPH YOUR WORK' : 'RETAKE')),
          ] else
            TextField(
                key: const Key('proofValue'),
                controller: value,
                keyboardType: type == 'link' ? TextInputType.url : TextInputType.text,
                maxLength: type == 'link' ? null : 200,
                decoration: InputDecoration(
                    hintText: type == 'link' ? 'https://github.com/you/repo/commit/...' : 'What I did, in one sentence')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: gold))),
          const SizedBox(height: 20),
          const H('Parking note for future you', color: cyan),
          const SizedBox(height: 8),
          TextField(
              key: const Key('parkingNote'),
              controller: note,
              maxLength: 120,
              decoration: const InputDecoration(hintText: 'Exact next step, e.g. Open notebook to page 12')),
          const Text('This becomes the next tiny step on Home.', style: TextStyle(color: dim)),
          const SizedBox(height: 24),
          FilledButton(key: const Key('proofSave'), onPressed: _save, child: const Text('SAVE AND FINISH')),
        ]));
  }
}
