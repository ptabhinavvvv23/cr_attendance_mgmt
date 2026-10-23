import 'package:flutter/material.dart';

import '../features/splash/screens/splash_screen.dart';
import '../features/shell/screens/app_shell.dart';
import '../features/onboarding/screens/cr_identity_screen.dart';
import '../features/onboarding/screens/class_setup_screen.dart';
import '../features/attendance/screens/attendance_setup_screen.dart';
import '../features/attendance/screens/attendance_roster_screen.dart';
import '../features/attendance/screens/attendance_history_screen.dart';
import '../features/subjects/screens/subjects_screen.dart';
import '../data/models/attendance_session_model.dart';

/// Centralized route definitions and generator.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String shell = '/shell';
  static const String onboardingOwner = '/onboarding/owner';
  static const String onboardingClass = '/onboarding/class';
  static const String attendanceSetup = '/attendance/setup';
  static const String attendanceRoster = '/attendance/roster';
  static const String attendanceHistory = '/attendance/history';
  static const String subjects = '/subjects';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case onboardingOwner:
        return MaterialPageRoute(
          builder: (_) => const CrIdentityScreen(),
          settings: settings,
        );

      case onboardingClass:
        final args = settings.arguments as Map<String, dynamic>?;
        final ownerId = args?['ownerId'] as String?;
        return MaterialPageRoute(
          builder: (_) => ClassSetupScreen(initialOwnerId: ownerId),
          settings: settings,
        );

      case shell:
        final initialTab = settings.arguments is int
            ? settings.arguments as int
            : 0;
        return MaterialPageRoute(
          builder: (_) => AppShell(initialIndex: initialTab),
          settings: settings,
        );

      case attendanceSetup:
        return MaterialPageRoute(
          builder: (_) => const AttendanceSetupScreen(),
          settings: settings,
        );

      case attendanceRoster:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => AttendanceRosterScreen(
            session: args['session'] as AttendanceSessionModel?,
            sessionId: args['sessionId'] as String?,
            subjectName:
                args['subject'] as String? ?? 'Data Structures & Algorithms',
            subjectCode: args['subjectCode'] as String?,
            sessionDate: args['date'] as DateTime? ?? DateTime.now(),
            period: args['period'] as String? ?? '1',
            classId: args['classId'] as String?,
            className: args['className'] as String?,
            section: args['section'] as String?,
          ),
          settings: settings,
        );

      case subjects:
        return MaterialPageRoute(
          builder: (_) => const SubjectsScreen(),
          settings: settings,
        );

      case attendanceHistory:
        return MaterialPageRoute(
          builder: (_) => const AttendanceHistoryScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }
}
