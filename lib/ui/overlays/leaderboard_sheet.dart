import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/leaderboard_service.dart';
import '../../core/services/procedural_audio_synth.dart';

class LeaderboardSheet extends StatefulWidget {
  const LeaderboardSheet({super.key});

  @override
  State<LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<LeaderboardSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ScoreEntry> _globalScores = [];
  List<ScoreEntry> _onePercentScores = [];
  bool _loading = true;
  String _currentHandle = 'PILOT';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final handle = await LeaderboardService.instance.getPlayerHandle();
    final global = await LeaderboardService.instance.fetchGlobalTopScores();
    final onePercent = await LeaderboardService.instance.fetchOnePercentClubScores();

    if (mounted) {
      setState(() {
        _currentHandle = handle;
        _globalScores = global;
        _onePercentScores = onePercent;
        _loading = false;
      });
    }
  }

  Future<void> _showEditHandleDialog() async {
    final controller = TextEditingController(text: _currentHandle);
    final newHandle = await showDialog<String>(
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
            ),
          ),
          content: TextField(
            controller: controller,
            maxLength: 14,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter 2-14 characters...',
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
                borderSide: const BorderSide(color: SplitPalette.nearMissCyan, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim().toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: SplitPalette.nearMissCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (newHandle != null && newHandle.length >= 2) {
      await LeaderboardService.instance.savePlayerHandle(newHandle);
      setState(() => _currentHandle = newHandle);
    }
  }

  String _formatTimer(int ms) {
    final double seconds = ms / 1000.0;
    final int mins = (seconds / 60).floor();
    final double secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toStringAsFixed(1).padLeft(4, '0')}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
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

            // Header & Callsign
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: const Icon(Icons.emoji_events_outlined, color: SplitPalette.godModeGold, size: 18),
                      ),
                      const SizedBox(width: 10.0),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hall of Records',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            'Verified cognitive reflexes & telemetry',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      ProceduralAudioSynth.instance.playTap();
                      HapticChoreographer.instance.triggerTap();
                      _showEditHandleDialog();
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.white12, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentHandle,
                            style: const TextStyle(
                              color: SplitPalette.nearMissCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          const Icon(Icons.edit, size: 12, color: SplitPalette.nearMissCyan),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14.0),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'Top Scores'),
                  Tab(text: '★ The 1% Club ★'),
                ],
              ),
            ),

            const SizedBox(height: 8.0),

            // Tab View
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: SplitPalette.nearMissCyan, strokeWidth: 2.0))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildScoreList(_globalScores, isOnePercentTab: false),
                        _buildScoreList(_onePercentScores, isOnePercentTab: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreList(List<ScoreEntry> scores, {required bool isOnePercentTab}) {
    if (scores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: isOnePercentTab ? SplitPalette.godModeGold.withOpacity(0.4) : Colors.white12,
                  ),
                ),
                child: Icon(
                  isOnePercentTab ? Icons.bolt_rounded : Icons.track_changes_rounded,
                  size: 26.0,
                  color: isOnePercentTab ? SplitPalette.godModeGold : Colors.white38,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                isOnePercentTab ? 'The 1% Club is unbreached' : 'No records yet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                isOnePercentTab
                    ? 'Survive on ≤ 1% battery in Overdrive to enshrine your score in the vault.'
                    : 'Complete a run to claim the top spot on the leaderboard.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      physics: const BouncingScrollPhysics(),
      itemCount: scores.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1.0),
      itemBuilder: (context, index) {
        final entry = scores[index];
        final rank = index + 1;
        final isTop3 = rank <= 3;
        final isGod = entry.batteryPct <= 1 && entry.wasOverdrive;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 34,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: isTop3
                        ? (isGod ? SplitPalette.godModeGold : SplitPalette.nearMissCyan)
                        : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // Callsign & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.playerHandle,
                          style: TextStyle(
                            color: entry.playerHandle == _currentHandle ? SplitPalette.nearMissCyan : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isGod) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: SplitPalette.godModeGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(color: SplitPalette.godModeGold, width: 0.8),
                            ),
                            child: const Text(
                              '1% GOD',
                              style: TextStyle(
                                color: SplitPalette.godModeGold,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ] else if (entry.wasOverdrive) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: SplitPalette.hazardCrimson.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(color: SplitPalette.hazardCrimson, width: 0.8),
                            ),
                            child: const Text(
                              'OVERDRIVE',
                              style: TextStyle(
                                color: SplitPalette.hazardCrimson,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${_formatTimer(entry.survivalMs)} survival • ${entry.batteryPct}% battery',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Score
              Text(
                '${entry.score}',
                style: TextStyle(
                  color: isGod ? SplitPalette.godModeGold : Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
