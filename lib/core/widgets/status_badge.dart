import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_status_colors.dart';

/// Accessible status badge for attendance and backup states.
/// Combines semantic colors, clear icons, and descriptive text.
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    this.isCompact = false,
  });

  /// Factory for attendance status badge
  factory StatusBadge.attendance(
    AttendanceStatus status,
    BuildContext context, {
    bool isCompact = false,
  }) {
    final statusColors =
        Theme.of(context).extension<AppStatusColors>() ?? AppStatusColors.light;
    return StatusBadge(
      label: status.label,
      icon: status.icon,
      foregroundColor: statusColors.forAttendance(status),
      backgroundColor: statusColors.subtleForAttendance(status),
      isCompact: isCompact,
    );
  }

  /// Factory for backup status badge
  factory StatusBadge.backup(
    BackupStatusState status,
    BuildContext context, {
    bool isCompact = false,
  }) {
    final statusColors =
        Theme.of(context).extension<AppStatusColors>() ?? AppStatusColors.light;
    return StatusBadge(
      label: status.label,
      icon: status.icon,
      foregroundColor: statusColors.forBackup(status),
      backgroundColor: statusColors.subtleForBackup(status),
      isCompact: isCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSpacing.xs : AppSpacing.sm,
        vertical: isCompact ? 2.0 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.borderRadiusFull,
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12.0 : 14.0, color: foregroundColor),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 11.0 : 12.0,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
