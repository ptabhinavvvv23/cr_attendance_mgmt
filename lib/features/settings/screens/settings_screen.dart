import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';

import '../../../data/models/class_model.dart';
import '../../../data/models/owner_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

/// Settings tab screen foundation supporting live theme switching and configuration sections.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  OwnerModel? _owner;
  ClassModel? _classModel;
  int? _activeSubjectCount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    try {
      final container = RepositoryProvider.of(context);
      final owner = await container.ownerRepository.getCurrentOwner();
      ClassModel? activeClass;
      int? subjectCount;
      if (owner != null) {
        activeClass = await container.classRepository.getActiveClassForOwner(
          owner.id,
        );
        if (activeClass != null) {
          final subjects = await container.subjectRepository.getSubjectsByClass(
            activeClass.id,
            activeOnly: true,
          );
          subjectCount = subjects.length;
        }
      }
      if (!mounted) return;
      setState(() {
        _owner = owner;
        _classModel = activeClass;
        _activeSubjectCount = subjectCount;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNotice(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeController = ThemeControllerProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // 1. APPEARANCE (LIVE THEME SWITCHING)
              // -------------------------------------------------------------
              const SectionHeader(
                title: 'Appearance',
                subtitle: 'Choose your preferred app theme',
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded, size: 18),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded, size: 18),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded, size: 18),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {themeController.themeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          themeController.setTheme(newSelection.first);
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      themeController.isSystemMode
                          ? 'Follows your device system display settings automatically.'
                          : (themeController.isLightMode
                                ? 'Light theme: clean, bright surface with royal blue primary accents.'
                                : 'Dark theme: deep navy surfaces (#101522) tailored for low-light environments.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // -------------------------------------------------------------
              // 2. CLASS PROFILE
              // -------------------------------------------------------------
              SectionHeader(
                title: 'CR & Class Profile',
                subtitle: 'Active institutional identity & class parameters',
                trailing: AppButton.text(
                  label: 'Edit',
                  onPressed: () async {
                    await Navigator.of(context).pushNamed(
                      AppRoutes.onboardingClass,
                      arguments: {'ownerId': _owner?.id},
                    );
                    _loadProfileData();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                child: Column(
                  children: [
                    _buildSettingsRow(
                      context,
                      icon: Icons.badge_outlined,
                      title: 'CR Name',
                      value:
                          _owner?.displayName ??
                          (_isLoading ? 'Loading...' : 'Not Set'),
                    ),
                    const Divider(height: AppSpacing.md),
                    _buildSettingsRow(
                      context,
                      icon: Icons.assignment_ind_outlined,
                      title: 'Registration ID',
                      value:
                          _owner?.registrationNumber ??
                          (_isLoading ? 'Loading...' : 'Not Set'),
                    ),
                    const Divider(height: AppSpacing.md),
                    _buildSettingsRow(
                      context,
                      icon: Icons.school_outlined,
                      title: 'Class Name',
                      value:
                          _classModel?.name ??
                          (_isLoading ? 'Loading...' : 'Not Configured'),
                    ),
                    const Divider(height: AppSpacing.md),
                    _buildSettingsRow(
                      context,
                      icon: Icons.calendar_today_outlined,
                      title: 'Academic Year',
                      value:
                          _classModel?.academicYear ??
                          (_isLoading ? 'Loading...' : 'Not Configured'),
                    ),
                    const Divider(height: AppSpacing.md),
                    _buildSettingsRow(
                      context,
                      icon: Icons.groups_outlined,
                      title: 'Section',
                      value: _classModel != null
                          ? 'Section ${_classModel!.section}'
                          : (_isLoading ? 'Loading...' : 'Not Configured'),
                    ),
                    if (_classModel?.semester != null) ...[
                      const Divider(height: AppSpacing.md),
                      _buildSettingsRow(
                        context,
                        icon: Icons.timeline_outlined,
                        title: 'Semester',
                        value: _classModel!.semester!,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // -------------------------------------------------------------
              // 3. SUBJECTS MANAGEMENT
              // -------------------------------------------------------------
              const SectionHeader(
                title: 'Curriculum & Subjects',
                subtitle: 'Subjects configured for this class',
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                onTap: () async {
                  await Navigator.of(context).pushNamed(AppRoutes.subjects);
                  _loadProfileData();
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeSubjectCount != null
                                ? 'Manage Subjects ($_activeSubjectCount active)'
                                : 'Manage Subjects',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            'Add, edit, or archive curriculum subjects',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // -------------------------------------------------------------
              // 4. DATA & BACKUP
              // -------------------------------------------------------------
              const SectionHeader(
                title: 'Data & Backup',
                subtitle: 'Cloud safety and recovery integration',
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.cloud_sync_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Google Drive Account'),
                      subtitle: const Text(
                        'Not connected (Local offline mode active)',
                      ),
                      trailing: AppButton.secondary(
                        label: 'Connect',
                        height: 36,
                        onPressed: () => _showNotice(
                          context,
                          'Google Sign-In (Batch 9)',
                          'Google OAuth and Drive backup integration will be wired in Batch 9 (Google Drive Integration).',
                        ),
                      ),
                    ),
                    const Divider(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Manual Backup'),
                      subtitle: const Text('Export a signed snapshot package'),
                      trailing: AppButton.secondary(
                        label: 'Backup Now',
                        height: 36,
                        onPressed: () => _showNotice(
                          context,
                          'Manual Backup (Batch 8)',
                          'Generating standalone backup packages will be integrated in Batch 8.',
                        ),
                      ),
                    ),
                    const Divider(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restore_page_outlined),
                      title: const Text('Restore from Backup'),
                      subtitle: const Text(
                        'Reconstruct local database from backup file',
                      ),
                      trailing: AppButton.secondary(
                        label: 'Restore',
                        height: 36,
                        onPressed: () => _showNotice(
                          context,
                          'Restore Flow (Batch 10)',
                          'Database reconstruction and safe staging validation will be implemented in Batch 10.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // -------------------------------------------------------------
              // 5. APPLICATION INFO
              // -------------------------------------------------------------
              const SectionHeader(
                title: 'Application Information',
                subtitle: 'Version and system metadata',
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                child: Column(
                  children: [
                    _buildSettingsRow(
                      context,
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      value: '1.0.0 (Build 1)',
                    ),
                    const Divider(height: AppSpacing.md),
                    _buildSettingsRow(
                      context,
                      icon: Icons.badge_outlined,
                      title: 'Designed For',
                      value: 'Class Representatives (Offline First)',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSettingsRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
