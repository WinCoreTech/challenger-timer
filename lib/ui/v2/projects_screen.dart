import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/engine.dart';
import '../../core/events.dart';
import '../../core/settings.dart';
import '../../core/tree.dart';
import '../theme.dart';

/// Reference 5.4: picker popup. Returns a project id, '' for none, or null.
Future<String?> pickProject(BuildContext context, WidgetRef ref) => showDialog<String>(
    context: context,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
          final v = ref.watch(viewProvider);
          return StatefulBuilder(builder: (ctx, set) {
            final q = _pickerQuery[ctx.hashCode] ?? '';
            return AlertDialog(
                backgroundColor: panel,
                title: const H('What are you working on?', color: Colors.white, size: 15),
                content: SizedBox(
                    width: double.maxFinite,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          key: const Key('pickerSearch'),
                          decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)),
                          onChanged: (x) => set(() => _pickerQuery[ctx.hashCode] = x)),
                      Flexible(
                          child: ListView(shrinkWrap: true, children: [
                        ListTile(
                            key: const Key('pick-none'),
                            selected: v.kv[K.lastProject] == null,
                            title: const Text('No project'),
                            onTap: () => Navigator.pop(ctx, '')),
                        for (final r in projectRows(v, filter: q))
                          ListTile(
                              key: Key('pick-${r.project.id}'),
                              selected: v.kv[K.lastProject] == r.project.id,
                              contentPadding: EdgeInsets.only(left: 16.0 + r.depth * 20, right: 16),
                              title: Text(r.project.str('name')),
                              onTap: () => Navigator.pop(ctx, r.project.id)),
                      ])),
                    ])));
          });
        }));

final _pickerQuery = <int, String>{};

/// Reference 5.5.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsState();
}

class _ProjectsState extends ConsumerState<ProjectsScreen> {
  String q = '';

  Future<void> _delete(DayView v, App app, Rec p) async {
    if (!await confirm(context, 'Delete "${p.str('name')}"?', 'Its sessions and proof stay in your history. Projects inside it move up one level.', ok: 'DELETE', cancel: 'KEEP')) return;
    for (final c in childrenOf(v, p.id)) {
      await app.putRec(c.copy({'parentId': p.str('parentId')}));
    }
    await app.deleteRec(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    final rows = projectRows(v, filter: q);
    return Scaffold(
        appBar: AppBar(title: const Text('PROJECTS'), actions: [
          IconButton(
              key: const Key('projHelp'),
              tooltip: 'Help',
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                      backgroundColor: panel,
                      title: const H('Projects', color: Colors.white, size: 16),
                      content: const Text('A project collects its sessions, time and proof.\n\n'
                          'Projects can sit inside other projects. A parent\'s time includes everything under it.\n\n'
                          'A project can have its own session and break lengths. They apply to it and to projects inside it.\n\n'
                          'Bright rows with a bolt were worked on in the last 7 days. Dim rows with a moon have been resting longer.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('GOT IT'))])),
              icon: const Icon(Icons.help_outline)),
        ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        key: const Key('projFilter'),
                        decoration: const InputDecoration(hintText: 'Filter by name', prefixIcon: Icon(Icons.search)),
                        onChanged: (x) => setState(() => q = x))),
                PopupMenuButton<String>(
                    key: const Key('projSort'),
                    tooltip: 'Sort',
                    icon: const Icon(Icons.sort),
                    onSelected: (m) => app.setSetting(S.sortProjectsBy, m),
                    itemBuilder: (_) => [
                          for (final (id, label) in const [('activity', 'Last activity'), ('name', 'Name'), ('time', 'Time worked')])
                            CheckedPopupMenuItem(value: id, checked: v.pref(S.sortProjectsBy) == id, child: Text(label)),
                        ]),
                IconButton(key: const Key('projAdd'), tooltip: 'Add a project', onPressed: () => context.push('/project/new'), icon: const Icon(Icons.add)),
              ])),
          Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(q.isEmpty ? 'No projects yet. Add one with the plus, so your hours have somewhere to go.' : 'Nothing matches "$q".',
                              key: const Key('projEmpty'), textAlign: TextAlign.center, style: const TextStyle(color: dim))))
                  : ListView(children: [
                      for (final r in rows)
                        Builder(builder: (_) {
                          final active = r.activeOn(v.today);
                          return ListTile(
                              key: Key('proj-${r.project.id}'),
                              contentPadding: EdgeInsets.only(left: 16.0 + r.depth * 24, right: 4),
                              leading: Icon(active ? Icons.bolt : Icons.bedtime_outlined, color: active ? accent : dim, semanticLabel: active ? 'Active this week' : 'Resting'),
                              title: Text(r.project.str('name'), style: TextStyle(color: active ? Colors.white : dim, fontWeight: FontWeight.w600)),
                              subtitle: Text(hm(r.minutes), style: const TextStyle(color: dim)),
                              onTap: () => context.push('/project/${r.project.id}'),
                              trailing: PopupMenuButton<String>(
                                  tooltip: 'More',
                                  onSelected: (m) async {
                                    if (m == 'edit') context.push('/project/${r.project.id}');
                                    if (m == 'archive') await app.putRec(r.project.copy({'archived': true}));
                                    if (m == 'delete') await _delete(v, app, r.project);
                                  },
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                                        PopupMenuItem(value: 'archive', child: Text('Archive')),
                                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                                      ]));
                        }),
                    ])),
        ]));
  }
}
