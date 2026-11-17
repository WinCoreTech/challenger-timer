import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/day.dart';
import '../../core/engine.dart';
import '../../core/events.dart';
import '../../core/v2_schedule.dart';
import '../theme.dart';

/// Weekly work blocks (reference spec 5.10).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static void _help(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
              backgroundColor: panel,
              title: const H('How the schedule works', color: Colors.white, size: 16),
              content: const SingleChildScrollView(
                  child: Text('A block is an appointment with your own work: a weekday, a start time, a length '
                      'and, if you like, a project.\n\n'
                      'Blocks repeat every week. With the reminder on, the phone taps you on the shoulder at '
                      'the start time. It does not start the timer for you. That part is still your job.\n\n'
                      'Missing a block costs nothing. It simply turns up again next week, on time, as usual.')),
              actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('GOT IT'))]));

  static void _create(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const _BlockEditor()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final any = v.of(blockKind).isNotEmpty;
    final today = weekdayOf(v.today);
    return Scaffold(
        appBar: AppBar(title: const Text('SCHEDULE'), actions: [
          IconButton(
              key: const Key('schedHelp'),
              tooltip: 'Help with the schedule',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _help(context)),
        ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (!any) ...[
                            const SizedBox(height: 24),
                            const Center(child: Poster(PosterArt.hourglass)),
                            const SizedBox(height: 24),
                            const H('No schedule yet', color: Colors.white, size: 18),
                            const SizedBox(height: 8),
                            const Text('Work that has no time of its own tends to happen "later". '
                                'Give one block a weekday and an hour. One is enough to begin.'),
                            const SizedBox(height: 24),
                          ],
                          for (var wd = 1; wd <= 7; wd++)
                            if (blocksOn(v, wd).isNotEmpty) ...[
                              Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                                  child: H(wd == today ? '${weekdayNames[wd - 1]} (today)' : weekdayNames[wd - 1],
                                      color: wd == today ? accent : dim)),
                              for (final b in blocksOn(v, wd))
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _BlockTile(
                                        key: Key('block-${b.id}'),
                                        block: b,
                                        project: blockProject(v, b),
                                        onDelete: () async {
                                          if (await confirm(context, 'Delete this block?',
                                              '${weekdayNames[wd - 1]}, ${blockSpan(b)}. Its reminder goes with it.',
                                              ok: 'DELETE', cancel: 'KEEP')) {
                                            await app.deleteRec(b.id);
                                            await app.syncNative();
                                          }
                                        })),
                            ],
                          const SizedBox(height: 12),
                          FilledButton(
                              key: const Key('schedCreate'),
                              onPressed: () => _create(context),
                              child: Text(any ? 'ADD BLOCK' : 'CREATE SCHEDULE', textAlign: TextAlign.center)),
                        ]))))));
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({super.key, required this.block, required this.project, required this.onDelete});
  final Rec block;
  final String project;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Panel(
      padding: 12,
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(blockSpan(block), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${block.integer('len')} min · ${project.isEmpty ? 'No project' : project}'),
          const SizedBox(height: 4),
          Text(block.flag('remind') ? 'Reminder at start: on' : 'Reminder at start: off',
              style: const TextStyle(color: dim)),
        ])),
        IconButton(
            key: Key('blockDelete-${block.id}'),
            tooltip: 'Delete block at ${hhmm(block.integer('minute'))}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete),
      ]));
}

class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor();
  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  late final DayView _v = ref.read(viewProvider);
  late final Set<int> _days = {weekdayOf(_v.today)};
  late int _minute = _v.cueMinute % 1440;
  int _len = 25;
  String _project = '';
  bool _remind = true;

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: _minute ~/ 60, minute: _minute % 60), helpText: 'BLOCK STARTS AT');
    if (t != null) setState(() => _minute = t.hour * 60 + t.minute);
  }

  Future<void> _save() async {
    final app = ref.read(appProvider.notifier);
    for (final wd in _days.toList()..sort()) {
      await app.addRec(blockKind, {'wd': wd, 'minute': _minute, 'len': _len, 'projectId': _project, 'remind': _remind});
    }
    await app.syncNative();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(viewProvider).projects;
    final project = projects.any((p) => p.id == _project) ? _project : '';
    return Scaffold(
        appBar: AppBar(title: const Text('NEW BLOCK')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const H('Which days'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            for (var wd = 1; wd <= 7; wd++)
                              FilterChip(
                                  key: Key('schedDay-$wd'),
                                  materialTapTargetSize: MaterialTapTargetSize.padded,
                                  label: Text(weekdayNames[wd - 1]),
                                  selected: _days.contains(wd),
                                  onSelected: (on) => setState(() => on ? _days.add(wd) : _days.remove(wd))),
                          ]),
                          if (_days.isEmpty)
                            const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Note: pick at least one day. "Someday" is not on the list.',
                                    style: TextStyle(color: gold))),
                          const SizedBox(height: 20),
                          const H('Starts at'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                              key: const Key('schedTime'),
                              onPressed: _pickTime,
                              icon: const Icon(Icons.schedule),
                              label: Text('${hhmm(_minute)} (tap to change)', textAlign: TextAlign.center)),
                          const SizedBox(height: 20),
                          const H('Length'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            for (final l in blockLengths)
                              ChoiceChip(
                                  key: Key('schedLen-$l'),
                                  materialTapTargetSize: MaterialTapTargetSize.padded,
                                  label: Text('$l min'),
                                  selected: _len == l,
                                  onSelected: (_) => setState(() => _len = l)),
                          ]),
                          const SizedBox(height: 20),
                          const H('Project'),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                              key: const Key('schedProject'),
                              isExpanded: true,
                              itemHeight: null,
                              dropdownColor: panel,
                              value: project,
                              items: [
                                const DropdownMenuItem(value: '', child: Text('No project')),
                                for (final p in projects)
                                  DropdownMenuItem(
                                      value: p.id, child: Text(p.str('name'), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (x) => setState(() => _project = x ?? '')),
                          const SizedBox(height: 12),
                          SwitchListTile(
                              key: const Key('schedRemind'),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Remind me at the start'),
                              subtitle: Text(
                                  _remind ? 'On: one notification when the block begins' : 'Off: the block stays silent'),
                              value: _remind,
                              onChanged: (x) => setState(() => _remind = x)),
                          const SizedBox(height: 20),
                          FilledButton(
                              key: const Key('schedSave'),
                              onPressed: _days.isEmpty ? null : _save,
                              child: const Text('SAVE BLOCK', textAlign: TextAlign.center)),
                        ]))))));
  }
}
