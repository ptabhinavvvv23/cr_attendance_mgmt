import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

/// Application splash screen preserving existing project branding while utilizing
/// the centralized design system and navigating smoothly to onboarding or the main shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    setState(() {
      _initializationError = null;
    });

    final stopwatch = Stopwatch()..start();
    String targetRoute = AppRoutes.onboardingOwner;
    Map<String, dynamic>? targetArgs;

    try {
      // 1. Initialize local SQLite database
      await AppDatabase.instance.database;

      if (!mounted) return;

      // 2. Query CR identity existence
      final container = RepositoryProvider.of(context);
      final currentOwner = await container.ownerRepository.getCurrentOwner();

      if (currentOwner == null) {
        // No CR identity -> Route to Step 1: CR Onboarding
        targetRoute = AppRoutes.onboardingOwner;
      } else {
        // 3. Query active class existence
        final activeClass = await container.classRepository
            .getActiveClassForOwner(currentOwner.id);
        if (activeClass == null) {
          // CR exists but no active class -> Route to Step 2: Class Setup
          targetRoute = AppRoutes.onboardingClass;
          targetArgs = {'ownerId': currentOwner.id};
        } else {
          // Both CR identity and active class exist -> Main shell
          targetRoute = AppRoutes.shell;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializationError = 'Database initialization failed: $e';
      });
      return;
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    final remaining = 1200 - elapsed;
    if (remaining > 0) {
      _timer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) {
          Navigator.of(context)
              .pushReplacementNamed(targetRoute, arguments: targetArgs);
        }
      });
    } else if (mounted) {
      Navigator.of(context)
          .pushReplacementNamed(targetRoute, arguments: targetArgs);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_initializationError != null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: SafeArea(
          child: Center(
            child: ErrorStateView(
              title: 'Database Initialization Error',
              message:
                  'The application was unable to open the local database. Please tap retry to attempt reinitialization.\n\nDetails: $_initializationError',
              retryLabel: 'Retry Initialization',
              onRetry: _initializeApp,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkNavSelected
                      : AppColors.lightNavSelected,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'CR Attendance Management',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Offline-first attendance & backup system',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
