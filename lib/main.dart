import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/game_hub_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TurboArcadeApp()));
}

class TurboArcadeApp extends StatelessWidget {
  const TurboArcadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turbo Arcade',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const GameHubScreen(),
    );
  }
}
