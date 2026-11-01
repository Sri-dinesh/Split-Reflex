import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverdriveTier {
  standard,
  overdrive3x,
  godMode10x,
  chargerPenalty,
}

class BatteryTelemetryState {
  final int batteryLevel;
  final BatteryState batteryState;
  final OverdriveTier tier;
  final double scoreMultiplier;
  final bool isSimulated;

  const BatteryTelemetryState({
    required this.batteryLevel,
    required this.batteryState,
    required this.tier,
    required this.scoreMultiplier,
    this.isSimulated = false,
  });

  bool get isOverdrive => tier == OverdriveTier.overdrive3x || tier == OverdriveTier.godMode10x;
  bool get isGodMode => tier == OverdriveTier.godMode10x;
  bool get hasPenalty => tier == OverdriveTier.chargerPenalty;

  BatteryTelemetryState copyWith({
    int? batteryLevel,
    BatteryState? batteryState,
    OverdriveTier? tier,
    double? scoreMultiplier,
    bool? isSimulated,
  }) {
    return BatteryTelemetryState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryState: batteryState ?? this.batteryState,
      tier: tier ?? this.tier,
      scoreMultiplier: scoreMultiplier ?? this.scoreMultiplier,
      isSimulated: isSimulated ?? this.isSimulated,
    );
  }
}

class BatteryTelemetryService extends ChangeNotifier {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _stateSubscription;
  Timer? _periodicTimer;

  BatteryTelemetryState _state = const BatteryTelemetryState(
    batteryLevel: 100,
    batteryState: BatteryState.discharging,
    tier: OverdriveTier.standard,
    scoreMultiplier: 1.0,
  );

  bool _overrideActive = false;
  int _overrideLevel = 100;
  BatteryState _overrideState = BatteryState.discharging;

  BatteryTelemetryState get state => _state;

  BatteryTelemetryService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final level = await _battery.batteryLevel;
      _updateTelemetry(level: level, state: BatteryState.discharging);
    } catch (_) {
      // In web or non-supported emulator environments, fallback gracefully
      _updateTelemetry(level: 100, state: BatteryState.discharging);
    }

    try {
      _stateSubscription = _battery.onBatteryStateChanged.handleError((_) {}).listen((state) async {
        if (!_overrideActive) {
          try {
            final level = await _battery.batteryLevel;
            _updateTelemetry(level: level, state: state);
          } catch (_) {}
        }
      });
    } catch (_) {}

    _periodicTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_overrideActive) {
        try {
          final level = await _battery.batteryLevel;
          _updateTelemetry(level: level, state: _state.batteryState);
        } catch (_) {}
      }
    });
  }

  void _updateTelemetry({required int level, required BatteryState state}) {
    final effectiveLevel = _overrideActive ? _overrideLevel : level;
    final effectiveState = _overrideActive ? _overrideState : state;

    final isCharging = effectiveState == BatteryState.charging || effectiveState == BatteryState.full;

    OverdriveTier tier;
    double multiplier;

    if (isCharging) {
      if (_state.isOverdrive) {
        tier = OverdriveTier.chargerPenalty;
        multiplier = 1.0;
      } else {
        tier = OverdriveTier.standard;
        multiplier = 1.0;
      }
    } else if (effectiveLevel == 1) {
      tier = OverdriveTier.godMode10x;
      multiplier = 10.0;
    } else if (effectiveLevel <= 10) {
      tier = OverdriveTier.overdrive3x;
      multiplier = 3.0;
    } else {
      tier = OverdriveTier.standard;
      multiplier = 1.0;
    }

    _state = BatteryTelemetryState(
      batteryLevel: effectiveLevel,
      batteryState: effectiveState,
      tier: tier,
      scoreMultiplier: multiplier,
      isSimulated: _overrideActive,
    );
    notifyListeners();
  }

  /// Override battery status for testing 1% Hero or Overdrive modes without draining device.
  void setSimulationOverride({required int level, required bool isCharging}) {
    _overrideActive = true;
    _overrideLevel = level.clamp(1, 100);
    _overrideState = isCharging ? BatteryState.charging : BatteryState.discharging;
    _updateTelemetry(level: _overrideLevel, state: _overrideState);
  }

  void clearSimulationOverride() {
    _overrideActive = false;
    _init();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}

final batteryServiceProvider = ChangeNotifierProvider<BatteryTelemetryService>((ref) {
  return BatteryTelemetryService();
});
