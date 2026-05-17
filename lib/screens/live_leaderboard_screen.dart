import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/class_model.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class LiveLeaderboardScreen extends StatefulWidget {
  final QuizModel quiz;
  final Map<String, dynamic> result;

  const LiveLeaderboardScreen({super.key, required this.quiz, required this.result});

  @override
  State<LiveLeaderboardScreen> createState() => _LiveLeaderboardScreenState();
}

class _LiveLeaderboardScreenState extends State<LiveLeaderboardScreen> {
  late IO.Socket _socket;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _initLiveLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/quizzes/${widget.quiz.id}/live/leaderboard'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load leaderboard';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error while fetching leaderboard.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initLiveLeaderboard() async {
    await _fetchLeaderboard();

    final token = await TokenService.getAccessToken();
    if (token == null) return;

    final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      _socket.emit('join:quiz', widget.quiz.id);
    });

    _socket.on('live:leaderboard_update', (_) {
      _fetchLeaderboard();
    });
    
    _socket.on('live:cancelled', (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The teacher has ended the live quiz.')),
        );
      }
    });
  }

  @override
  void dispose() {
    if (_socket.connected) {
      _socket.emit('leave:quiz', widget.quiz.id);
      _socket.disconnect();
    }
    _socket.dispose();
    super.dispose();
  }

  Widget _buildTopThree() {
    if (_leaderboard.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.primary600,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_leaderboard.length > 1) _buildPodiumItem(_leaderboard[1], 2, 100),
          _buildPodiumItem(_leaderboard[0], 1, 140),
          if (_leaderboard.length > 2) _buildPodiumItem(_leaderboard[2], 3, 80),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> data, int rank, double height) {
    final user = data['user'] ?? {};
    final attempt = widget.result['attempt'] ?? {};
    final isCurrentUser = user['_id'] == attempt['studentId']; 
    final name = user['name'] ?? 'Unknown';
    final score = data['score']?.toString() ?? '0';

    Color rankColor;
    if (rank == 1) rankColor = const Color(0xFFFACC15); // gold
    else if (rank == 2) rankColor = AppTheme.gray300; // silver
    else rankColor = const Color(0xFFCD7F32); // bronze

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          name.split(' ').first,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: rankColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                '#$rank',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '$score pts',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Leaderboard'),
        backgroundColor: AppTheme.primary600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildTopThree(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _leaderboard.length > 3 ? _leaderboard.length - 3 : 0,
                        itemBuilder: (context, index) {
                          final data = _leaderboard[index + 3];
                          final rank = data['rank'] ?? (index + 4);
                          final user = data['user'] ?? {};
                          final name = user['name'] ?? 'Unknown';
                          final score = data['score']?.toString() ?? '0';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary100,
                                child: Text(
                                  '#$rank',
                                  style: const TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: Text('$score pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary600)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
