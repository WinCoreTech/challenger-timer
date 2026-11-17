import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/events.dart';
import 'settings.dart';
import 'special.dart';
import 'tabs.dart';
import 'theme.dart';
import 'timer.dart';
import 'toolbox.dart';
import 'v2/about_screen.dart';
import 'v2/achievements_screen.dart';
import 'v2/backup_screen.dart';
import 'v2/dashboard.dart';
import 'v2/project_edit.dart';
import 'v2/projects_screen.dart';
import 'v2/ranks_screen.dart';
import 'v2/schedule_screen.dart';
import 'v2/settings_v2.dart';
import 'v2/stats_screen.dart';
import 'v2/work_screen.dart';

/// Plan v2: the dashboard is home and every other screen sits on top of it,
/// so the system back button always returns to the dashboard.
final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final onboarded = ref.read(viewProvider).onboarded;
        if (!onboarded && state.matchedLocation != '/welcome') return '/welcome';
        if (onboarded && state.matchedLocation == '/welcome') return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (c, s) => const DashboardScreen(), routes: [
          GoRoute(path: 'work', builder: (c, s) => const WorkScreen()),
          GoRoute(path: 'projects', builder: (c, s) => const ProjectsScreen()),
          GoRoute(path: 'project/:id', builder: (c, s) => ProjectEditScreen(s.pathParameters['id']!)),
          GoRoute(path: 'achievements', builder: (c, s) => const AchievementsScreen()),
          GoRoute(path: 'stats', builder: (c, s) => const StatsScreen()),
          GoRoute(path: 'schedule', builder: (c, s) => const ScheduleScreen()),
          GoRoute(path: 'prefs', builder: (c, s) => const SettingsV2Screen()),
          GoRoute(path: 'backup', builder: (c, s) => const BackupScreen()),
          GoRoute(path: 'about', builder: (c, s) => const AboutScreen()),
          GoRoute(path: 'ranks', builder: (c, s) => const RanksScreen()),
          GoRoute(path: 'timer', builder: (c, s) => const TimerScreen()),
          GoRoute(path: 'streaks', builder: (c, s) => const StreaksScreen()),
          GoRoute(path: 'vault', builder: (c, s) => const VaultScreen()),
          GoRoute(path: 'plan', builder: (c, s) => const PlanScreen()),
          GoRoute(path: 'me', builder: (c, s) => const MeScreen()),
          GoRoute(path: 'proof', builder: (c, s) => const ProofScreen()),
          GoRoute(path: 'receipt', builder: (c, s) => const ReceiptScreen()),
          GoRoute(path: 'settings', builder: (c, s) => const SettingsScreen()),
          GoRoute(path: 'ritual', builder: (c, s) => const RitualScreen()),
          GoRoute(path: 'habit/:id', builder: (c, s) => HabitScreen(s.pathParameters['id']!)),
          GoRoute(path: 'task/:id', builder: (c, s) => TaskScreen(s.pathParameters['id']!)),
          GoRoute(path: 'toolbox', builder: (c, s) => const ToolboxScreen()),
          GoRoute(path: 'features', builder: (c, s) => const FeaturesScreen()),
          GoRoute(path: 'tool/:n', builder: (c, s) => ToolScreen(int.parse(s.pathParameters['n']!))),
        ]),
        GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
      ],
    ));

class ChallengerApp extends ConsumerStatefulWidget {
  const ChallengerApp({super.key});
  @override
  ConsumerState<ChallengerApp> createState() => _AppState();
}

class _AppState extends ConsumerState<ChallengerApp> with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(nativeProvider).onAction = _wake;
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _wake());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(appProvider.notifier).log(Ev.appOpen);
      await _wake();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int? _leftAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final clock = ref.read(clockProvider);
    if (state == AppLifecycleState.paused) _leftAt = clock().ms;
    if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null) {
        final native = ref.read(nativeProvider);
        await ref.read(appProvider.notifier)
            .hardModeCheck(clock().ms - left, leftWithScreenOn: await native.leftWithScreenOn());
      }
      await _wake();
    }
  }

  /// Runs on open, on resume, on native actions and every few seconds:
  /// closes a session that ended while we were away, then handles any
  /// "Start 2 min" tap that came from outside the app.
  Future<void> _wake() async {
    if (!mounted) return;
    final app = ref.read(appProvider.notifier);
    final router = ref.read(routerProvider);
    await app.permissionGuard();
    await app.noteLateFinish();
    final finished = await app.completeIfDue();
    final action = await app.handleLaunchAction();
    if (!mounted) return;
    ref.read(tickProvider.notifier).bump();
    if (action == 'start2' || finished) router.go('/timer');
    if (action == 'report') {
      await ref.read(shareProvider)(text: ref.read(viewProvider).buddyText);
      await app.log(Ev.buddyReport, {'channel': 'share'});
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
      title: 'Challenger Timer',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      builder: (context, child) {
        // Feature 495: text size on top of the phone's own font scale.
        final pct = ref.watch(viewProvider).settingInt('textPct', 100).clamp(80, 160);
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * pct / 100)), child: child!);
      },
      routerConfig: ref.watch(routerProvider));
}
