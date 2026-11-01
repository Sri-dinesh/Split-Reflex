import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../widgets/split_diamond_emblem.dart';

/// Cinematic procedural animated splash screen.
///
/// Features:
/// - Smooth dual-hemisphere vector wing convergence along the diagonal split rift
/// - Singularity ignition seam with bilateral cyan/crimson radial bloom
/// - Subtle harmonic kinetic breathe and staggered typography reveals
/// - Synchronized procedural synth resonance and tactile haptic feedback
/// - Instant tap-to-skip support
class CinematicSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CinematicSplashScreen({super.key, required this.onComplete});

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _dockAnimation;
  late Animation<double> _seamIgnitionAnimation;
  late Animation<double> _energyBloomAnimation;
  late Animation<double> _kineticBreatheAnimation;
  late Animation<double> _titleOpacityAnimation;
  late Animation<double> _titleSlideAnimation;
  late Animation<double> _taglineOpacityAnimation;
  late Animation<double> _exitFadeAnimation;

  Timer? _lockHapticTimer;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // 1. Dual-Hemisphere Convergence (Glide smoothly into lock)
    _dockAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.48, curve: Curves.easeOutQuart),
    );

    // 2. Singularity Seam Laser Ignition
    _seamIgnitionAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.42, 0.65, curve: Curves.easeInOutCubic),
    );

    // 3. Radial Bilateral Energy Bloom
    _energyBloomAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.38, 0.72, curve: Curves.easeOutCubic),
    );

    // 4. Subtle Harmonic Kinetic Breathe (Scale 1.0 -> 1.035 -> 1.0)
    _kineticBreatheAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.035).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.035, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 45,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.88),
      ),
    );

    // 5. Staggered Title Reveal
    _titleOpacityAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.48, 0.78, curve: Curves.easeOutCubic),
    );
    _titleSlideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.48, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    // 6. Tagline Reveal
    _taglineOpacityAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.64, 0.88, curve: Curves.easeOutCubic),
    );

    // 7. Smooth Horizon Exit Crossfade
    _exitFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.88, 1.0, curve: Curves.easeInOutCubic),
    );

    _startCinematicSequence();
  }

  void _cancelTimers() {
    _lockHapticTimer?.cancel();
    _lockHapticTimer = null;
    _completionTimer?.cancel();
    _completionTimer = null;
  }

  void _startCinematicSequence() {
    // Initial start tick
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();

    _animController.forward();

    // Singularity lock audio & haptics at 45% of sequence (~1080ms)
    _lockHapticTimer = Timer(const Duration(milliseconds: 1080), () {
      if (mounted) {
        ProceduralAudioSynth.instance.playSwapTick(isFinal: false);
        HapticChoreographer.instance.triggerNearMiss();
      }
    });

    // Sequence completion
    _completionTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _cancelTimers();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Immediate skip on player tap
        _cancelTimers();
        widget.onComplete();
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final double exitOpacity = (1.0 - _exitFadeAnimation.value).clamp(0.0, 1.0);

          return Opacity(
            opacity: exitOpacity,
            child: Container(
              color: const Color(0xFF07070A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Kinetic Emblem
                    Transform.scale(
                      scale: _kineticBreatheAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Expanding Ambient Radial Aura behind emblem
                          Container(
                            width: 160.0 * (0.6 + 0.4 * _energyBloomAnimation.value),
                            height: 160.0 * (0.6 + 0.4 * _energyBloomAnimation.value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  SplitPalette.nearMissCyan.withOpacity(0.28 * _energyBloomAnimation.value),
                                  SplitPalette.hazardCrimson.withOpacity(0.18 * _energyBloomAnimation.value),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.48, 1.0],
                              ),
                            ),
                          ),

                          // Detailed Procedural Split Emblem with Animated Convergence
                          SplitDiamondEmblem(
                            size: 104.0,
                            dockProgress: _dockAnimation.value,
                            glowIntensity: _energyBloomAnimation.value,
                            seamIntensity: _seamIgnitionAnimation.value,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36.0),

                    // Staggered Title with Fluid Slide & Fade
                    Transform.translate(
                      offset: Offset(0, _titleSlideAnimation.value),
                      child: Opacity(
                        opacity: _titleOpacityAnimation.value,
                        child: const Text(
                          'SPLIT REFLEX',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // Subtitle / Tagline
                    Opacity(
                      opacity: _taglineOpacityAnimation.value,
                      child: const Text(
                        'Dual-Hemisphere Reflex Engine',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
