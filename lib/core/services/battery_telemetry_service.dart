import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverdriveTier { standard, overdrive3x, godMode10x, chargerPenalty }

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

  bool get isOverdrive =>
      tier == OverdriveTier.overdrive3x || tier == OverdriveTier.godMode10x;
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

/// The small slice of `battery_plus` the telemetry service depends on.
///
/// `Battery` is a private-constructor singleton, so tests inject this
/// interface instead of mocking the plugin.
abstract class BatterySource {
  Future<int> get batteryLevel;
  Stream<BatteryState> get onBatteryStateChanged;
}

/// Production implementation backed by the `battery_plus` platform channels.
class PlatformBatterySource implements BatterySource {
  final Battery _battery = Battery();

  @override
  Future<int> get batteryLevel => _battery.batteryLevel;

  @override
  Stream<BatteryState> get onBatteryStateChanged =>
      _battery.onBatteryStateChanged;
}

/// Reads live device battery telemetry and derives the Overdrive tier.
///
/// The tier is a pure function of (level, charging) so behaviour is stable
/// across app launches and never depends on the previously observed state.
class BatteryTelemetryService extends ChangeNotifier {
  final BatterySource _battery;
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

  bool _started = false;
  bool _disposed = false;
  bool _readInFlight = false;

  BatteryTelemetryService({BatterySource? source})
    : _battery = source ?? PlatformBatterySource() {
    _start();
  }

  BatteryTelemetryState get state => _state;

  void _start() {
    if (_started || _disposed) return;
    _started = true;

    try {
      _stateSubscription = _battery.onBatteryStateChanged
          .handleError((Object _) {})
          .listen((BatteryState batteryState) {
            if (_overrideActive) return;
            unawaited(_read(levelState: batteryState));
          });
    } catch (_) {
      // Platform channel unavailable (tests, unsupported hosts): stay on defaults.
    }

    _periodicTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_overrideActive) return;
      unawaited(_read());
    });

    unawaited(_read());
  }

  Future<void> _read({BatteryState? levelState}) async {
    if (_disposed || _overrideActive || _readInFlight) return;
    _readInFlight = true;
    try {
      final int level = await _battery.batteryLevel;
      if (_disposed || _overrideActive) return;
      _updateTelemetry(
        level: level,
        batteryState: levelState ?? _state.batteryState,
      );
    } catch (_) {
      // Non-supported host or transient platform error: keep the last reading.
    } finally {
      _readInFlight = false;
    }
  }

  void _updateTelemetry({
    required int level,
    required BatteryState batteryState,
  }) {
    final int effectiveLevel = _overrideActive ? _overrideLevel : level;
    final BatteryState effectiveState = _overrideActive
        ? _overrideState
        : batteryState;

    final bool isCharging =
        effectiveState == BatteryState.charging ||
        effectiveState == BatteryState.full;

    final OverdriveTier tier;
    final double multiplier;

    if (isCharging) {
      // Plugging in disables the low-battery bonus; a low battery while
      // charging is explicitly flagged as a penalty so the player cannot farm
      // Overdrive by keeping the charger connected.
      if (effectiveLevel <= 10) {
        tier = OverdriveTier.chargerPenalty;
      } else {
        tier = OverdriveTier.standard;
      }
      multiplier = 1.0;
    } else if (effectiveLevel <= 1) {
      tier = OverdriveTier.godMode10x;
      multiplier = 10.0;
    } else if (effectiveLevel <= 10) {
      tier = OverdriveTier.overdrive3x;
      multiplier = 3.0;
    } else {
      tier = OverdriveTier.standard;
      multiplier = 1.0;
    }

    final BatteryTelemetryState next = BatteryTelemetryState(
      batteryLevel: effectiveLevel.clamp(0, 100),
      batteryState: effectiveState,
      tier: tier,
      scoreMultiplier: multiplier,
      isSimulated: _overrideActive,
    );

    // Avoid rebuilding the whole overlay tree on every poll when nothing changed.
    if (next.batteryLevel == _state.batteryLevel &&
        next.batteryState == _state.batteryState &&
        next.tier == _state.tier &&
        next.isSimulated == _state.isSimulated) {
      return;
    }

    _state = next;
    if (!_disposed) notifyListeners();
  }

  /// Override battery status for testing 1% Hero or Overdrive modes without draining the device.
  void setSimulationOverride({required int level, required bool isCharging}) {
    if (_disposed) return;
    _overrideActive = true;
    _overrideLevel = level.clamp(1, 100);
    _overrideState = isCharging
        ? BatteryState.charging
        : BatteryState.discharging;
    _updateTelemetry(level: _overrideLevel, batteryState: _overrideState);
  }

  /// Drops the simulation override and resumes real hardware telemetry.
  ///
  /// This intentionally does *not* re-subscribe or re-arm the polling timer,
  /// which previously leaked a subscription and a timer on every call.
  void clearSimulationOverride() {
    if (_disposed || !_overrideActive) return;
    _overrideActive = false;
    unawaited(_read());
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    super.dispose();
  }
}

final batteryServiceProvider = ChangeNotifierProvider<BatteryTelemetryService>((
  ref,
) {
  // ChangeNotifierProvider disposes the notifier it creates, so registering an
  // extra ref.onDispose(service.dispose) would dispose it twice.
  return BatteryTelemetryService();
});
