import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/events.dart';
import '../../core/settings.dart';
import '../../core/tree.dart';
import '../theme.dart';

/// Reference 5.6. [id] is a project id, or 'new'.
class ProjectEditScreen extends ConsumerStatefulWidget {
  const ProjectEditScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<ProjectEditScreen> createState() => _EditState();
}

class _EditState extends ConsumerState<ProjectEditScreen> {
  final name = TextEditingController();
  String parent = '';
  int work = 0, short = 0, long = 0;
  bool loaded = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final p = v.rec(widget.id);
    if (!loaded) {
      name.text = p?.str('name') ?? '';
      parent = p?.str('parentId') ?? '';
      work = p?.integer('workMin') ?? 0;
      short = p?.integer('shortBreakMin') ?? 0;
      long = p?.integer('longBreakMin') ?? 0;
      loaded = true;
    }
    Widget pick(String label, Key key, int value, List<int> options, int global, ValueChanged<int> set) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<int>(
            key: key,
            initialValue: options.contains(value) ? value : 0,
            decoration: InputDecoration(labelText: label),
            isExpanded: true,
            dropdownColor: panel,
            items: [
              DropdownMenuItem(value: 0, child: Text('Default ($global min)')),
              for (final o in options) DropdownMenuItem(value: o, child: Text('$o min')),
            ],
            onChanged: (x) => setState(() => set(x ?? 0))));
    final parents = v.projects.where((x) => x.id != widget.id && (p == null || canSetParent(v, p.id, x.id))).toList();
    return Scaffold(
        appBar: AppBar(title: Text(p == null ? 'NEW PROJECT' : 'EDIT PROJECT')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(key: const Key('peName'), controller: name, decoration: InputDecoration(labelText: 'Project name', errorText: error)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              key: const Key('peParent'),
              initialValue: parents.any((x) => x.id == parent) ? parent : '',
              decoration: const InputDecoration(labelText: 'Inside project'),
              isExpanded: true,
            dropdownColor: panel,
              items: [
                const DropdownMenuItem(value: '', child: Text('No parent')),
                for (final x in parents) DropdownMenuItem(value: x.id, child: Text(x.str('name'))),
              ],
              onChanged: (x) => setState(() => parent = x ?? '')),
          const SizedBox(height: 12),
          pick('Work session', const Key('peWork'), work, const [10, 15, 20, 25, 30, 45, 50, 60, 90], v.prefInt(S.workMin), (x) => work = x),
          pick('Short break', const Key('peShort'), short, const [3, 5, 10, 15], v.prefInt(S.shortBreakMin), (x) => short = x),
          pick('Long break', const Key('peLong'), long, const [10, 15, 20, 30], v.prefInt(S.longBreakMin), (x) => long = x),
          const Text('Note: a length set here replaces the global setting for this project and for projects inside it.', style: TextStyle(color: gold, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
              key: const Key('peSave'),
              onPressed: () async {
                if (name.text.trim().isEmpty) return setState(() => error = 'A project needs a name.');
                final data = {'name': name.text.trim(), 'parentId': parent, 'workMin': work, 'shortBreakMin': short, 'longBreakMin': long};
                p == null ? await app.addRec(Kind.project, data) : await app.putRec(p.copy(data));
                if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
              },
              child: const Text('SAVE')),
        ]));
  }
}
