import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared quiz status display helpers.
/// Consolidates duplicate logic from kelas_tab.dart and quiz_detail_screen.dart.

Color quizStatusColor(String status) {
  switch (status) {
    case 'open':
      return AppTheme.success;
    case 'scheduled':
      return AppTheme.warning;
    case 'closed':
    case 'finished':
      return AppTheme.error;
    default:
      return AppTheme.textTertiary;
  }
}

String quizStatusLabel(String status) {
  switch (status) {
    case 'draft':
      return 'DRAF';
    case 'scheduled':
      return 'TERJADWAL';
    case 'open':
      return 'TERBUKA';
    case 'closed':
      return 'DITUTUP';
    case 'waiting':
      return 'MENUNGGU';
    case 'in_progress':
      return 'BERLANGSUNG';
    case 'finished':
      return 'SELESAI';
    default:
      return status.toUpperCase();
  }
}

IconData quizTrailingIcon(String status) {
  switch (status) {
    case 'open':
      return Icons.arrow_forward_ios;
    case 'scheduled':
      return Icons.schedule;
    case 'closed':
      return Icons.lock_outline;
    default:
      return Icons.arrow_forward_ios;
  }
}

/// Score-band color: green ≥70%, orange ≥40%, red <40%
Color scoreBandColor(double? percentage) {
  if (percentage == null) return AppTheme.textTertiary;
  if (percentage >= 70) return AppTheme.success;
  if (percentage >= 40) return AppTheme.warning;
  return AppTheme.error;
}
