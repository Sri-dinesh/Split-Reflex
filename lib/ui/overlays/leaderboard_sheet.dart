import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/leaderboard_service.dart';

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
  String _currentHandle = '';

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
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'CALLSIGN (PLAYER HANDLE)',
            style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: controller,
            maxLength: 16,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'ENTER 2-16 CHARS',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim().toUpperCase()),
              style: ElevatedButton.styleFrom(backgroundColor: SplitPalette.hazardCrimson),
              child: const Text('SAVE', style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.w900)),
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
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12.0),
          Container(
            width: 40.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          const SizedBox(height: 14.0),

          // Header & Callsign
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HALL OF HEROES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontFamily: 'monospace',
                  ),
                ),
                GestureDetector(
                  onTap: _showEditHandleDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: Colors.white24, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentHandle.isEmpty ? 'SET CALLSIGN' : _currentHandle,
                          style: const TextStyle(
                            color: SplitPalette.nearMissCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
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

          const SizedBox(height: 12.0),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: SplitPalette.hazardCrimson,
            indicatorWeight: 3.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
            tabs: const [
              Tab(text: 'GLOBAL TOP 100'),
              Tab(text: '★ THE 1% CLUB ★'),
            ],
          ),

          // Tab View
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: SplitPalette.hazardCrimson))
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
    );
  }

  Widget _buildScoreList(List<ScoreEntry> scores, {required bool isOnePercentTab}) {
    if (scores.isEmpty) {
      return Center(
        child: Text(
          isOnePercentTab
              ? 'NO ONE HAS SURVIVED AT 1% BATTERY YET.\nWILL YOU BE FIRST?'
              : 'NO SCORES RECORDED YET.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontFamily: 'monospace',
            letterSpacing: 1.0,
            height: 1.5,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: scores.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1.0),
      itemBuilder: (context, index) {
        final entry = scores[index];
        final rank = index + 1;
        final isTop3 = rank <= 3;
        final isGod = entry.batteryPct <= 1 && entry.wasOverdrive;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 32,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: isTop3
                        ? (isGod ? SplitPalette.godModeGold : SplitPalette.hazardCrimson)
                        : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              // Callsign & Survival Details
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
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (isGod) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: SplitPalette.godModeGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2.0),
                              border: Border.all(color: SplitPalette.godModeGold, width: 0.5),
                            ),
                            child: const Text(
                              '1% GOD',
                              style: TextStyle(
                                color: SplitPalette.godModeGold,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ] else if (entry.wasOverdrive) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: SplitPalette.hazardCrimson.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2.0),
                              border: Border.all(color: SplitPalette.hazardCrimson, width: 0.5),
                            ),
                            child: const Text(
                              'OVERDRIVE',
                              style: TextStyle(
                                color: SplitPalette.hazardCrimson,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${_formatTimer(entry.survivalMs)} // ${entry.batteryPct}% BATTERY',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace',
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
