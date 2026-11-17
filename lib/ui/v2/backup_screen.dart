import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/state.dart';
import '../../core/backup.dart';
import '../../core/day.dart';
import '../../core/settings.dart';
import '../share.dart';
import '../theme.dart';

/// Writes [contents] to a temp file called [name] and returns its path.
final backupFileProvider = Provider<Future<String> Function(String name, String contents)>((ref) => (name, contents) async {
      final f = File(p.join((await getTemporaryDirectory()).path, name));
      await f.writeAsString(contents);
      return f.path;
    });

/// Reference 5.12.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupState();
}

class _BackupState extends ConsumerState<BackupScreen> {
  final paste = TextEditingController();
  String? error;

  @override
  void dispose() {
    paste.dispose();
    super.dispose();
  }

  Future<void> _make(bool redacted) async {
    final app = ref.read(appProvider.notifier);
    final path = await ref.read(backupFileProvider)(redacted ? 'challenger-timer-redacted.json' : 'challenger-timer-backup.json', app.exportJson(redacted: redacted));
    await ref.read(shareProvider)(filePath: path);
    if (!redacted) await app.markExported();
  }

  Future<void> _load() async {
    final Backup b;
    try {
      b = decodeBackup(paste.text);
    } on BackupError catch (e) {
      return setState(() => error = e.message);
    }
    setState(() => error = null);
    if (!await confirm(context, 'Replace everything on this phone?', 'The backup holds ${b.summary}.\n\nEverything now in the app is removed first. Rank, streaks and XP are rebuilt from the backup.',
        ok: 'REPLACE', cancel: 'KEEP WHAT I HAVE')) {
      return;
    }
    await ref.read(appProvider.notifier).loadBackup(b);
    paste.clear();
    if (mounted) toast(context, 'Backup loaded.');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final last = int.tryParse(v.kv[S.lastBackup] ?? '');
    return Scaffold(
        appBar: AppBar(title: const Text('BACKUP')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(last == null ? 'Last backup: never' : 'Last backup: ${dayLabel(dayOf(last, v.now.offsetMin, 0))}', key: const Key('bkLast'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Warning: a backup is one file. It is saved nowhere unless you send it somewhere: Drive, email, or a chat with yourself.',
              style: TextStyle(color: Color(0xFFFF8A80))),
          const SizedBox(height: 16),
          FilledButton(key: const Key('bkMake'), onPressed: () => _make(false), child: const Text('MAKE BACKUP')),
          const SizedBox(height: 10),
          OutlinedButton(key: const Key('bkRedacted'), onPressed: () => _make(true), child: const Text('MAKE REDACTED BACKUP')),
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Redacted: project names, notes and proof text are replaced by placeholders. Useful for sending a bug report.', style: TextStyle(color: dim, fontSize: 12))),
          const SizedBox(height: 24),
          const H('Load backup'),
          const SizedBox(height: 6),
          const Text('Loading is by paste for now: open the backup file, copy all of it, paste it here.', style: TextStyle(color: dim)),
          const SizedBox(height: 8),
          TextField(key: const Key('bkPaste'), controller: paste, minLines: 3, maxLines: 6, decoration: InputDecoration(hintText: 'Paste the backup file contents', errorText: error, errorMaxLines: 3)),
          const SizedBox(height: 8),
          OutlinedButton(key: const Key('bkLoad'), onPressed: _load, child: const Text('LOAD BACKUP')),
          const SizedBox(height: 32),
          OutlinedButton(
              key: const Key('bkWipe'),
              style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold, width: 2)),
              onPressed: () async {
                final t = await askText(context, 'Wipe all data?', hint: 'Type DELETE', ok: 'WIPE');
                if (t?.trim().toUpperCase() != 'DELETE') return;
                await ref.read(appProvider.notifier).wipe();
                if (context.mounted) context.go('/welcome');
              },
              child: const Text('WIPE DATA')),
        ]));
  }
}
