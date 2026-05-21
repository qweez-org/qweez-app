import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../services/token_service.dart';
import '../models/class_model.dart';

/// Global service that maintains a Socket.IO connection
/// and listens for live quiz events across all joined classes.
class LiveQuizService {
  io.Socket? _socket;

  /// Notifier that fires when a live quiz starts. UI layers observe this.
  final ValueNotifier<Map<String, dynamic>?> liveStartedNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  final Set<String> _joinedClassIds = {};

  /// Initialize the socket connection and start listening for live quiz events.
  Future<void> connect(BuildContext context) async {

    final token = await TokenService.getAccessToken();
    if (token == null) return;

    final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      // Re-join any previously joined class rooms
      for (final classId in _joinedClassIds) {
        _socket!.emit('join:class', classId);
      }
    });

    _socket!.connect();

    // Listen for live quiz start events from joined class rooms
    _socket!.on('live:started', (data) {
      if (data is Map<String, dynamic>) {
        liveStartedNotifier.value = data;
      } else if (data is Map) {
        liveStartedNotifier.value = Map<String, dynamic>.from(data);
      }
    });

  }

  /// Join class rooms so the student receives live quiz notifications
  void joinClassRoom(String classId) {
    _joinedClassIds.add(classId);
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join:class', classId);

    }
  }

  /// Join all class rooms from a list of classes
  void joinAllClassRooms(List<ClassModel> classes) {
    for (final cls in classes) {
      joinClassRoom(cls.id);
    }
  }



  /// Disconnect the socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _joinedClassIds.clear();
  }
}
