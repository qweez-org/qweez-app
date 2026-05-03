import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  final String baseUrl = 'http://192.168.1.15:5000/api';
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
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
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markAsRead(String id) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _loadNotifications();
    } catch (e) { /* ignore */ }
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
      case 'join_approved': return const Color(0xFF22C55E);
      case 'join_rejected': return Colors.red;
      case 'quiz_new': return AppTheme.primary500;
      case 'quiz_open': return Colors.orange;
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
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.notifications_none, size: 80, color: AppTheme.primary200),
                    const SizedBox(height: 24),
                    Text('No Notifications Yet', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('When you have new quizzes, announcements, or class approvals, they will appear here.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                  ]),
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
