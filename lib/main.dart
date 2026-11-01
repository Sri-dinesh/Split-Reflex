import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/game_viewport_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1.1: Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Step 1.1: Immersive sticky edge-to-edge mode for competitive dual-thumb gameplay
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(
    const ProviderScope(
      child: SplitBrainApp(),
    ),
  );
}

class SplitBrainApp extends StatelessWidget {
  const SplitBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Split Reflex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
      ),
      home: const GameViewportScreen(),
    );
  }
}
