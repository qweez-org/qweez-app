import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../services/token_service.dart';

import '../theme/app_theme.dart';
import 'live_quiz_screen.dart';

/// Screen where students enter a PIN to join a live quiz.
/// Flow: PIN input → socket student_join → wait for join_success → lobby → quiz_started → navigate
class LiveQuizWaitingScreen extends StatefulWidget {
  /// Optional pre-filled PIN (from live:started notification)
  final String? initialPin;

  const LiveQuizWaitingScreen({super.key, this.initialPin});

  @override
  State<LiveQuizWaitingScreen> createState() => _LiveQuizWaitingScreenState();
}

class _LiveQuizWaitingScreenState extends State<LiveQuizWaitingScreen> {
  final TextEditingController _pinController = TextEditingController();
  io.Socket? _socket;

  // UI state
  bool _isConnecting = false;
  bool _isInLobby = false;
  bool _isNavigatingToQuiz = false;
  String? _errorMessage;
  String? _quizTitle;
  int _participantCount = 0;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialPin != null && widget.initialPin!.isNotEmpty) {
      _pinController.text = widget.initialPin!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinSession());
    } else {
      // Check for stored active session
      _checkStoredSession();
    }
  }

  Future<void> _checkStoredSession() async {
    final storedPin = await TokenService.getActivePin();
    if (storedPin != null && storedPin.isNotEmpty && mounted) {
      _pinController.text = storedPin;
      _joinSession();
    }
  }

  Future<void> _joinSession() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _errorMessage = 'PIN harus 6 digit');
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final token = await TokenService.getAccessToken();
    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication error. Please login again.';
        _isConnecting = false;
      });
      return;
    }

    // Get user name for display — server will use authenticated user name

    final serverUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    // Dispose any existing socket to prevent leaks on rapid re-join
    _socket?.disconnect();
    _socket?.dispose();

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[LiveQuiz] Socket connected, emitting student_join with pin=$pin');
      _socket!.emit('student_join', {
        'pin': pin,
        'displayName': '', // Server will use authenticated user name
      });
    });

    _socket!.onConnectError((err) {
      debugPrint('[LiveQuiz] Socket connect error: $err');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal terhubung ke server. Pastikan koneksi internet & WiFi yang sama.\n($err)';
          _isConnecting = false;
        });
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[LiveQuiz] Socket disconnected');
    });

    // ── Socket Event Handlers ──────────────────────────────────────────────

    _socket!.on('join_success', (data) {
      if (mounted) {
        setState(() {
          _isInLobby = true;
          _isConnecting = false;
          _quizTitle = data['quizTitle'] ?? 'Live Quiz';
          _participantCount = data['participantCount'] ?? 1;
        });
        // Store active pin
        TokenService.setActivePin(_pinController.text.trim());
      }
    });

    _socket!.on('join_error', (data) {

      if (mounted) {
        setState(() {
          _errorMessage = data['message'] ?? 'Gagal bergabung.';
          _isConnecting = false;
        });
        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
        TokenService.clearActivePin();
      }
    });

    _socket!.on('participant_joined', (data) {
      if (mounted) {
        setState(() {
          _participantCount = data['participantCount'] ?? _participantCount;
          _participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
        });
      }
    });

    _socket!.on('participant_left', (data) {
      if (mounted) {
        setState(() {
          _participantCount = data['participantCount'] ?? _participantCount;
        });
      }
    });

    _socket!.on('quiz_started', (data) async {

      if (mounted) {
        final allQuestions = (data['allQuestions'] as List?)
            ?.map((q) => Map<String, dynamic>.from(q as Map))
            .toList() ?? [];
        final totalDurationSec = data['totalDurationSec'] ?? 0;
        final allowBacktrack = data['allowBacktrack'] ?? true;
        final shuffleQuestions = data['shuffleQuestions'] ?? false;
        final shuffleOptions = data['shuffleOptions'] ?? false;
        
        final existingAnswers = data['existingAnswers'] != null
            ? Map<String, dynamic>.from(data['existingAnswers'] as Map)
            : <String, dynamic>{};

        for (var i = 0; i < allQuestions.length; i++) {
          allQuestions[i]['_originalIndex'] = i;
          if (shuffleOptions && allQuestions[i]['options'] != null) {
            final options = List<Map<String, dynamic>>.from(allQuestions[i]['options']);
            options.shuffle();
            allQuestions[i]['options'] = options;
          }
        }

        if (shuffleQuestions) {
          allQuestions.shuffle();
        }

        // Navigate to the live quiz screen with all questions and total timer
        _isNavigatingToQuiz = true;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveQuizScreen(
              socket: _socket!,
              pin: pin,
              quizTitle: _quizTitle ?? 'Live Quiz',
              allQuestions: allQuestions,
              totalDurationSec: totalDurationSec,
              allowBacktrack: allowBacktrack,
              existingAnswers: existingAnswers,
            ),
          ),
        );
        // After LiveQuizScreen pops (student clicks "Selesai"), pop this waiting screen too
        // so QuizDetailScreen's await resolves and refreshes data
        if (mounted) Navigator.pop(context);
        // Clear stored pin after quiz navigation completes
        TokenService.clearActivePin();
      }
    });

    _socket!.on('session_cancelled', (data) {
      if (mounted) {
        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
        TokenService.clearActivePin();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Sesi Dibatalkan'),
            content: const Text('Guru telah membatalkan sesi live quiz ini.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    _socket!.on('teacher_disconnected', (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Guru terputus. Menunggu koneksi ulang...'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    });

    _socket!.connect();
  }

  @override
  void dispose() {
    _pinController.dispose();
    // Only disconnect if we haven't navigated to the quiz yet
    if (!_isNavigatingToQuiz && _socket != null) {
      _socket?.disconnect();
      _socket?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary50,
      appBar: AppBar(
        title: const Text('Live Quiz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _isInLobby ? _buildLobby() : _buildPinEntry(),
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.bolt, size: 64, color: AppTheme.live),
        ),
        const SizedBox(height: 32),
        Text(
          'Masukkan PIN',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Masukkan 6 digit PIN dari guru untuk bergabung',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // PIN Input
        SizedBox(
          width: 240,
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 12,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                color: AppTheme.gray300,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary200, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primary500, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Error message
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Join button
        SizedBox(
          width: 240,
          child: ElevatedButton(
            onPressed: _isConnecting ? null : _joinSession,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Bergabung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildLobby() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Quiz title
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.bolt, size: 80, color: Colors.orange),
        ),
        const SizedBox(height: 24),
        Text(
          _quizTitle ?? 'Live Quiz',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Menunggu guru memulai kuis...',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 32),

        // Participant count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primary200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group, color: AppTheme.primary600, size: 28),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Text(
                  '$_participantCount',
                  key: ValueKey<int>(_participantCount),
                  style: const TextStyle(
                    color: AppTheme.primary700,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const Text(
                ' siswa bergabung',
                style: TextStyle(
                  color: AppTheme.primary700,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Participant chips
        if (_participants.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _participants.map((p) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: AppTheme.primary100,
                  child: Text(
                    (p['displayName'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary700),
                  ),
                ),
                label: Text(p['displayName'] ?? 'Siswa'),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.primary100),
              );
            }).toList(),
          ),

        const SizedBox(height: 32),

        // Loading indicator
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: 8),
        Text(
          'PIN: ${_pinController.text}',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 14,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
