import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../services/token_service.dart';
import '../models/class_model.dart';
import '../screens/live_quiz_waiting_screen.dart';

/// Global service that maintains a Socket.IO connection
/// and listens for live quiz events across all joined classes.
class LiveQuizService {
  io.Socket? _socket;
  BuildContext? _context;

  /// Initialize the socket connection and start listening for live quiz events.
  Future<void> connect(BuildContext context) async {
    _context = context;

    final token = await TokenService.getAccessToken();
    if (token == null) return;

    final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('🔌 LiveQuizService: Socket connected');
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 LiveQuizService: Socket disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('🔌 LiveQuizService: Connection error: $err');
    });

    // Listen for live quiz started event
    _socket!.on('live:started', (data) {
      debugPrint('🔔 Live quiz started: $data');
      if (_context != null && _context!.mounted) {
        _showLiveQuizDialog(data);
      }
    });
  }

  /// Join class rooms so the student receives live quiz notifications
  void joinClassRoom(String classId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join:class', classId);
      debugPrint('🔌 LiveQuizService: Joined class room $classId');
    }
  }

  /// Join all class rooms from a list of classes
  void joinAllClassRooms(List<ClassModel> classes) {
    for (final cls in classes) {
      joinClassRoom(cls.id);
    }
  }

  void _showLiveQuizDialog(dynamic data) {
    final ctx = _context;
    if (ctx == null || !ctx.mounted) return;

    final quizTitle = data['title'] ?? 'Live Quiz';
    final pin = data['pin']?.toString() ?? '';
    final duration = data['duration'] ?? 0;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bolt, color: Colors.red.shade400, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '🔴 Live Quiz!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quizTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '⏱ Durasi: $duration menit',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (pin.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PIN: $pin',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 6,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Guru telah memulai live quiz! Bergabung sekarang untuk mengikuti kuis secara langsung.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Nanti', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              // Navigate to live quiz waiting screen with pre-filled PIN
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => LiveQuizWaitingScreen(initialPin: pin),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Bergabung Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Disconnect the socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _context = null;
  }
}
