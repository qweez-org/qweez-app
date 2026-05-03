import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../theme/app_theme.dart';
import 'in_class_tabs/kelas_tab.dart';
import 'in_class_tabs/informasi_tab.dart';
import 'in_class_tabs/riwayat_tab.dart';
import 'in_class_tabs/nilai_tab.dart';

class InClassShellScreen extends StatefulWidget {
  final ClassModel classData;

  const InClassShellScreen({super.key, required this.classData});

  @override
  State<InClassShellScreen> createState() => _InClassShellScreenState();
}

class _InClassShellScreenState extends State<InClassShellScreen> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      KelasTab(classData: widget.classData),
      InformasiTab(classData: widget.classData),
      RiwayatTab(classData: widget.classData),
      NilaiTab(classData: widget.classData),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Kelas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            activeIcon: Icon(Icons.info),
            label: 'Informasi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            activeIcon: Icon(Icons.leaderboard),
            label: 'Nilai',
          ),
        ],
      ),
    );
  }
}
