import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_brain/core/services/procedural_audio_synth.dart';
import 'package:split_brain/main.dart';
import 'package:split_brain/ui/screens/game_viewport_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  ProceduralAudioSynth.instance.soundEnabled = false;

  testWidgets('SplitBrainApp mounts GameViewportScreen successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SplitBrainApp(),
      ),
    );

    expect(find.byType(GameViewportScreen), findsOneWidget);
    expect(find.text('SPLIT REFLEX'), findsOneWidget);
  });
}
