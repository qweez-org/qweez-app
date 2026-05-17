import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../services/token_service.dart';
import '../models/class_model.dart';

/// Global service that maintains a Socket.IO connection
/// and listens for live quiz events across all joined classes.
class LiveQuizService {
  io.Socket? _socket;
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

    _socket!.connect();




  }

  /// Join class rooms so the student receives live quiz notifications
  void joinClassRoom(String classId) {
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
  }
}
