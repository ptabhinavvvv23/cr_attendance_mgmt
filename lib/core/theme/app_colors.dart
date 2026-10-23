import 'package:flutter/material.dart';

/// Centralized color palette and semantic tokens for the CR Attendance application.
/// Strictly conforms to the Batch 1 design specifications.
class AppColors {
  AppColors._();

  // Core Brand Palette
  static const Color primary = Color(0xFF355CDE);
  static const Color primaryHover = Color(0xFF2848B8);
  static const Color secondary = Color(0xFF5267A8);
  static const Color accent = Color(0xFF13A89E);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF182230);
  static const Color lightTextSecondary = Color(0xFF667085);
  static const Color lightDivider = Color(0xFFE4E7EC);
  static const Color lightNavSelected = Color(0xFFE9EFFF);
  static const Color lightCardShadow = Color(0x0A101828);

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF101522);
  static const Color darkSurface = Color(0xFF1A2233);
  static const Color darkElevatedSurface = Color(0xFF222D40);
  static const Color darkTextPrimary = Color(0xFFF2F4F7);
  static const Color darkTextSecondary = Color(0xFFAAB4C5);
  static const Color darkDivider = Color(0xFF344054);
  static const Color darkNavSelected = Color(0x33355CDE);
  static const Color darkCardShadow = Color(0x1F000000);

  // Semantic Status Colors - Light
  static const Color lightSuccess = Color(0xFF12B76A);
  static const Color lightSuccessSubtle = Color(0xFFECFDF3);
  static const Color lightWarning = Color(0xFFF79009);
  static const Color lightWarningSubtle = Color(0xFFFEF0C7);
  static const Color lightError = Color(0xFFF04438);
  static const Color lightErrorSubtle = Color(0xFFFEF3F2);
  static const Color lightInfo = Color(0xFF0BA5EC);
  static const Color lightInfoSubtle = Color(0xFFF0F9FF);
  static const Color lightNeutral = Color(0xFF667085);
  static const Color lightNeutralSubtle = Color(0xFFF2F4F7);

  // Semantic Status Colors - Dark
  static const Color darkSuccess = Color(0xFF32D583);
  static const Color darkSuccessSubtle = Color(0x2912B76A);
  static const Color darkWarning = Color(0xFFFEC84B);
  static const Color darkWarningSubtle = Color(0x29F79009);
  static const Color darkError = Color(0xFFFDA29B);
  static const Color darkErrorSubtle = Color(0x29F04438);
  static const Color darkInfo = Color(0xFF7CD4FD);
  static const Color darkInfoSubtle = Color(0x290BA5EC);
  static const Color darkNeutral = Color(0xFF98A2B3);
  static const Color darkNeutralSubtle = Color(0x29667085);

  // Attendance Status Helpers
  static Color statusColor(AttendanceStatus status, {required bool isDark}) {
    switch (status) {
      case AttendanceStatus.present:
        return isDark ? darkSuccess : lightSuccess;
      case AttendanceStatus.absent:
        return isDark ? darkError : lightError;
      case AttendanceStatus.late:
        return isDark ? darkWarning : lightWarning;
      case AttendanceStatus.leave:
        return isDark ? darkInfo : lightInfo;
      case AttendanceStatus.unmarked:
        return isDark ? darkNeutral : lightNeutral;
    }
  }

  static Color statusSubtleColor(
    AttendanceStatus status, {
    required bool isDark,
  }) {
    switch (status) {
      case AttendanceStatus.present:
        return isDark ? darkSuccessSubtle : lightSuccessSubtle;
      case AttendanceStatus.absent:
        return isDark ? darkErrorSubtle : lightErrorSubtle;
      case AttendanceStatus.late:
        return isDark ? darkWarningSubtle : lightWarningSubtle;
      case AttendanceStatus.leave:
        return isDark ? darkInfoSubtle : lightInfoSubtle;
      case AttendanceStatus.unmarked:
        return isDark ? darkNeutralSubtle : lightNeutralSubtle;
    }
  }
}

/// Core attendance marking states with textual labels and icons
/// ensuring color is NEVER the sole distinguishing factor.
enum AttendanceStatus {
  present('Present', Icons.check_circle_rounded),
  absent('Absent', Icons.cancel_rounded),
  late('Late', Icons.schedule_rounded),
  leave('Leave', Icons.event_busy_rounded),
  unmarked('Unmarked', Icons.radio_button_unchecked_rounded);

  final String label;
  final IconData icon;

  const AttendanceStatus(this.label, this.icon);
}

/// Backup synchronization state
enum BackupStatusState {
  neverBackedUp('Never Backed Up', Icons.cloud_off_rounded),
  pending('Backup Pending', Icons.cloud_queue_rounded),
  successful('Backup Successful', Icons.cloud_done_rounded),
  failed('Backup Failed', Icons.sync_problem_rounded);

  final String label;
  final IconData icon;

  const BackupStatusState(this.label, this.icon);
}
