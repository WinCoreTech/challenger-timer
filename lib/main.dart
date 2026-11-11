import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/native.dart';
import 'app/state.dart';
import 'core/flags.dart';
import 'core/rules.dart';
import 'core/tools.dart';
import 'data/drift_store.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(overrides: [
    storeProvider.overrideWithValue(await DriftStore.open()),
    nativeProvider.overrideWithValue(ChannelNative()),
    ranksProvider.overrideWithValue(parseRanks(await rootBundle.loadString('assets/ranks.json'))),
    catalogProvider.overrideWithValue(Catalog.parse(await rootBundle.loadString('assets/features.json'))),
    toolsProvider.overrideWithValue(parseTools(await rootBundle.loadString('assets/tools.json'))),
    achievementsProvider
        .overrideWithValue(parseAchievements(await rootBundle.loadString('assets/achievements.json'))),
  ]);
  await container.read(appProvider.notifier).load();
  runApp(UncontrolledProviderScope(container: container, child: const ChallengerApp()));
}
