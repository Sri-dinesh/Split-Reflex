import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../widgets/split_diamond_emblem.dart';

class CinematicSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CinematicSplashScreen({super.key, required this.onComplete});

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _titleOpacityAnimation;
  late Animation<double> _taglineOpacityAnimation;
  late Animation<double> _exitFadeAnimation;

  Timer? _midTimer;
  Timer? _endTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Initial spring-pop entry
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
    ]).animate(_animController);

    // Gentle kinetic calibration rotation
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -math.pi * 0.25, end: 0.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: 50,
      ),
    ]).animate(_animController);

    // Breathing glow bloom
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_animController);

    // Title reveal (fade & slide up)
    _titleOpacityAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.40, 0.75, curve: Curves.easeOut),
    );

    // Tagline reveal
    _taglineOpacityAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
    );

    // Smooth exit transition
    _exitFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.88, 1.0, curve: Curves.easeInOut),
    );

    // Trigger haptic and sound sync
    _runSplashSequence();
  }

  void _cancelTimers() {
    _midTimer?.cancel();
    _midTimer = null;
    _endTimer?.cancel();
    _endTimer = null;
  }

  void _runSplashSequence() {
    // Subtle start tick
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();

    _animController.forward();

    // Singularity burst haptic at midpoint
    _midTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        ProceduralAudioSynth.instance.playSwapTick(isFinal: false);
        HapticChoreographer.instance.triggerNearMiss();
      }
    });

    // Sequence completion
    _endTimer = Timer(const Duration(milliseconds: 2200), () {
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
        // Allow tap to skip splash immediately
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
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Kinetic Emblem
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Radial Energy Rings
                            Container(
                              width: 140.0 * _glowAnimation.value,
                              height: 140.0 * _glowAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    SplitPalette.nearMissCyan.withOpacity(0.25 * _glowAnimation.value),
                                    SplitPalette.hazardCrimson.withOpacity(0.15 * _glowAnimation.value),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),

                            // Authentic Split Diamond
                            const SplitDiamondEmblem(size: 96.0),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32.0),

                    // Title with Opacity and Letter Spacing
                    Opacity(
                      opacity: _titleOpacityAnimation.value,
                      child: const Text(
                        'SPLIT REFLEX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // Tagline
                    Opacity(
                      opacity: _taglineOpacityAnimation.value,
                      child: const Text(
                        'Dual-Hemisphere Reflex Engine',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
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
