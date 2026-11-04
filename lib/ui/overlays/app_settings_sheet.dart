import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/leaderboard_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../../engine/game_controller.dart';

const String _kWebsiteUrl = 'https://splitreflex.vercel.app/';
const String _kTermsUrl = 'https://splitreflex.vercel.app/terms';
const String _kPrivacyUrl = 'https://splitreflex.vercel.app/privacy';

class AppSettingsSheet extends StatefulWidget {
  final GameController controller;

  const AppSettingsSheet({super.key, required this.controller});

  @override
  State<AppSettingsSheet> createState() => _AppSettingsSheetState();
}

class _AppSettingsSheetState extends State<AppSettingsSheet> {
  String _callsign = 'PILOT';
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final handle = await LeaderboardService.instance.getPlayerHandle();
    final high = await LeaderboardService.instance.getLocalHighScore();
    if (mounted) {
      setState(() {
        _callsign = handle;
        _highScore = high;
      });
    }
  }

  Future<void> _editCallsign() async {
    final textController = TextEditingController(text: _callsign);
    final newCallsign = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141419),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: Colors.white24, width: 1.0),
          ),
          title: const Text(
            'Pilot Callsign',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          content: TextField(
            controller: textController,
            maxLength: 14,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter callsign...',
              hintStyle: const TextStyle(color: Colors.white30),
              counterStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(
                  color: SplitPalette.nearMissCyan,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                textController.text.trim().toUpperCase(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SplitPalette.nearMissCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (newCallsign != null && newCallsign.isNotEmpty) {
      await LeaderboardService.instance.savePlayerHandle(newCallsign);
      setState(() => _callsign = newCallsign);
    }
  }

  Future<void> _confirmClearScores() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: Colors.white24, width: 1.0),
          ),
          title: const Text(
            'Reset Run Records?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'This will permanently clear your local high score and recorded run history.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: SplitPalette.hazardCrimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Reset',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await LeaderboardService.instance.clearLocalScores();
      setState(() => _highScore = 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Run records cleared.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF222228),
          ),
        );
      }
    }
  }

  /// Explains, in plain language, what the app stores and what it does not.
  Future<void> _showPrivacyAndData() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141419),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: Colors.white24, width: 1.0),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: SplitPalette.nearMissCyan,
                size: 20,
              ),
              SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Privacy & Data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Split Reflex works completely offline.\n\n'
              '• It has no internet permission, no ads, no analytics and no '
              'third-party SDKs.\n'
              '• Your callsign, run history, high score and preferences are '
              'stored only on this device.\n'
              '• Nothing is uploaded, sold or shared with anyone.\n'
              '• Leaderboards are local: the Hall of Records only shows runs '
              'recorded on this device.\n'
              '• Sharing a death receipt sends an image through the app you '
              'choose in the Android share sheet; the game itself never '
              'transmits it.\n\n'
              'Use “Erase All Local Data” below to delete everything the app '
              'has stored, or uninstall the app to remove it with the app.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _openExternalUrl(_kPrivacyUrl),
              child: const Text(
                'Full Policy',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openExternalUrl(_kTermsUrl),
              child: const Text(
                'Terms',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: SplitPalette.nearMissCyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExternalUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Gracefully handle if browser is unavailable
    }
  }

  /// Deletes every byte the app has written: scores, callsign and preferences.
  Future<void> _confirmEraseAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: Colors.white24, width: 1.0),
          ),
          title: const Text(
            'Erase All Local Data?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'This permanently deletes your callsign, run history, high score '
            'and every preference on this device. It cannot be undone.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: SplitPalette.hazardCrimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Erase Everything',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await LeaderboardService.instance.clearAllUserData();
    await PreferencesService.instance.clearAll();
    widget.controller.resetToFactoryDefaults();

    if (!mounted) return;
    setState(() {
      _callsign = 'PILOT';
      _highScore = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All local data erased.'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF222228),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Notch
            const SizedBox(height: 12.0),
            Container(
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            const SizedBox(height: 16.0),

            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preferences',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                'Hardware, audio & gameplay configuration',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                      size: 22,
                    ),
                    splashRadius: 20,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14.0),
            const Divider(color: Colors.white10, height: 1.0),

            // Scrollable Settings Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Audio & Tactile Haptics
                    _buildSectionHeader('AUDIO & HAPTICS'),
                    _buildSettingCard(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.graphic_eq_rounded,
                          title: 'Procedural Audio Synth',
                          subtitle: 'Real-time 16-bit PCM waveform synthesis',
                          value: ProceduralAudioSynth.instance.soundEnabled,
                          accentColor: SplitPalette.nearMissCyan,
                          onChanged: (val) {
                            setState(() {
                              PreferencesService.instance
                                  .setSoundEnabled(val)
                                  .ignore();
                              if (val) ProceduralAudioSynth.instance.playTap();
                            });
                          },
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        _buildSwitchTile(
                          icon: Icons.vibration_rounded,
                          title: 'Tactile Haptics',
                          subtitle: 'Multi-tiered kinetic feedback on grazing and impact',
                          value: HapticChoreographer.instance.hapticsEnabled,
                          accentColor: SplitPalette.hazardCrimson,
                          onChanged: (val) {
                            setState(() {
                              PreferencesService.instance
                                  .setHapticsEnabled(val)
                                  .ignore();
                              if (val) {
                                HapticChoreographer.instance.triggerTap();
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20.0),

                    // Section 2: Controls & Steering
                    _buildSectionHeader('STEERING & CONTROLS'),
                    _buildSettingCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.sensors_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10.0),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Input Mode',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'Steering method for Rail Dart and Slalom',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 3.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: controller.isGyroAvailable
                                          ? const Color(0xFF00E676)
                                                .withOpacity(0.12)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(
                                        color: controller.isGyroAvailable
                                            ? const Color(0xFF00E676)
                                            : Colors.white24,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      controller.isGyroAvailable
                                          ? 'GYRO READY'
                                          : 'TOUCH ONLY',
                                      style: TextStyle(
                                        color: controller.isGyroAvailable
                                            ? const Color(0xFF00E676)
                                            : Colors.white54,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildChoiceButton(
                                      icon: Icons.touch_app_rounded,
                                      label: 'Touch Drag',
                                      isSelected:
                                          controller.controlMode ==
                                          ControlMode.touchSwipe,
                                      onTap: () {
                                        controller.setControlMode(
                                          ControlMode.touchSwipe,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: _buildChoiceButton(
                                      icon: Icons.screen_rotation_rounded,
                                      label: 'Gyro Tilt',
                                      isSelected:
                                          controller.controlMode ==
                                          ControlMode.gyroTilt,
                                      onTap: () {
                                        controller.setControlMode(
                                          ControlMode.gyroTilt,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20.0),

                    // Section 3: Gameplay Rules
                    _buildSectionHeader('GAMEPLAY FORMAT'),
                    _buildSettingCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Survival Rules',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                'Single lane crash handling protocol',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 10.0),
                              Builder(
                                builder: (context) {
                                  final bool isPong =
                                      controller.gamePairMode ==
                                      GamePairMode.dimensionBreach;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _buildChoiceButton(
                                          icon: Icons.bolt_rounded,
                                          label: '2-Hands Strict',
                                          sublabel: isPong
                                              ? 'Dual paddles required for Pong'
                                              : 'Dual failure triggers game over',
                                          isSelected:
                                              controller.playMode ==
                                              PlayHandMode.twoHands,
                                          onTap: () {
                                            controller.setPlayMode(
                                              PlayHandMode.twoHands,
                                            );
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: _buildChoiceButton(
                                          icon: isPong
                                              ? Icons.lock_outline_rounded
                                              : Icons.shield_outlined,
                                          label: '1-Hand Survival',
                                          sublabel: isPong
                                              ? 'Disabled in Pong mode'
                                              : 'Surviving side keeps going',
                                          isSelected: !isPong &&
                                              controller.playMode ==
                                              PlayHandMode.oneHand,
                                          isEnabled: !isPong,
                                          onTap: () {
                                            if (!isPong) {
                                              controller.setPlayMode(
                                                PlayHandMode.oneHand,
                                              );
                                              setState(() {});
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14.0),
                              const Divider(color: Colors.white10, height: 1.0),
                              const SizedBox(height: 14.0),
                              const Text(
                                'Player Allocation',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                'Solo mental endurance vs Shared 2-player device co-op',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 10.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildChoiceButton(
                                      icon: Icons.person_rounded,
                                      label: 'Solo (1P)',
                                      sublabel: 'Split-brain challenge',
                                      isSelected:
                                          controller.sessionMode ==
                                          GameSessionMode.solo,
                                      onTap: () {
                                        controller.setSessionMode(
                                          GameSessionMode.solo,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: _buildChoiceButton(
                                      icon: Icons.people_rounded,
                                      label: 'Duo Co-Op (2P)',
                                      sublabel: 'P1 Left vs P2 Right',
                                      isSelected:
                                          controller.sessionMode ==
                                          GameSessionMode.duoCoop,
                                      onTap: () {
                                        controller.setSessionMode(
                                          GameSessionMode.duoCoop,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20.0),

                    // Section 4: Themes
                    _buildSectionHeader('VISUAL THEME'),
                    _buildSettingCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildThemeTile(
                                      theme: CyberTheme.monochrome,
                                      label: 'Monochrome',
                                      color: Colors.white,
                                      isSelected:
                                          controller.theme ==
                                          CyberTheme.monochrome,
                                      onTap: () {
                                        controller.setTheme(
                                          CyberTheme.monochrome,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: _buildThemeTile(
                                      theme: CyberTheme.synthwave,
                                      label: 'Synthwave 84',
                                      color: SplitPalette.synthwavePink,
                                      isSelected:
                                          controller.theme ==
                                          CyberTheme.synthwave,
                                      onTap: () {
                                        controller.setTheme(
                                          CyberTheme.synthwave,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildThemeTile(
                                      theme: CyberTheme.matrix,
                                      label: 'Matrix Terminal',
                                      color: SplitPalette.matrixGreen,
                                      isSelected:
                                          controller.theme == CyberTheme.matrix,
                                      onTap: () {
                                        controller.setTheme(CyberTheme.matrix);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: _buildThemeTile(
                                      theme: CyberTheme.cyberGold,
                                      label: 'Cyber Gold 24K',
                                      color: SplitPalette.goldBright,
                                      isSelected:
                                          controller.theme ==
                                          CyberTheme.cyberGold,
                                      onTap: () {
                                        controller.setTheme(
                                          CyberTheme.cyberGold,
                                        );
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20.0),

                    // Section 5: Pilot & Data Archive
                    _buildSectionHeader('PILOT & TELEMETRY'),
                    _buildSettingCard(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.badge_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          title: const Text(
                            'Callsign',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _callsign,
                            style: const TextStyle(
                              color: SplitPalette.nearMissCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 5.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          onTap: _editCallsign,
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.emoji_events_rounded,
                            color: SplitPalette.godModeGold,
                            size: 20,
                          ),
                          title: const Text(
                            'Personal Best',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '$_highScore pts',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_outline_rounded,
                            color: SplitPalette.hazardCrimson,
                            size: 20,
                          ),
                          title: const Text(
                            'Clear Run Records',
                            style: TextStyle(
                              color: SplitPalette.hazardCrimson,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Erase local score history',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          onTap: _confirmClearScores,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20.0),

                    // Section 6: Legal & Data Privacy
                    _buildSectionHeader('LEGAL & DATA PRIVACY'),
                    _buildSettingCard(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.shield_outlined,
                            color: SplitPalette.nearMissCyan,
                            size: 20,
                          ),
                          title: const Text(
                            'Privacy & Data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Offline-only architecture. Zero telemetry tracking.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onTap: _showPrivacyAndData,
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.policy_outlined,
                            color: SplitPalette.nearMissCyan,
                            size: 20,
                          ),
                          title: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'splitreflex.vercel.app/privacy',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onTap: () => _openExternalUrl(_kPrivacyUrl),
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.gavel_rounded,
                            color: SplitPalette.nearMissCyan,
                            size: 20,
                          ),
                          title: const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'splitreflex.vercel.app/terms',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onTap: () => _openExternalUrl(_kTermsUrl),
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.language_rounded,
                            color: SplitPalette.nearMissCyan,
                            size: 20,
                          ),
                          title: const Text(
                            'Official Website',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'splitreflex.vercel.app',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onTap: () => _openExternalUrl(_kWebsiteUrl),
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1.0,
                          indent: 46.0,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            color: SplitPalette.hazardCrimson,
                            size: 20,
                          ),
                          title: const Text(
                            'Erase All Local Data',
                            style: TextStyle(
                              color: SplitPalette.hazardCrimson,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Scores, callsign and every preference',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          onTap: _confirmEraseAllData,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Material(
      color: const Color(0xFF13131A),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color accentColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: accentColor,
            activeTrackColor: accentColor.withOpacity(0.35),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            onChanged: (v) {
              ProceduralAudioSynth.instance.playTap();
              HapticChoreographer.instance.triggerTap();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required IconData icon,
    required String label,
    String? sublabel,
    required bool isSelected,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled
          ? () {
              ProceduralAudioSynth.instance.playTap();
              HapticChoreographer.instance.triggerTap();
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: !isEnabled
              ? Colors.white.withOpacity(0.02)
              : (isSelected
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black26),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: !isEnabled
                ? Colors.white.withOpacity(0.05)
                : (isSelected ? Colors.white : Colors.white12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: !isEnabled
                  ? Colors.white24
                  : (isSelected ? Colors.white : Colors.white54),
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: TextStyle(
                color: !isEnabled
                    ? Colors.white30
                    : (isSelected ? Colors.white : Colors.white60),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 2.0),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: !isEnabled
                      ? Colors.white24
                      : (isSelected ? Colors.white70 : Colors.white24),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required CyberTheme theme,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        ProceduralAudioSynth.instance.playTap();
        HapticChoreographer.instance.triggerTap();
        onTap();
      },
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.black26,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14.0,
              height: 14.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 6.0,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
