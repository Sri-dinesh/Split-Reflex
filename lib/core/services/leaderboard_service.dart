import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      playerHandle: map['player_handle']?.toString() ?? 'ANON',
      score: (map['score'] as num?)?.toInt() ?? 0,
      survivalMs: (map['survival_ms'] as num?)?.toInt() ?? 0,
      batteryPct: (map['battery_pct'] as num?)?.toInt() ?? 100,
      wasOverdrive: map['was_overdrive'] == true,
      failedHemisphere: map['failed_hemisphere']?.toString() ?? 'LEFT',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class LeaderboardService {
  static final LeaderboardService instance = LeaderboardService._internal();
  LeaderboardService._internal();

  static const String _localScoresKey = 'split_brain_local_scores';
  static const String _localHighScoreKey = 'split_brain_high_score';
  static const String _playerHandleKey = 'split_brain_player_handle';

  bool _supabaseInitialized = false;

  Future<void> init({String? supabaseUrl, String? supabaseAnonKey}) async {
    if (supabaseUrl != null && supabaseAnonKey != null && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey, // ignore: deprecated_member_use
        );
        _supabaseInitialized = true;
      } catch (e) {
        debugPrint('Supabase init skipped or offline: $e');
        _supabaseInitialized = false;
      }
    }
  }

  Future<String> getPlayerHandle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playerHandleKey) ?? 'HERO_${DateTime.now().millisecond % 1000}';
  }

  Future<void> savePlayerHandle(String handle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerHandleKey, handle.trim());
  }

  Future<int> getLocalHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_localHighScoreKey) ?? 0;
  }

  Future<void> recordScore(ScoreEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt(_localHighScoreKey) ?? 0;
    if (entry.score > currentHigh) {
      await prefs.setInt(_localHighScoreKey, entry.score);
    }

    // Save to local scores cache
    final rawList = prefs.getStringList(_localScoresKey) ?? [];
    final jsonStr = jsonEncode(entry.toMap());
    rawList.add(jsonStr);
    await prefs.setStringList(_localScoresKey, rawList);

    // If Supabase is connected, submit online
    if (_supabaseInitialized) {
      try {
        await Supabase.instance.client.from('scores').insert({
          'player_handle': entry.playerHandle,
          'score': entry.score,
          'survival_ms': entry.survivalMs,
          'battery_pct': entry.batteryPct,
          'was_overdrive': entry.wasOverdrive,
          'failed_hemisphere': entry.failedHemisphere,
        });
      } catch (e) {
        debugPrint('Failed to submit score to Supabase: $e');
      }
    }
  }

  Future<List<ScoreEntry>> fetchGlobalTopScores() async {
    if (_supabaseInitialized) {
      try {
        final response = await Supabase.instance.client
            .from('scores')
            .select()
            .order('score', ascending: false)
            .limit(100);

        final list = (response as List).map((row) => ScoreEntry.fromMap(row as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('Failed to fetch from Supabase: $e');
      }
    }

    // Fallback: local scores + procedural mock records
    return _getLocalScores(filterOnePercentClub: false);
  }

  Future<List<ScoreEntry>> fetchOnePercentClubScores() async {
    if (_supabaseInitialized) {
      try {
        final response = await Supabase.instance.client
            .from('scores')
            .select()
            .eq('battery_pct', 1)
            .eq('was_overdrive', true)
            .order('score', ascending: false)
            .limit(100);

        final list = (response as List).map((row) => ScoreEntry.fromMap(row as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('Failed to fetch 1% club from Supabase: $e');
      }
    }

    // Fallback: local scores + procedural mock records
    return _getLocalScores(filterOnePercentClub: true);
  }

  Future<List<ScoreEntry>> _getLocalScores({required bool filterOnePercentClub}) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_localScoresKey) ?? [];

    final List<ScoreEntry> entries = [];
    for (final s in rawList) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        entries.add(ScoreEntry.fromMap(map));
      } catch (_) {}
    }

    // Add high quality seed benchmark entries if list is small
    if (entries.length < 5) {
      entries.addAll(_generateBenchmarkScores());
    }

    List<ScoreEntry> filtered = entries;
    if (filterOnePercentClub) {
      filtered = entries.where((e) => e.batteryPct <= 1 && e.wasOverdrive).toList();
      if (filtered.isEmpty) {
        filtered.add(
          ScoreEntry(
            id: 'legend-01',
            playerHandle: 'ZERO_HERO',
            score: 48250,
            survivalMs: 64200,
            batteryPct: 1,
            wasOverdrive: true,
            failedHemisphere: 'LEFT',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
        );
      }
    }

    filtered.sort((a, b) => b.score.compareTo(a.score));
    return filtered;
  }

  List<ScoreEntry> _generateBenchmarkScores() {
    final now = DateTime.now();
    return [
      ScoreEntry(
        id: 'bench-1',
        playerHandle: 'SYNAPSE_X',
        score: 52180,
        survivalMs: 72400,
        batteryPct: 1,
        wasOverdrive: true,
        failedHemisphere: 'RIGHT',
        createdAt: now.subtract(const Duration(minutes: 32)),
      ),
      ScoreEntry(
        id: 'bench-2',
        playerHandle: 'NEURO_SLICER',
        score: 38400,
        survivalMs: 54100,
        batteryPct: 6,
        wasOverdrive: true,
        failedHemisphere: 'LEFT',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ScoreEntry(
        id: 'bench-3',
        playerHandle: 'CORTEX_99',
        score: 29500,
        survivalMs: 44800,
        batteryPct: 84,
        wasOverdrive: false,
        failedHemisphere: 'RIGHT',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      ScoreEntry(
        id: 'bench-4',
        playerHandle: 'THUMB_GOD',
        score: 22100,
        survivalMs: 36200,
        batteryPct: 4,
        wasOverdrive: true,
        failedHemisphere: 'LEFT',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
