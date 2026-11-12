import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/state.dart';
import '../core/events.dart';
import 'home.dart';
import 'settings.dart';
import 'special.dart';
import 'tabs.dart';
import 'theme.dart';
import 'timer.dart';
import 'toolbox.dart';

const _tabs = [
  ('/', 'HOME', Icons.play_circle_fill),
  ('/timer', 'TIMER', Icons.timer),
  ('/streaks', 'STREAKS', Icons.local_fire_department),
  ('/vault', 'VAULT', Icons.inventory_2),
  ('/plan', 'PLAN', Icons.event_note),
  ('/me', 'ME', Icons.person),
];

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final onboarded = ref.read(viewProvider).onboarded;
        if (!onboarded && state.matchedLocation != '/welcome') return '/welcome';
        if (onboarded && state.matchedLocation == '/welcome') return '/';
        return null;
      },
      routes: [
        ShellRoute(
            builder: (context, state, child) {
              final i = _tabs.indexWhere((t) => t.$1 == state.matchedLocation);
              return Scaffold(
                  body: child,
                  bottomNavigationBar: NavigationBar(
                      selectedIndex: i < 0 ? 0 : i,
                      onDestinationSelected: (n) => context.go(_tabs[n].$1),
                      destinations: [
                        for (final t in _tabs)
                          NavigationDestination(key: Key('tab-${t.$2}'), icon: Icon(t.$3), label: t.$2),
                      ]));
            },
            routes: [
              GoRoute(path: '/', pageBuilder: (c, s) => const NoTransitionPage(child: HomeScreen())),
              GoRoute(path: '/timer', pageBuilder: (c, s) => const NoTransitionPage(child: TimerScreen())),
              GoRoute(path: '/streaks', pageBuilder: (c, s) => const NoTransitionPage(child: StreaksScreen())),
              GoRoute(path: '/vault', pageBuilder: (c, s) => const NoTransitionPage(child: VaultScreen())),
              GoRoute(path: '/plan', pageBuilder: (c, s) => const NoTransitionPage(child: PlanScreen())),
              GoRoute(path: '/me', pageBuilder: (c, s) => const NoTransitionPage(child: MeScreen())),
            ]),
        GoRoute(path: '/proof', builder: (c, s) => const ProofScreen()),
        GoRoute(path: '/receipt', builder: (c, s) => const ReceiptScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
        GoRoute(path: '/ritual', builder: (c, s) => const RitualScreen()),
        GoRoute(path: '/habit/:id', builder: (c, s) => HabitScreen(s.pathParameters['id']!)),
        GoRoute(path: '/task/:id', builder: (c, s) => TaskScreen(s.pathParameters['id']!)),
        GoRoute(path: '/toolbox', builder: (c, s) => const ToolboxScreen()),
        GoRoute(path: '/features', builder: (c, s) => const FeaturesScreen()),
        GoRoute(path: '/tool/:n', builder: (c, s) => ToolScreen(int.parse(s.pathParameters['n']!))),
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
