import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';
import '../../services/token_service.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/empty_state.dart';

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  final String baseUrl = ApiConfig.baseUrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> notifs = data['notifications'] ?? [];
        _notifications = notifs.cast<Map<String, dynamic>>();
        _unreadCount = data['unreadCount'] ?? 0;
      }
    } catch (e) {
      _errorMessage = 'Failed to load notifications. Check your connection.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markAsRead(String id) async {
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark as read')),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.day}/${l.month}/${l.year} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'join_approved': return Icons.check_circle_outline;
      case 'join_rejected': return Icons.cancel_outlined;
      case 'quiz_new': return Icons.assignment_outlined;
      case 'quiz_open': return Icons.play_circle_outline;
      case 'quiz_closed': return Icons.lock_outline;
      default: return Icons.notifications_none;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'join_approved': return AppTheme.success;
      case 'join_rejected': return AppTheme.error;
      case 'quiz_new': return AppTheme.primary500;
      case 'quiz_open': return AppTheme.warning;
      case 'quiz_closed': return AppTheme.textTertiary;
      default: return AppTheme.primary400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inbox'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerCard(height: 80),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.error.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadNotifications, child: const Text('Retry')),
                    ]),
                  ),
                )
              : _notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'No Notifications Yet',
                  message: 'When you have new quizzes, announcements, or class approvals, they will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isRead = n['isRead'] == true;
                      final type = n['type'] as String?;
                      return Container(
                        color: isRead ? null : AppTheme.primary50.withValues(alpha: 0.5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _typeColor(type).withValues(alpha: 0.1),
                            child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
                          ),
                          title: Text(n['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_formatDate(n['createdAt']), style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                          ]),
                          trailing: isRead ? null : Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary400)),
                          onTap: () {
                            if (!isRead) _markAsRead(n['_id']);
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
