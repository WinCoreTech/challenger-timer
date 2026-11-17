import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/settings.dart';
import '../theme.dart';

/// One settings row: key, label, kind and choices as (stored value, label).
class _Row {
  const _Row(this.key, this.label, {this.choices = const [], this.note = '', this.slider = false});
  final String key, label, note;
  final List<(String, String)> choices; // empty = on/off switch
  final bool slider;
}

List<(String, String)> _mins(List<int> xs) => [for (final x in xs) ('$x', '$x min')];
const _onOff = <(String, String)>[];

final _rows = <Object>[
  'Timer',
  _Row(S.workMin, 'Work session', choices: _mins([10, 15, 20, 25, 30, 45, 50, 60, 90])),
  _Row(S.shortBreakMin, 'Short break', choices: _mins([3, 5, 10, 15])),
  _Row(S.longBreakMin, 'Long break', choices: _mins([5, 10, 15, 30])),
  _Row(S.longBreakEvery, 'Long break after every', choices: [for (var i = 2; i <= 8; i++) ('$i', '$i sessions')],
      note: 'The count starts again after 3 hours with no finished session.'),
  const _Row(S.overtimeStep, 'Overtime step', choices: [('0', 'Off'), ('1', '1 min'), ('5', '5 min'), ('10', '10 min')]),
  const _Row(S.robustCountdown, 'Robust countdown timer', choices: _onOff, note: 'Ends sessions with an alarm-clock alarm. Use it if countdowns finish late on your phone.'),
  const _Row('floatingTimer', 'Floating timer', choices: _onOff, note: 'A small countdown over other apps while a session runs. Needs "Display over other apps", asked for under Locks and permissions.'),
  _Row('dailyTargetMinutes', 'Daily target', choices: _mins([25, 50, 75, 100, 150, 200, 300])),
  const _Row(S.stayAway, 'Stay-away mode', choices: _onOff, note: 'A full-screen pulsing timer while you work.'),
  const _Row(S.focusMode, 'Focus mode', choices: [('normal', 'Normal'), ('hyper', 'Hyper'), ('beast', 'Beast')]),
  _Row(S.dailyLimitHours, 'Daily limit', choices: [for (var i = 2; i <= 12; i++) ('$i', '$i hours')], note: 'Above this for 3 days in a row, the app eases its pressure.'),
  'Sound',
  const _Row(S.almostSound, 'Almost-complete sound', choices: _onOff),
  const _Row(S.notificationSound, 'Notification sound', choices: [('default', 'App default'), ('none', 'None')]),
  const _Row(S.soundChannel, 'Sound channel', choices: [('media', 'Media'), ('notification', 'Notification'), ('alarm', 'Alarm')]),
  const _Row(S.completeVolume, 'Complete volume', slider: true),
  const _Row(S.tickingVolume, 'Ticking volume', slider: true),
  const _Row(S.otherVolume, 'Other sounds volume', slider: true, note: 'Volumes are relative to the phone\'s own volume.'),
  'Screen',
  const _Row(S.keepScreenOn, 'Keep screen on', choices: _onOff),
  const _Row(S.screenDuringCountdown, 'Screen during countdowns', choices: [('device', 'Device default'), ('dim', 'Dim'), ('on', 'Full')]),
  const _Row(S.screenOnComplete, 'Turn on screen on complete', choices: _onOff),
  const _Row(S.theme, 'Theme', choices: [('dark', 'Dark'), ('light', 'Light'), ('system', 'System')], note: 'Light and system themes arrive with the design pass. Dark is used for now.'),
  const _Row('textPct', 'Text size', choices: [('100', '100%'), ('115', '115%'), ('130', '130%'), ('150', '150%'), ('200', '200%')]),
  const _Row(S.language, 'Language', choices: [('device', 'Device default'), ('en', 'English')]),
  'Behaviour',
  const _Row(S.weekStartsOn, 'Week starts on',
      choices: [('1', 'Monday'), ('2', 'Tuesday'), ('3', 'Wednesday'), ('4', 'Thursday'), ('5', 'Friday'), ('6', 'Saturday'), ('7', 'Sunday')]),
  const _Row(S.sortProjectsBy, 'Sort projects by', choices: [('activity', 'Last activity'), ('name', 'Name'), ('time', 'Time worked')]),
  const _Row(S.enableNotes, 'Enable notes', choices: _onOff),
  const _Row(S.casualMode, 'Casual mode', choices: _onOff, note: 'No nagging, and no rank or achievement notifications.'),
  _Row(S.remindersPerDay, 'Reminders per day at most', choices: [for (var i = 0; i <= 5; i++) ('$i', '$i')]),
];

/// Reference 5.11: every setting with its default.
class SettingsV2Screen extends ConsumerWidget {
  const SettingsV2Screen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(viewProvider);
    final app = ref.read(appProvider.notifier);
    String cur(String key) => switch (key) {
          'textPct' => v.kv[key] ?? '100',
          'floatingTimer' => v.kv[key] ?? '0',
          'dailyTargetMinutes' => v.kv[key] ?? '50',
          _ => v.pref(key),
        };
    Widget build(_Row r) {
      final note = r.note.isEmpty ? null : Text('Note: ${r.note}', style: const TextStyle(color: gold, fontSize: 12));
      if (r.slider) {
        final val = (int.tryParse(cur(r.key)) ?? 0).clamp(0, 100).toDouble();
        return ListTile(
            title: Text('${r.label}: ${val == 0 ? 'off' : '${val.round()}%'}'),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Slider(key: Key('set-${r.key}'), value: val, max: 100, divisions: 10, label: '${val.round()}', onChanged: (x) => app.setSetting(r.key, '${x.round()}')),
              ?note,
            ]));
      }
      if (r.choices.isEmpty) {
        return SwitchListTile(key: Key('set-${r.key}'), title: Text(r.label), subtitle: note, value: cur(r.key) == '1', onChanged: (x) => app.setSetting(r.key, x ? '1' : '0'));
      }
      final has = r.choices.any((c) => c.$1 == cur(r.key));
      return ListTile(
          title: Text(r.label),
          subtitle: note,
          trailing: SizedBox(
              width: 150,
              child: DropdownButton<String>(
              key: Key('set-${r.key}'),
              isExpanded: true,
              value: cur(r.key),
              dropdownColor: panel,
              items: [
                if (!has) DropdownMenuItem(value: cur(r.key), child: Text(cur(r.key))),
                for (final (val, label) in r.choices) DropdownMenuItem(value: val, child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (x) => x == null ? null : app.setSetting(r.key, x))));
    }

    return Scaffold(
        appBar: AppBar(title: const Text('SETTINGS')),
        body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          for (final r in _rows)
            if (r is String) Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: H(r, color: accent)) else build(r as _Row),
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 4), child: H('More', color: accent)),
          ListTile(key: const Key('set-locks'), title: const Text('Locks, permissions and buddy'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/settings')),
          ListTile(
              key: const Key('set-goal'),
              title: const Text('Long-term goal'),
              subtitle: Text((v.kv['goalText'] ?? '').isEmpty ? 'Not set' : '${v.kv['goalText']} · ${v.kv['goalHours']} hours'),
              onTap: () async {
                final text = await askText(context, 'Long-term goal', initial: v.kv['goalText'] ?? '', hint: 'Crack placements');
                if (text == null || !context.mounted) return;
                final hours = await askText(context, 'Hours it will take', initial: v.kv['goalHours'] ?? '', hint: '500', keyboard: TextInputType.number);
                await app.setSetting('goalText', text.trim());
                await app.setSetting('goalHours', '${int.tryParse(hours ?? '') ?? 0}');
              }),
          ListTile(key: const Key('set-me'), title: const Text('XP, levels and buddy'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/me')),
          ListTile(key: const Key('set-toolbox'), title: const Text('Toolbox'), subtitle: const Text('Optional extras'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/toolbox')),
          Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                  key: const Key('set-resetPrivacy'),
                  onPressed: () async {
                    if (!await confirm(context, 'Reset privacy settings?', 'Hidden warnings come back and the app forgets which permissions it saw. Nothing you logged is touched.', ok: 'RESET')) return;
                    await app.setSetting(S.hideLateWarning, '0');
                    for (final k in v.kv.keys.where((k) => k.startsWith('perm.')).toList()) {
                      await app.setKv(k, null);
                    }
                    if (context.mounted) toast(context, 'Privacy settings reset.');
                  },
                  child: const Text('RESET PRIVACY SETTINGS'))),
        ]));
  }
}
