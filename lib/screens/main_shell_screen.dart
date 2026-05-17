import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/class_provider.dart';
import '../services/live_quiz_service.dart';
import 'tabs/classes_tab.dart';
import 'tabs/join_class_tab.dart';
import 'tabs/inbox_tab.dart';
import 'tabs/profile_tab.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  final LiveQuizService _liveQuizService = LiveQuizService();
  bool _socketInitialized = false;

  final List<Widget> _tabs = [
    const ClassesTab(),
    const JoinClassTab(),
    const InboxTab(),
    const ProfileTab(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initSocketIfNeeded();
  }

  void _initSocketIfNeeded() {
    if (_socketInitialized) return;
    _socketInitialized = true;

    // Connect the live quiz socket and join class rooms after classes load
    _liveQuizService.connect(context).then((_) {
      if (!mounted) return;
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      // If classes are already loaded, join their rooms
      if (classProvider.classes.isNotEmpty) {
        _liveQuizService.joinAllClassRooms(classProvider.classes);
      }
      // Also listen for future class list changes
      classProvider.addListener(() {
        if (!mounted) return;
        if (classProvider.classes.isNotEmpty) {
          _liveQuizService.joinAllClassRooms(classProvider.classes);
        }
      });
    });
  }

  @override
  void dispose() {
    _liveQuizService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary600,
        unselectedItemColor: AppTheme.textTertiary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.class_outlined),
            activeIcon: Icon(Icons.class_),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Join',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: Icon(Icons.notifications),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
