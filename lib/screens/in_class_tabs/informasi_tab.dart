import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/class_model.dart';
import '../../theme/app_theme.dart';
import '../../../config/api_config.dart';
import '../../services/token_service.dart';

class InformasiTab extends StatefulWidget {
  final ClassModel classData;

  const InformasiTab({super.key, required this.classData});

  @override
  State<InformasiTab> createState() => _InformasiTabState();
}

class _InformasiTabState extends State<InformasiTab> {
  final String baseUrl = ApiConfig.baseUrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _coTeachers = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenService.getAccessToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$baseUrl/classes/members/${widget.classData.id}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> members = data['members'] ?? [];

        _students = [];
        _coTeachers = [];
        for (final m in members) {
          final user = m['userId'];
          if (user == null) continue;
          final role = m['role'] ?? 'student';
          final entry = {
            'name': user['name'] ?? '',
            'email': user['email'] ?? '',
            'role': role,
          };
          if (role == 'co-teacher') {
            _coTeachers.add(entry);
          } else {
            _students.add(entry);
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAllStudents() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('All Students (${_students.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _students.length,
                    itemBuilder: (_, i) {
                      final s = _students[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary100,
                          child: Text(
                            (s['name'] as String).isNotEmpty ? s['name'][0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.primary600, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(s['name']),
                        subtitle: Text(s['email'], style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Teacher (Owner)
          _sectionTitle('Pengajar'),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary400,
                child: Text(
                  widget.classData.owner?.name.isNotEmpty == true
                      ? widget.classData.owner!.name[0].toUpperCase()
                      : 'T',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(widget.classData.owner?.name ?? 'Teacher'),
              subtitle: Text(widget.classData.owner?.email ?? '', style: const TextStyle(fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Owner', style: TextStyle(color: AppTheme.primary600, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          // Co-Teachers
          if (_coTeachers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Co-Teacher'),
            ..._coTeachers.map((ct) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text(ct['name'][0].toUpperCase(),
                          style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(ct['name']),
                    subtitle: Text(ct['email'], style: const TextStyle(fontSize: 12)),
                  ),
                )),
          ],

          // Students preview
          const SizedBox(height: 24),
          Row(
            children: [
              _sectionTitle('Murid (${_students.length})'),
              const Spacer(),
              if (_students.length > 3)
                TextButton(
                  onPressed: _showAllStudents,
                  child: const Text('Lihat semua'),
                ),
            ],
          ),
          if (_students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No students enrolled yet.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ..._students.take(5).map((s) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary100,
                      child: Text(
                        (s['name'] as String).isNotEmpty ? s['name'][0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.primary600, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(s['name']),
                    subtitle: Text(s['email'], style: const TextStyle(fontSize: 12)),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
