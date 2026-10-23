import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cr_attendance_mgmt/main.dart';
import 'package:cr_attendance_mgmt/core/theme/theme_controller.dart';
import 'package:cr_attendance_mgmt/core/theme/app_colors.dart';
import 'package:cr_attendance_mgmt/features/shell/screens/app_shell.dart';
import 'package:cr_attendance_mgmt/features/attendance/screens/attendance_setup_screen.dart';
import 'package:cr_attendance_mgmt/routes/app_routes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Batch 1 Theme System Tests', () {
    test(
      'ThemeController defaults to system mode and updates correctly',
      () async {
        final controller = ThemeController();
        expect(controller.themeMode, equals(ThemeMode.system));
        expect(controller.isSystemMode, isTrue);

        await controller.setTheme(ThemeMode.dark);
        expect(controller.themeMode, equals(ThemeMode.dark));
        expect(controller.isDarkMode, isTrue);

        await controller.setTheme(ThemeMode.light);
        expect(controller.themeMode, equals(ThemeMode.light));
        expect(controller.isLightMode, isTrue);
      },
    );

    test(
      'AttendanceStatus enum provides non-color attributes (label and icon)',
      () {
        for (final status in AttendanceStatus.values) {
          expect(status.label.isNotEmpty, isTrue);
          expect(status.icon, isNotNull);
        }
      },
    );
  });

  group('Batch 1 App Shell & Navigation Tests', () {
    testWidgets('App launches with splash screen and branding', (
      WidgetTester tester,
    ) async {
      final controller = ThemeController();
      await tester.pumpWidget(MyApp(themeController: controller));

      // Initial frame renders splash screen
      expect(find.text('CR Attendance Management'), findsOneWidget);
      expect(
        find.text('Offline-first attendance & backup system'),
        findsOneWidget,
      );

      // Advance clock past splash delay to ensure clean timer disposal and navigation
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // Landed on AppShell Home tab
      expect(find.text('CS 2026 — Section A'), findsOneWidget);
    });

    testWidgets('AppShell navigates across all four bottom tabs', (
      WidgetTester tester,
    ) async {
      final controller = ThemeController();

      await tester.pumpWidget(
        ThemeControllerProvider(
          controller: controller,
          child: MaterialApp(
            home: const AppShell(),
            onGenerateRoute: AppRoutes.onGenerateRoute,
          ),
        ),
      );

      // 1. Initial tab is Home
      expect(find.text('CS 2026 — Section A'), findsOneWidget);
      expect(find.text('Mark Attendance Now'), findsOneWidget);

      // 2. Switch to Students tab
      await tester.tap(find.byIcon(Icons.people_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('Students ('), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);

      // 3. Switch to Reports tab
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Attendance Reports'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);

      // 4. Switch to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // 5. Test Live Theme Switching from Settings
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(controller.themeMode, equals(ThemeMode.dark));

      // 6. Switch back to Home tab
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      expect(find.text('CS 2026 — Section A'), findsOneWidget);
    });

    testWidgets('Attendance Session Setup and Roster flow works correctly', (
      WidgetTester tester,
    ) async {
      final controller = ThemeController();

      await tester.pumpWidget(
        ThemeControllerProvider(
          controller: controller,
          child: MaterialApp(
            home: const AttendanceSetupScreen(),
            onGenerateRoute: AppRoutes.onGenerateRoute,
          ),
        ),
      );

      // Verify Session Setup screen
      expect(find.text('Start Attendance Session'), findsOneWidget);
      expect(find.text('Configure Subject & Date'), findsOneWidget);
      expect(find.text('Open Attendance Roster'), findsOneWidget);

      // Navigate to Attendance Roster
      await tester.tap(find.text('Open Attendance Roster'));
      await tester.pumpAndSettle();

      // Verify Roster screen elements
      expect(find.text('Mark All Present'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);

      // Tap Mark All Present
      await tester.tap(find.text('Mark All Present'));
      await tester.pumpAndSettle();

      // Verify save button reflects updated count
      expect(
        find.textContaining('Save Attendance (10/10 Present)'),
        findsOneWidget,
      );

      // Save Attendance
      await tester.tap(find.textContaining('Save Attendance'));
      await tester.pumpAndSettle();

      // Roster pops back to session setup
      expect(find.text('Start Attendance Session'), findsOneWidget);
    });
  });
}
