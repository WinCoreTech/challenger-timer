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
import '../core/events.dart';
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
  String tag = '';
  bool hard = false;
  final intention = TextEditingController();

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
    intention.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final s = v.active;
    final rest = s == null ? v.pendingProof != null : s.isBreak;
    return Theme(
        data: appTheme(rest: rest),
        child: Builder(
            builder: (context) => Scaffold(
                body: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: s == null
                            ? (rest ? _done(context, v, app) : _idle(context, v, app))
                            : s.isBreak
                                ? _break(context, v, s, app)
                                : _running(context, v, s, app))))));
  }

  Widget _running(BuildContext context, DayView v, ActiveSession s, App app) {
    final now = ref.read(clockProvider)().ms;
    final left = s.remainingMs(now);
    final hide = v.on(95) && v.kv['hideClock'] == '1';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: H(s.paused ? 'Paused' : 'Work', size: 28, color: cyan)),
        if (s.hard) const H('Hard mode', color: gold),
        if (s.cycleLeft > 0) H('  ${s.cycleLeft} more rounds'),
      ]),
      const SizedBox(height: 8),
      Text(s.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      if (v.on(251) && (v.kv['t.251'] ?? '').length > 4)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(v.single(const ToolDef(n: 251, kind: 'single', title: '', prompts: [''])).first, style: const TextStyle(color: dim))),
      const Spacer(),
      Center(
          child: FittedBox(
              child: Big(hide ? '••:••' : clock(s.flow ? s.elapsedMs(now) : left), size: 120, key: const Key('countdown')))),
      const SizedBox(height: 12),
      if (!s.flow) Bar(1 - left / (s.minutes * msPerMinute), height: 6),
      const SizedBox(height: 8),
      Center(child: H(s.flow ? 'Flowtime: stop when focus fades' : '${s.minutes} minute session', size: 12)),
      const Spacer(),
      if (v.on(92))
        TextButton(
            key: const Key('wander'),
            onPressed: () => app.log(Ev.tool, {'n': 92, 'sid': s.sid}),
            child: Text('MIND WANDERED · ${wanderCount(v, sid: s.sid)} (no penalty, just notice)')),
      if (v.on(8) && (v.kv['t.8'] ?? '').contains('http'))
        TextButton.icon(
            key: const Key('playlist'),
            onPressed: () => ref.read(nativeProvider).openUrl(
                v.single(ref.read(toolsProvider)[8] ?? const ToolDef(n: 8, kind: 'single', title: '', prompts: [''])).first),
            icon: const Icon(Icons.music_note),
            label: const Text('PLAY MY SESSION-ONLY PLAYLIST')),
      Row(children: [
        if (s.paused)
          Expanded(child: FilledButton(key: const Key('resume'), onPressed: app.resumeSession, child: const Text('RESUME')))
        else if (v.on(91) && !s.hard && s.pauses < 2) ...[
          Expanded(
              child: OutlinedButton(
                  key: const Key('pause'),
                  onPressed: () async {
                    final why = await askText(context, 'Pause for what?', hint: 'Door, phone call, water...', ok: 'PAUSE');
                    if (why != null && why.trim().isNotEmpty) await app.pauseSession(why.trim());
                  },
                  child: Text('PAUSE (${2 - s.pauses} LEFT)'))),
          const SizedBox(width: 10),
        ],
        if (!s.paused)
          Expanded(
              child: OutlinedButton(
                  key: const Key('stop'),
                  onPressed: () async {
                    final early = s.elapsedMs(ref.read(clockProvider)().ms) < 2 * msPerMinute;
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
                  child: const Text('STOP'))),
      ]),
    ]);
  }

  Widget _break(BuildContext context, DayView v, ActiveSession s, App app) {
    final left = s.remainingMs(ref.read(clockProvider)().ms);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const H('Rest', size: 28, color: ink),
      const SizedBox(height: 8),
      if (v.on(94))
        Text(breakIdea(s.startMs ~/ 1000), key: const Key('breakIdea'), style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800)),
      const Spacer(),
      Center(child: FittedBox(child: Big(clock(left), size: 120, color: ink, key: const Key('countdown')))),
      Center(child: H(s.cycleLeft > 0 ? 'Break. The next round starts by itself.' : 'Break', size: 12, color: ink)),
      const Spacer(),
      if (s.cycleLeft > 0)
        FilledButton(key: const Key('skipBreak'), onPressed: app.skipBreak, child: const Text('SKIP THE BREAK, NEXT ROUND')),
      const SizedBox(height: 10),
      OutlinedButton(key: const Key('endBreak'), onPressed: app.stopSession, child: Text(s.cycleLeft > 0 ? 'END THE CYCLE HERE' : 'END BREAK')),
    ]);
  }

  Widget _done(BuildContext context, DayView v, App app) {
    final pending = v.pendingProof!;
    final rest = pending['break'] as int?;
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
      if (v.on(300))
        const Center(
            child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Fist pump. Out loud if nobody is looking.', style: TextStyle(color: ink)))),
      const Spacer(),
      FilledButton(
          key: const Key('saveProof'), onPressed: () => context.push('/proof'), child: const Text('SAVE PROOF')),
      const SizedBox(height: 12),
      OutlinedButton(
          key: const Key('fiveMore'),
          onPressed: () => app.startSession(
              minutes: 5, projectId: pending['projectId'] as String?, title: pending['title'] as String?, source: 'five_more'),
          child: const Text('JUST FIVE MORE')),
      if (rest != null && v.on(78)) ...[
        const SizedBox(height: 12),
        TextButton(key: const Key('flowBreak'), onPressed: () => app.startBreak(rest), child: Text('TAKE A $rest-MINUTE BREAK (SIZED TO THE WORK)')),
      ],
    ]);
  }

  Widget _idle(BuildContext context, DayView v, App app) {
    final pid = projectId ?? v.kv[K.lastProject];
    final native = ref.read(nativeProvider);
    String? title() => intention.text.trim().isEmpty ? null : intention.text.trim();
    Future<void> go({int? m, bool flow = false, int work = 0, int rest = 0, int rounds = 0, String source = 'app'}) async {
      final noise = v.on(96) ? v.kv['noise'] ?? '' : '';
      await app.startSession(
          minutes: work > 0 ? work : m ?? minutes, projectId: pid, title: title(), tag: tag, hard: hard && v.on(90), flow: flow,
          cycleWork: work, cycleRest: rest, cycleLeft: rounds > 0 ? rounds - 1 : 0, source: source);
      if (noise.isNotEmpty) await native.noise(noise);
    }

    final extras = v.on(77) || v.on(78) || v.on(90) || v.on(95) || v.on(96) || v.on(99);
    final leftHard = v.events.isNotEmpty &&
        v.events.last.type == Ev.sessionAbandon &&
        v.events.last.get<String>('reason') == 'left' &&
        v.events.last.day == v.today;
    return ListView(children: [
      const H('Timer', size: 28, color: Colors.white),
      const SizedBox(height: 8),
      Text(
          leftHard
              ? 'Hard mode ended that one when you left the app. No harm done. Start another when ready.'
              : 'Pick a length. Two minutes is a full win.',
          style: const TextStyle(color: dim)),
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
        const SizedBox(height: 16),
      ],
      if (v.on(82)) ...[
        TextField(
            key: const Key('intention'),
            controller: intention,
            maxLength: 100,
            decoration: const InputDecoration(hintText: 'Intention for this session (optional)', counterText: '')),
        const SizedBox(height: 12),
      ],
      if (v.on(97))
        Wrap(spacing: 8, children: [
          for (final t in const ['study', 'code', 'write', 'admin'])
            ChoiceChip(key: Key('tag-$t'), label: Text(t.toUpperCase()), selected: tag == t, onSelected: (on) => setState(() => tag = on ? t : '')),
        ]),
      const SizedBox(height: 12),
      Center(child: Big('${two(minutes)}:00', size: 96)),
      const SizedBox(height: 12),
      Row(children: [
        if (v.on(18))
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.outlined(
                  key: const Key('voiceStart'),
                  tooltip: 'Voice start',
                  onPressed: () async {
                    final heard = await native.listen();
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
                    if (await fiveSecondLaunch(context)) await go(source: 'launch5');
                  },
                  child: const Text('5·4·3·2·1'))),
        Expanded(child: FilledButton(key: const Key('timerStart'), onPressed: go, child: const Text('START'))),
      ]),
      if (extras)
        ExpansionTile(
            key: const Key('moreModes'),
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            title: const H('More ways to run it'),
            children: [
              if (v.on(90))
                SwitchListTile(
                    key: const Key('hardMode'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hard mode'),
                    subtitle: const Text('Leaving the app ends the session without credit. The screen stays on.', style: TextStyle(color: dim, fontSize: 12)),
                    value: hard,
                    onChanged: (x) => setState(() => hard = x)),
              if (v.on(95))
                SwitchListTile(
                    key: const Key('hideClock'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide the clock digits'),
                    value: v.kv['hideClock'] == '1',
                    onChanged: (x) => app.setSetting('hideClock', x ? '1' : '0')),
              if (v.on(96))
                Wrap(spacing: 8, children: [
                  for (final (id, label) in const [('', 'SILENT'), ('brown', 'BROWN NOISE'), ('rain', 'RAIN-LIKE'), ('white', 'WHITE NOISE')])
                    ChoiceChip(
                        key: Key('noise-$id'),
                        label: Text(label),
                        selected: (v.kv['noise'] ?? '') == id,
                        onSelected: (_) => app.setSetting('noise', id)),
                ]),
              const SizedBox(height: 8),
              if (v.on(77))
                OutlinedButton(key: const Key('pomodoro'), onPressed: () => go(work: 25, rest: 5, rounds: 4, source: 'cycle'), child: const Text('POMODORO: 4 × 25 MIN, 5 MIN BREAKS')),
              const SizedBox(height: 8),
              if (v.on(78))
                OutlinedButton(key: const Key('flowtime'), onPressed: () => go(flow: true, source: 'flow'), child: const Text('FLOWTIME: COUNT UP, STOP WHEN FOCUS FADES')),
              const SizedBox(height: 8),
              if (v.on(99))
                OutlinedButton(key: const Key('marathon'), onPressed: () => go(work: 25, rest: 5, rounds: 6, source: 'marathon'), child: const Text('MARATHON DAY: 6 × 25 MIN, BREAKS ENFORCED')),
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
  String outcome = '';
  int difficulty = 0;

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
    final receipt = ref.read(viewProvider).on(100);
    await ref.read(appProvider.notifier)
        .saveProof(type: type, value: v, parkingNote: note.text, outcome: outcome, difficulty: difficulty);
    if (mounted) context.go(receipt ? '/receipt' : '/');
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
          if (v.on(83)) ...[
            const SizedBox(height: 16),
            const H('How did it go?'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final o in const ['done', 'partly', 'stuck'])
                ChoiceChip(key: Key('outcome-$o'), label: Text(o.toUpperCase()), selected: outcome == o, onSelected: (_) => setState(() => outcome = o)),
            ]),
          ],
          if (v.on(98)) ...[
            const SizedBox(height: 16),
            const H('How hard was it? Harder pays more XP'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final (i, o) in const ['EASY', 'MEDIUM', 'HARD'].indexed)
                ChoiceChip(key: Key('difficulty-${i + 1}'), label: Text(o), selected: difficulty == i + 1, onSelected: (_) => setState(() => difficulty = i + 1)),
            ]),
          ],
          const SizedBox(height: 24),
          FilledButton(key: const Key('proofSave'), onPressed: _save, child: const Text('SAVE AND FINISH')),
        ]));
  }
}


/// Feature 100: a summary card right after the proof is saved.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final p = v.rec(ref.read(appProvider.notifier).lastProofId) ?? (v.proofs.isEmpty ? null : v.proofs.first);
    Widget row(String k, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: H(k, size: 11)),
          Expanded(child: Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]));
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Spacer(),
                  Panel(
                      key: const Key('receipt'),
                      border: cyan,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const H('Session receipt', color: cyan, size: 18),
                        const Divider(),
                        if (p != null) ...[
                          row('Time', '${p.integer('minutes')} minutes'),
                          row('Task', p.str('title')),
                          row('Project', v.rec(p.str('projectId'))?.str('name') ?? 'No project'),
                          row('Proof', p.str('type') == 'photo' ? 'Photo saved' : p.str('value')),
                          if (p.str('outcome').isNotEmpty) row('Outcome', p.str('outcome')),
                        ],
                        row('Streak', '${v.master.current} days'),
                        row('Today', '${v.sessionsToday} sessions, ${v.minutesToday} min'),
                        row('Rank', v.rank.rank.name),
                      ])),
                  const Spacer(),
                  FilledButton(key: const Key('receiptDone'), onPressed: () => context.go('/'), child: const Text('DONE')),
                ]))));
  }
}
