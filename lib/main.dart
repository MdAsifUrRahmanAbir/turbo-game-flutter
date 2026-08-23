import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/persistence/game_progress_store.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/game_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TurboArcadeApp(),
    ),
  );
}

class TurboArcadeApp extends StatelessWidget {
  const TurboArcadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayBits',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const GameHubScreen(),
    );
  }
}
