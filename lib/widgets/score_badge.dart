import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScoreBadge extends StatelessWidget {
  final String text;
  final bool isHigh;
  final bool isMid;
  final bool isLow;

  const ScoreBadge({
    super.key,
    required this.text,
    this.isHigh = true,
    this.isMid = false,
    this.isLow = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppTheme.primary50;
    Color fgColor = AppTheme.primary600;

    if (isLow) {
      bgColor = const Color(0xFFFEE2E2); // red-100
      fgColor = const Color(0xFFB91C1C); // red-700
    } else if (isMid) {
      bgColor = const Color(0xFFFEF3C7); // yellow-100
      fgColor = const Color(0xFFB45309); // yellow-700
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fgColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
