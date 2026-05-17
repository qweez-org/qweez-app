import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../theme/app_theme.dart';
import '../in_class_shell_screen.dart';
import '../live_quiz_waiting_screen.dart';

class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClassProvider>(context, listen: false).fetchClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        automaticallyImplyLeading: false,
      ),
      body: classProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => classProvider.fetchClasses(),
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  Text(
                    'Welcome back, ${user?.name.split(' ').first ?? 'Student'}!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Here are your enrolled classes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  // Join Live Quiz Card
                  Card(
                    color: AppTheme.live.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      side: BorderSide(color: AppTheme.live.withValues(alpha: 0.3)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LiveQuizWaitingScreen()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.live.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: const Icon(Icons.bolt, color: AppTheme.live, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gabung Live Quiz',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.live,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Masukkan PIN dari guru untuk bergabung',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.live.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppTheme.live.withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (classProvider.classes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.class_outlined, size: 64, color: AppTheme.primary200),
                            const SizedBox(height: 16),
                            const Text(
                              'You are not enrolled in any classes yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...classProvider.classes.map((c) {
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InClassShellScreen(classData: c),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary50,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                  child: const Icon(Icons.menu_book, color: AppTheme.primary500),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.owner?.name ?? 'Teacher',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
