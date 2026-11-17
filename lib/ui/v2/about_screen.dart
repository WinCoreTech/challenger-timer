import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

/// Mirrors `version` in pubspec.yaml.
const appVersion = '0.2.0';

const whatsNew = [
  'Dashboard home with tiles and a rank bar.',
  'Work screen with project, today, 7-day average and rank.',
  'Rank ladder that follows recent work, with promotion and demotion.',
  'Nested projects with their own session lengths.',
  'Stats by period, with consistency first.',
  'Weekly schedule blocks with reminders.',
  'Versioned backup, redacted backup and load.',
  'Battery warning when a countdown finishes late.',
];

const permissions = [
  ('Notifications', 'The running timer, alarms and reminders are notifications.'),
  ('Exact alarms', 'So sessions and alarms end on the minute.'),
  ('Full-screen alarms', 'Lets the start alarm cover the lock screen.'),
  ('Foreground service', 'Keeps a session alive when the app is closed.'),
  ('Run at startup', 'Restores alarms and a running timer after a restart.'),
  ('Usage access', 'Only for app blocking and screen-time read-outs.'),
  ('Display over other apps', 'Only for the block screen.'),
  ('Send SMS', 'Only for the optional buddy report.'),
  ('Microphone', 'Only while you record a voice note.'),
  ('Do Not Disturb access', 'Only if you ask for silence during sessions.'),
  ('Ignore battery optimisation', 'Stops the phone delaying countdowns.'),
  ('Camera', 'Photo proof, through the system camera.'),
];

/// Reference 5.13.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Productivity Challenger Timer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const Text('Version $appVersion', key: Key('aboutVersion'), style: TextStyle(color: dim)),
        const SizedBox(height: 16),
        const Text('A timer that keeps score. You press start, it counts, and your rank follows what you actually did this week. '
            'It is strict about numbers and never rude about you.'),
        const SizedBox(height: 12),
        const Panel(
            child: Text('Straight talk: this is not an organiser and it will not plan your life. Your rank drops if work stops, except on rest, sick and exam days. '
                'There is no account and nothing leaves this phone. It has not been tested on every phone, so tell the developer when something misbehaves.')),
        const SizedBox(height: 20),
        const H('What\'s new', color: cyan),
        for (final w in whatsNew) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $w')),
        const SizedBox(height: 20),
        const H('Permissions and why', color: cyan),
        for (final (name, why) in permissions)
          ListTile(key: Key('perm-$name'), contentPadding: EdgeInsets.zero, dense: true, title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(why, style: const TextStyle(color: dim))),
        const Text('Each one is asked for only when you switch on the feature that needs it.', style: TextStyle(color: dim, fontSize: 12)),
      ]));
}
