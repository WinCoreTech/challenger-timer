import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/state.dart';
import '../core/day.dart';
import '../core/engine.dart';
import '../core/events.dart';
import '../core/rules.dart';
import 'theme.dart';

/// Opens the Android share sheet. Swapped out in tests.
final shareProvider = Provider<Future<void> Function({String? text, String? filePath})>(
    (ref) => ({String? text, String? filePath}) async {
          await SharePlus.instance
              .share(ShareParams(text: text, files: filePath == null ? null : [XFile(filePath)]));
        });

/// One permission, one plain reason, asked only when a feature needs it.
Future<bool> askPermission(BuildContext context, WidgetRef ref, String name, String title, String reason) async {
  final native = ref.read(nativeProvider);
  if ((await native.status())[name] == true) return true;
  if (!context.mounted) return false;
  if (!await confirm(context, title, reason, ok: 'CONTINUE')) return false;
  const viaSettings = {'usage', 'overlay', 'exactAlarm', 'fullScreen', 'battery'};
  if (viaSettings.contains(name)) {
    await native.openSettings(name);
    return (await native.status())[name] == true;
  }
  return native.requestPermission(name);
}

const _switchInfo = {
  K.swCue: ('Cue alarm', 'A full-screen alarm at your cue time with a Start 2 min button.'),
  K.swBlock: ('Earn your phone', 'Chosen apps stay blocked each day until your first session ends.'),
  K.swBonus: ('Bonus to lose', '100 XP handed to you each morning. It leaves at day end if no session happens.'),
  K.swBuddy: ('Buddy report', 'At 8 pm your buddy gets the day\'s result by SMS, zero days included.'),
  K.swRescue: ('Evening rescue', 'At 9 pm on a zero day, a call-style alert offers a 2-minute save.'),
  K.swLock: ('Locked first task', 'Tomorrow\'s first task cannot be edited after 10 pm.'),
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  Map<String, bool> status = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await ref.read(nativeProvider).status();
    if (mounted) setState(() => status = s);
  }

  Future<void> _turnOn(String key) async {
    final app = ref.read(appProvider.notifier);
    final v = ref.read(viewProvider);
    switch (key) {
      case K.swCue || K.swRescue:
        await askPermission(context, ref, 'notifications', 'Allow notifications',
            'The alarm is a notification that takes over the screen. Without this permission it cannot appear. If you say no, the task still shows on Home.');
        if (mounted) {
          await askPermission(context, ref, 'fullScreen', 'Allow full-screen alarms',
              'Android asks separately before an app may cover the lock screen. Without it you get a normal notification instead.');
        }
      case K.swBlock:
        if (v.blockedApps.isEmpty) {
          await _pickApps();
          if (ref.read(viewProvider).blockedApps.isEmpty) return;
        }
        if (!mounted) return;
        await askPermission(context, ref, 'usage', 'Allow usage access',
            'To know when a blocked app is opened, the app needs to see which app is on screen. Nothing leaves your phone.');
        if (mounted) {
          await askPermission(context, ref, 'overlay', 'Allow display over other apps',
              'The block is a screen drawn on top of the blocked app with a Start button. Android needs your permission for that.');
        }
        if (mounted) {
          await askPermission(context, ref, 'notifications', 'Allow notifications',
              'The blocker runs as a visible background service, which needs a notification.');
        }
      case K.swBuddy:
        if ((v.kv[K.buddyPhone] ?? '').isEmpty) {
          await _editBuddy();
          if ((ref.read(viewProvider).kv[K.buddyPhone] ?? '').isEmpty) return;
        }
        if (!mounted) return;
        final ok = await askPermission(context, ref, 'sms', 'Allow sending SMS',
            'The report goes out by itself at 8 pm, so the app needs to send one SMS a day to your buddy. Normal SMS charges apply.');
        if (!ok && mounted) {
          toast(context, 'No SMS permission. At 8 pm you will get a reminder that opens the share sheet instead.');
        }
    }
    await app.switchOn(key);
    await _refresh();
  }

  Future<void> _pickApps() async {
    final apps = await ref.read(nativeProvider).listApps();
    if (!mounted) return;
    final chosen = {...ref.read(viewProvider).blockedApps};
    final removedBefore = {...chosen};
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    backgroundColor: panel,
                    title: const H('Apps to block until the first session', color: Colors.white, size: 15),
                    content: SizedBox(
                        width: double.maxFinite,
                        child: ListView(shrinkWrap: true, children: [
                          for (final a in apps)
                            CheckboxListTile(
                                value: chosen.contains(a['package']),
                                title: Text(a['label'] ?? ''),
                                onChanged: (on) => set(() => on == true ? chosen.add(a['package']!) : chosen.remove(a['package']))),
                        ])),
                    actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('DONE'))])));
    // Removing an app from the list weakens a lock, so it is only allowed
    // while the blocker is off. Adding is always fine.
    final v = ref.read(viewProvider);
    if (v.isOn(K.swBlock) && removedBefore.difference(chosen).isNotEmpty) {
      chosen.addAll(removedBefore);
      if (mounted) toast(context, 'Apps can be added any time. To remove one, switch the blocker off first (24 hours).');
    }
    await ref.read(appProvider.notifier).setSetting(K.blockedApps, jsonEncode(chosen.toList()..sort()));
  }

  Future<void> _editBuddy() async {
    final v = ref.read(viewProvider);
    final app = ref.read(appProvider.notifier);
    final name = await askText(context, 'Buddy name', hint: 'Someone who will be kind', initial: v.kv[K.buddyName] ?? '');
    if (name == null || !mounted) return;
    final phone = await askText(context, 'Buddy phone number',
        hint: '+91 98765 43210', initial: v.kv[K.buddyPhone] ?? '', keyboard: TextInputType.phone);
    if (phone == null) return;
    await app.setSetting(K.buddyName, name.trim());
    await app.setSetting(K.buddyPhone, phone.replaceAll(RegExp(r'[^0-9+]'), ''));
  }

  Future<void> _sendReport() async {
    final app = ref.read(appProvider.notifier);
    if (await app.sendBuddySms()) {
      if (mounted) toast(context, 'Report sent by SMS.');
    } else {
      await ref.read(shareProvider)(text: ref.read(viewProvider).buddyText);
      await app.log(Ev.buddyReport, {'channel': 'share'});
    }
  }

  Future<void> _export() async {
    final json = ref.read(appProvider.notifier).exportJson();
    final file = File(p.join((await getTemporaryDirectory()).path, 'challenger-timer-export.json'));
    await file.writeAsString(json);
    await ref.read(shareProvider)(filePath: file.path);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    Widget perm(String key, String label, String why) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(status[key] == true ? Icons.check_circle : Icons.radio_button_unchecked,
            color: status[key] == true ? cyan : dim),
        title: Text(label),
        subtitle: Text(why, style: const TextStyle(color: dim, fontSize: 12)),
        trailing: status[key] == true
            ? null
            : TextButton(
                onPressed: () async {
                  await askPermission(context, ref, key, label, why);
                  await _refresh();
                },
                child: const Text('ALLOW')));
    return Scaffold(
        appBar: AppBar(title: const Text('SETTINGS')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
          const H('You'),
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Name'),
              subtitle: Text(v.name.isEmpty ? 'Not set' : v.name),
              onTap: () async {
                final n = await askText(context, 'Your name', initial: v.name);
                if (n != null) await app.setSetting(K.name, n.trim());
              }),
          ListTile(
              key: const Key('dayEnd'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Day ends at'),
              subtitle: Text('${hhmm(v.dayEndHour * 60)}. Work before this still counts for the day before.'),
              onTap: () async {
                final h = await showDialog<int>(
                    context: context,
                    builder: (ctx) => SimpleDialog(backgroundColor: panel, title: const Text('Day ends at'), children: [
                          for (final h in [0, 1, 2, 3, 4, 5, 6])
                            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, h), child: Text(hhmm(h * 60))),
                        ]));
                if (h != null) await app.setSetting(K.dayEndHour, '$h');
              }),
          ListTile(
              key: const Key('cueTime'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Cue time'),
              subtitle: Text('${hhmm(v.cueMinute)}. The daily alarm for the first task.'),
              onTap: () async {
                final t = await showTimePicker(
                    context: context, initialTime: TimeOfDay(hour: v.cueMinute ~/ 60, minute: v.cueMinute % 60));
                if (t != null) await app.setSetting(K.cueMinute, '${t.hour * 60 + t.minute}');
              }),
          const SizedBox(height: 16),
          const H('Force stack'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Switching one ON is instant. Switching one OFF takes 24 hours, and you can cancel during the wait. You stay in charge, just not at your weakest moment.',
                  style: TextStyle(color: dim, fontSize: 12))),
          for (final key in _switchInfo.keys) _lockSwitch(key, v, app),
          const SizedBox(height: 16),
          const H('Blocked apps'),
          ListTile(
              key: const Key('blockedApps'),
              contentPadding: EdgeInsets.zero,
              title: Text(v.blockedApps.isEmpty ? 'None chosen' : '${v.blockedApps.length} apps chosen'),
              subtitle: const Text('Blocked each day until the first session is finished.', style: TextStyle(color: dim)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickApps),
          const SizedBox(height: 16),
          const H('Buddy'),
          ListTile(
              key: const Key('buddy'),
              contentPadding: EdgeInsets.zero,
              title: Text((v.kv[K.buddyPhone] ?? '').isEmpty ? 'Add a buddy contact' : '${v.kv[K.buddyName]} · ${v.kv[K.buddyPhone]}'),
              subtitle: const Text('One real person who gets your result at 8 pm.', style: TextStyle(color: dim)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editBuddy),
          if ((v.kv[K.buddyPhone] ?? '').isNotEmpty)
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(key: const Key('sendReport'), onPressed: _sendReport, child: const Text("SEND TODAY'S REPORT NOW"))),
          const SizedBox(height: 16),
          const H('Permissions'),
          perm('notifications', 'Notifications', 'Timer, alarms and the rescue alert are notifications.'),
          perm('exactAlarm', 'Exact alarms', 'So the cue alarm rings on the minute, not whenever Android feels like it.'),
          perm('fullScreen', 'Full-screen alarms', 'Lets the alarm cover the lock screen.'),
          perm('usage', 'Usage access', 'Needed only for Earn your phone, to see which app is open.'),
          perm('overlay', 'Display over other apps', 'Needed only for Earn your phone, to draw the block screen.'),
          perm('sms', 'Send SMS', 'Needed only for the automatic buddy report.'),
          perm('battery', 'Ignore battery optimisation', 'Stops Android from delaying alarms and the blocker while the phone sleeps.'),
          const SizedBox(height: 16),
          const H('Your data'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Everything is stored on this phone only.', style: TextStyle(color: dim, fontSize: 12))),
          Row(children: [
            Expanded(child: OutlinedButton(key: const Key('export'), onPressed: _export, child: const Text('EXPORT JSON'))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton(
                    key: const Key('wipe'),
                    style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold, width: 2)),
                    onPressed: () async {
                      final t = await askText(context, 'Delete everything?',
                          hint: 'Type DELETE', ok: 'DELETE');
                      if (t?.trim().toUpperCase() != 'DELETE') return;
                      await app.wipe();
                      if (context.mounted) context.go('/welcome');
                    },
                    child: const Text('DELETE ALL'))),
          ]),
        ]));
  }

  Widget _lockSwitch(String key, DayView v, App app) {
    final (title, why) = _switchInfo[key]!;
    final s = v.sw(key);
    final on = s.effective(v.now.ms);
    final pending = s.pendingOff(v.now.ms);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
            key: Key('sw-$key'),
            border: pending ? gold : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                H(pending ? 'Turning off' : on ? 'On' : 'Off', color: pending ? gold : on ? cyan : dim),
              ]),
              const SizedBox(height: 4),
              Text(why, style: const TextStyle(color: dim, fontSize: 12)),
              const SizedBox(height: 8),
              if (pending)
                Row(children: [
                  Expanded(child: Text('Off in ${countdown(s.msUntilOff(v.now.ms))}. Still active until then.', style: const TextStyle(color: gold))),
                  TextButton(key: Key('cancel-$key'), onPressed: () => app.switchCancelOff(key), child: const Text('KEEP IT ON')),
                ])
              else if (on)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        key: Key('off-$key'),
                        onPressed: () async {
                          if (await confirm(context, 'Turn off $title?',
                              'It keeps working for 24 more hours, then switches off. You can cancel any time before that.',
                              ok: 'START 24H COUNTDOWN', cancel: 'KEEP IT ON')) {
                            await app.switchRequestOff(key);
                          }
                        },
                        child: const Text('TURN OFF (TAKES 24H)')))
              else
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(key: Key('on-$key'), onPressed: () => _turnOn(key), child: const Text('TURN ON'))),
            ])));
  }
}

// ---- ONBOARDING (three questions, then straight into two minutes) --------
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeState();
}

class _WelcomeState extends ConsumerState<WelcomeScreen> {
  int step = 0;
  final name = TextEditingController();
  final habit = TextEditingController();
  int cue = 9 * 60;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    habit.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (busy) return;
    setState(() => busy = true);
    final app = ref.read(appProvider.notifier);
    await app.setKv(K.name, name.text.trim());
    await app.setKv(K.cueMinute, '$cue');
    final h = habit.text.trim().isEmpty ? 'Open the book' : habit.text.trim();
    await app.addRec(Kind.habit, {'name': h});
    await app.log(Ev.onboarded, {'cueMinute': cue});
    if (mounted) {
      await askPermission(context, ref, 'notifications', 'One permission',
          'Notifications keep the timer alive when the app is closed and let the daily alarm ring. That is the only thing asked right now.');
    }
    await app.startSession(minutes: 2, source: 'onboarding', title: h);
    if (mounted) context.go('/timer');
  }

  @override
  Widget build(BuildContext context) {
    final pages = <(String, String, Widget)>[
      ('What should we call you?', 'First name is plenty.',
          TextField(key: const Key('obName'), controller: name, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your name'))),
      ('One tiny habit', 'Small enough to do on your worst day. You can add more later.',
          TextField(key: const Key('obHabit'), controller: habit, decoration: const InputDecoration(hintText: 'Open the book'))),
      ('When should the alarm ring?', 'Pick the time you will start each day. A full-screen alarm shows your first task.',
          Center(
              child: TextButton(
                  key: const Key('obCue'),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cue ~/ 60, minute: cue % 60));
                    if (t != null) setState(() => cue = t.hour * 60 + t.minute);
                  },
                  child: Big(hhmm(cue), size: 72, color: cyan)))),
    ];
    final (title, sub, body) = pages[step];
    final last = step == pages.length - 1;
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Poster(PosterArt.door, size: 64),
                    const SizedBox(width: 12),
                    Expanded(child: H('Productivity\nChallenger Timer', color: Colors.white, size: 18)),
                  ]),
                  const SizedBox(height: 8),
                  Bar((step + 1) / pages.length, height: 4),
                  const Spacer(),
                  Text(title.toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(sub, style: const TextStyle(color: dim, fontSize: 16)),
                  const SizedBox(height: 20),
                  body,
                  const Spacer(flex: 2),
                  FilledButton(
                      key: const Key('obNext'),
                      onPressed: busy ? null : () => last ? _finish() : setState(() => step++),
                      child: Text(last ? 'START MY FIRST 2 MINUTES' : 'NEXT')),
                  if (step == 0)
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('No account. Nothing leaves this phone.', textAlign: TextAlign.center, style: TextStyle(color: dim))),
                ]))));
  }
}
