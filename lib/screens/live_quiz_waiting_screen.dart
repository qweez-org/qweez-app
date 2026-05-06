import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/class_model.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import 'quiz_screen.dart';

class LiveQuizWaitingScreen extends StatefulWidget {
  final QuizModel quiz;

  const LiveQuizWaitingScreen({super.key, required this.quiz});

  @override
  State<LiveQuizWaitingScreen> createState() => _LiveQuizWaitingScreenState();
}

class _LiveQuizWaitingScreenState extends State<LiveQuizWaitingScreen> {
  late IO.Socket _socket;
  bool _isLoading = true;
  String? _errorMessage;
  int _participantCount = 0;

  @override
  void initState() {
    super.initState();
    _initLiveSession();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _initLiveSession() async {
    try {
      final token = await _getToken();
      if (token == null) {
        setState(() => _errorMessage = 'Authentication error');
        return;
      }

      // 1. Join via REST API
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/quizzes/${widget.quiz.id}/live/join'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        setState(() {
          _errorMessage = json.decode(res.body)['message'] ?? 'Failed to join live session.';
          _isLoading = false;
        });
        return;
      }

      final data = json.decode(res.body);
      setState(() {
        _participantCount = data['participantCount'] ?? 1;
      });

      // 2. Connect Socket.IO
      final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );

      _socket.connect();

      _socket.onConnect((_) {
        print('Socket connected');
        _socket.emit('join:quiz', widget.quiz.id);
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

      _socket.onConnectError((err) {
        print('Socket connection error: $err');
      });

      _socket.on('live:participant_joined', (data) {
        if (mounted) {
          setState(() {
            _participantCount = data['count'];
          });
        }
      });

      _socket.on('live:begin', (data) {
        if (mounted) {
          _socket.disconnect(); // Disconnect from waiting room
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => QuizScreen(quiz: widget.quiz)),
          );
        }
      });

      _socket.on('live:cancelled', (_) {
        if (mounted) {
          _socket.disconnect();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Session Cancelled'),
              content: const Text('The teacher has cancelled this live quiz session.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: const Text('OK'),
                )
              ],
            ),
          );
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error. Could not join session.';
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary50,
      appBar: AppBar(
        title: const Text('Live Quiz Waiting Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('Connecting to live session...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              )
            : _errorMessage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bolt, size: 80, color: Colors.orange),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.quiz.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Waiting for the teacher to start...',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppTheme.primary200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group, color: AppTheme.primary600),
                            const SizedBox(width: 12),
                            Text(
                              '$_participantCount students waiting',
                              style: const TextStyle(
                                color: AppTheme.primary700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
