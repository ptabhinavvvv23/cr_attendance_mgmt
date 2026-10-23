import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ThemeExtension to provide semantic status colors via Theme.of(context).
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  final Color success;
  final Color successSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color error;
  final Color errorSubtle;
  final Color info;
  final Color infoSubtle;
  final Color neutral;
  final Color neutralSubtle;

  const AppStatusColors({
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.error,
    required this.errorSubtle,
    required this.info,
    required this.infoSubtle,
    required this.neutral,
    required this.neutralSubtle,
  });

  static const AppStatusColors light = AppStatusColors(
    success: AppColors.lightSuccess,
    successSubtle: AppColors.lightSuccessSubtle,
    warning: AppColors.lightWarning,
    warningSubtle: AppColors.lightWarningSubtle,
    error: AppColors.lightError,
    errorSubtle: AppColors.lightErrorSubtle,
    info: AppColors.lightInfo,
    infoSubtle: AppColors.lightInfoSubtle,
    neutral: AppColors.lightNeutral,
    neutralSubtle: AppColors.lightNeutralSubtle,
  );

  static const AppStatusColors dark = AppStatusColors(
    success: AppColors.darkSuccess,
    successSubtle: AppColors.darkSuccessSubtle,
    warning: AppColors.darkWarning,
    warningSubtle: AppColors.darkWarningSubtle,
    error: AppColors.darkError,
    errorSubtle: AppColors.darkErrorSubtle,
    info: AppColors.darkInfo,
    infoSubtle: AppColors.darkInfoSubtle,
    neutral: AppColors.darkNeutral,
    neutralSubtle: AppColors.darkNeutralSubtle,
  );

  Color forAttendance(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return success;
      case AttendanceStatus.absent:
        return error;
      case AttendanceStatus.late:
        return warning;
      case AttendanceStatus.leave:
        return info;
      case AttendanceStatus.unmarked:
        return neutral;
    }
  }

  Color subtleForAttendance(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return successSubtle;
      case AttendanceStatus.absent:
        return errorSubtle;
      case AttendanceStatus.late:
        return warningSubtle;
      case AttendanceStatus.leave:
        return infoSubtle;
      case AttendanceStatus.unmarked:
        return neutralSubtle;
    }
  }

  Color forBackup(BackupStatusState status) {
    switch (status) {
      case BackupStatusState.successful:
        return success;
      case BackupStatusState.pending:
        return warning;
      case BackupStatusState.failed:
        return error;
      case BackupStatusState.neverBackedUp:
        return neutral;
    }
  }

  Color subtleForBackup(BackupStatusState status) {
    switch (status) {
      case BackupStatusState.successful:
        return successSubtle;
      case BackupStatusState.pending:
        return warningSubtle;
      case BackupStatusState.failed:
        return errorSubtle;
      case BackupStatusState.neverBackedUp:
        return neutralSubtle;
    }
  }

  @override
  ThemeExtension<AppStatusColors> copyWith({
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? error,
    Color? errorSubtle,
    Color? info,
    Color? infoSubtle,
    Color? neutral,
    Color? neutralSubtle,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      error: error ?? this.error,
      errorSubtle: errorSubtle ?? this.errorSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      neutral: neutral ?? this.neutral,
      neutralSubtle: neutralSubtle ?? this.neutralSubtle,
    );
  }

  @override
  ThemeExtension<AppStatusColors> lerp(
    ThemeExtension<AppStatusColors>? other,
    double t,
  ) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSubtle: Color.lerp(errorSubtle, other.errorSubtle, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      neutralSubtle: Color.lerp(neutralSubtle, other.neutralSubtle, t)!,
    );
  }
}
