import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/preferences_service.dart';
import 'ui/screens/game_viewport_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never let an unexpected exception take the whole process down without a
  // trace. Release builds log a single line; debug builds keep the full
  // Flutter error presentation.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
        debugPrint('Uncaught async error: $error');
        return true;
      };

  // Restore sound/haptics/gameplay preferences before the first frame so the
  // menu never renders with the wrong settings.
  await PreferencesService.instance.load();

  // Portrait-first competitive dual-thumb layout. Large screens that ignore
  // this request still get a playable, scroll-safe landscape layout.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // Immersive sticky keeps the play area edge-to-edge while still allowing the
  // system swipe gesture to reveal the bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // A readable fallback instead of the red "RenderFlex" screen in release.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      return const _FatalErrorFallback();
    }
    return ErrorWidget(details.exception);
  };

  runApp(const ProviderScope(child: SplitBrainApp()));
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
        splashFactory: InkRipple.splashFactory,
      ),
      // The gameplay HUD is laid out against a fixed pixel budget; clamping the
      // OS font scale keeps large accessibility text from clipping while still
      // honouring a 140% preference.
      builder: (BuildContext context, Widget? child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.4,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const GameViewportScreen(),
    );
  }
}

class _FatalErrorFallback extends StatelessWidget {
  const _FatalErrorFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Split Reflex hit an unexpected error.\nPlease reopen the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
