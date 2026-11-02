import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class InputRouter {
  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _lastPositions = {};

  // Thumb activity history for death autopsy sparkline
  final List<double> leftActivityHistory = [];
  final List<double> rightActivityHistory = [];
  double _currentWindowLeftActivity = 0.0;
  double _currentWindowRightActivity = 0.0;
  double _activityBucketTimer = 0.0;

  // Biometric dual-thumb hold tracking
  bool leftThumbHeld = false;
  bool rightThumbHeld = false;

  void resetActivity() {
    _activePointers.clear();
    _lastPositions.clear();
    leftActivityHistory.clear();
    rightActivityHistory.clear();
    _currentWindowLeftActivity = 0.0;
    _currentWindowRightActivity = 0.0;
    _activityBucketTimer = 0.0;
    leftThumbHeld = false;
    rightThumbHeld = false;
  }

  void updateActivityTimer(double dt) {
    _activityBucketTimer += dt;
    // Record activity density every 500ms
    if (_activityBucketTimer >= 0.5) {
      _activityBucketTimer = 0.0;
      leftActivityHistory.add(_currentWindowLeftActivity);
      rightActivityHistory.add(_currentWindowRightActivity);
      _currentWindowLeftActivity = 0.0;
      _currentWindowRightActivity = 0.0;

      // Keep up to 60 buckets (30 seconds of sparkline)
      if (leftActivityHistory.length > 60) {
        leftActivityHistory.removeAt(0);
        rightActivityHistory.removeAt(0);
      }
    }
  }

  void handlePointerDown({
    required PointerDownEvent event,
    required double splitX,
    required void Function(bool isLeft, Offset localPosition) onPointerDown,
  }) {
    _activePointers[event.pointer] = event.localPosition;
    _lastPositions[event.pointer] = event.localPosition;

    final bool isLeft = event.localPosition.dx < splitX;
    if (isLeft) {
      leftThumbHeld = true;
      _currentWindowLeftActivity += 1.0;
    } else {
      rightThumbHeld = true;
      _currentWindowRightActivity += 1.0;
    }
    onPointerDown(isLeft, event.localPosition);
  }

  void handlePointerMove({
    required PointerMoveEvent event,
    required double splitX,
    required void Function(bool isLeft, double deltaX, Offset localPosition)
    onPointerMove,
  }) {
    final Offset prevPos = _lastPositions[event.pointer] ?? event.localPosition;
    final double deltaX = event.localPosition.dx - prevPos.dx;
    _lastPositions[event.pointer] = event.localPosition;
    _activePointers[event.pointer] = event.localPosition;

    final bool isLeft = event.localPosition.dx < splitX;
    if (isLeft) {
      _currentWindowLeftActivity += deltaX.abs() * 0.1;
    } else {
      _currentWindowRightActivity += deltaX.abs() * 0.1;
    }
    onPointerMove(isLeft, deltaX, event.localPosition);
  }

  void handlePointerUp({
    required PointerUpEvent event,
    required double splitX,
  }) {
    _removePointer(event.pointer, splitX);
  }

  void handlePointerCancel({
    required PointerCancelEvent event,
    required double splitX,
  }) {
    _removePointer(event.pointer, splitX);
  }

  void _removePointer(int pointerId, double splitX) {
    _activePointers.remove(pointerId);
    _lastPositions.remove(pointerId);

    // Re-evaluate thumb hold status
    bool hasLeft = false;
    bool hasRight = false;
    for (final p in _activePointers.values) {
      if (p.dx < splitX) {
        hasLeft = true;
      } else {
        hasRight = true;
      }
    }
    leftThumbHeld = hasLeft;
    rightThumbHeld = hasRight;
  }
}
