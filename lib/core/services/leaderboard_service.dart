import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single completed run.
///
/// All fields are gameplay telemetry generated on-device. No identifiers,
/// location, contacts or advertising data are ever stored.
class ScoreEntry {
  final String id;
  final String playerHandle;
  final int score;
  final int survivalMs;
  final int batteryPct;
  final bool wasOverdrive;
  final String failedHemisphere; // 'LEFT' or 'RIGHT'
  final DateTime createdAt;

  const ScoreEntry({
    required this.id,
    required this.playerHandle,
    required this.score,
    required this.survivalMs,
    required this.batteryPct,
    required this.wasOverdrive,
    required this.failedHemisphere,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_handle': playerHandle,
      'score': score,
      'survival_ms': survivalMs,
      'battery_pct': batteryPct,
      'was_overdrive': wasOverdrive,
      'failed_hemisphere': failedHemisphere,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScoreEntry.fromMap(Map<String, dynamic> map) {
    return ScoreEntry(
      id: map['id']?.toString() ?? '',
      playerHandle: map['player_handle']?.toString() ?? 'PILOT',
      score: (map['score'] as num?)?.toInt() ?? 0,
      survivalMs: (map['survival_ms'] as num?)?.toInt() ?? 0,
      batteryPct: (map['battery_pct'] as num?)?.toInt() ?? 100,
      wasOverdrive: map['was_overdrive'] == true,
      failedHemisphere: map['failed_hemisphere']?.toString() == 'RIGHT'
          ? 'RIGHT'
          : 'LEFT',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// On-device run history and high score store.
///
/// Split Reflex intentionally has **no remote leaderboard**. Keeping the
/// leaderboard local means the app needs no network permission, collects no
/// user data, and stays outside Google Play's user-generated-content policy.
class LeaderboardService {
  static final LeaderboardService instance = LeaderboardService._internal();
  LeaderboardService._internal();

  static const String _localScoresKey = 'split_brain_local_scores';
  static const String _localHighScoreKey = 'split_brain_high_score';
  static const String _playerHandleKey = 'split_brain_player_handle';

  /// Hard cap so a long-lived install cannot grow prefs without bound.
  static const int maxStoredScores = 200;

  /// Maximum length of a callsign, matching the UI input limit.
  static const int maxHandleLength = 14;

  bool _initialized = false;

  /// Kept for source compatibility with earlier builds; the store is local and
  /// therefore needs no credentials or network handshake.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Normalises a user-entered callsign: strips control characters, collapses
  /// whitespace, upper-cases it and clamps the length.
  static String sanitizeHandle(String? raw) {
    final String cleaned = (raw ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '')
        .trim()
        .toUpperCase();
    if (cleaned.isEmpty) return 'PILOT';
    return cleaned.length > maxHandleLength
        ? cleaned.substring(0, maxHandleLength).trim()
        : cleaned;
  }

  Future<String> getPlayerHandle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return sanitizeHandle(prefs.getString(_playerHandleKey));
    } catch (_) {
      return 'PILOT';
    }
  }

  Future<void> savePlayerHandle(String handle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playerHandleKey, sanitizeHandle(handle));
    } catch (error) {
      debugPrint('Failed to persist player handle: $error');
    }
  }

  Future<int> getLocalHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_localHighScoreKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearLocalScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localScoresKey);
      await prefs.remove(_localHighScoreKey);
    } catch (error) {
      debugPrint('Failed to clear local scores: $error');
    }
  }

  /// Removes every piece of data the app has written (scores + callsign).
  Future<void> clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localScoresKey);
      await prefs.remove(_localHighScoreKey);
      await prefs.remove(_playerHandleKey);
    } catch (error) {
      debugPrint('Failed to clear user data: $error');
    }
  }

  Future<void> recordScore(ScoreEntry entry) async {
    // Reject nonsense telemetry rather than persisting it.
    if (entry.score < 0 ||
        entry.survivalMs < 0 ||
        entry.survivalMs > 86400000) {
      debugPrint('Discarding invalid score entry');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final int currentHigh = prefs.getInt(_localHighScoreKey) ?? 0;
      if (entry.score > currentHigh) {
        await prefs.setInt(_localHighScoreKey, entry.score);
      }

      final List<String> rawList =
          prefs.getStringList(_localScoresKey) ?? <String>[];
      rawList.add(jsonEncode(entry.toMap()));

      // Keep only the newest [maxStoredScores] runs.
      final List<String> trimmed = rawList.length > maxStoredScores
          ? rawList.sublist(rawList.length - maxStoredScores)
          : rawList;

      await prefs.setStringList(_localScoresKey, trimmed);
    } catch (error) {
      debugPrint('Failed to record score: $error');
    }
  }

  /// Top runs stored on this device. There is no remote source to merge with.
  Future<List<ScoreEntry>> fetchGlobalTopScores() {
    return _getLocalScores(filterOnePercentClub: false);
  }

  /// Low-battery "1% club" runs stored on this device.
  Future<List<ScoreEntry>> fetchOnePercentClubScores() {
    return _getLocalScores(filterOnePercentClub: true);
  }

  Future<List<ScoreEntry>> _getLocalScores({
    required bool filterOnePercentClub,
  }) async {
    List<String> rawList;
    try {
      final prefs = await SharedPreferences.getInstance();
      rawList = prefs.getStringList(_localScoresKey) ?? <String>[];
    } catch (error) {
      debugPrint('Failed to read local scores: $error');
      return <ScoreEntry>[];
    }

    final List<ScoreEntry> entries = <ScoreEntry>[];
    for (final String raw in rawList) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          entries.add(ScoreEntry.fromMap(decoded));
        }
      } catch (_) {
        // Skip corrupt rows instead of failing the whole leaderboard.
      }
    }

    final List<ScoreEntry> filtered = filterOnePercentClub
        ? entries.where((e) => e.batteryPct <= 1 && e.wasOverdrive).toList()
        : entries;

    filtered.sort((a, b) => b.score.compareTo(a.score));
    return filtered;
  }
}
