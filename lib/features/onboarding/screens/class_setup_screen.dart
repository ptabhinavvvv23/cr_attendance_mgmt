import 'package:flutter/material.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

/// Step 2 of Onboarding: Class Profile Setup.
/// Captures class name, academic year, section, and optional semester,
/// associating the class with the persisted CR owner ID through [ClassRepository].
class ClassSetupScreen extends StatefulWidget {
  final String? initialOwnerId;

  const ClassSetupScreen({super.key, this.initialOwnerId});

  @override
  State<ClassSetupScreen> createState() => _ClassSetupScreenState();
}

class _ClassSetupScreenState extends State<ClassSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _academicYearController = TextEditingController(text: '2026-2027');
  final _sectionController = TextEditingController(text: 'A');
  final _semesterController = TextEditingController();

  final List<String> _commonSemesters = [
    'None / Not Applicable',
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  late String _selectedSemester;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSemester = _commonSemesters.first;
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _academicYearController.dispose();
    _sectionController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _submitClassProfile() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final container = RepositoryProvider.of(context);
    final ownerRepo = container.ownerRepository;
    final classRepo = container.classRepository;

    try {
      // Resolve valid owner ID
      String? ownerId = widget.initialOwnerId;
      if (ownerId == null || ownerId.trim().isEmpty) {
        final currentOwner = await ownerRepo.getCurrentOwner();
        ownerId = currentOwner?.id;
      }

      if (ownerId == null) {
        throw ValidationException(
          'CR Owner profile was not found. Please complete Step 1 first.',
        );
      }

      final className = _classNameController.text.trim();
      final academicYear = _academicYearController.text.trim();
      final section = _sectionController.text.trim();
      final semester = _selectedSemester == 'None / Not Applicable'
          ? null
          : _selectedSemester.trim();

      // Persist class profile (createClass sets isActive = true by default)
      final createdClass = await classRepo.createClass(
        ownerId: ownerId,
        name: className,
        academicYear: academicYear,
        section: section,
        semester: semester,
      );

      // Ensure class is explicitly marked active
      await classRepo.activateClass(createdClass.id);

      if (!mounted) return;

      // Onboarding complete! Navigate to the main application shell
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.shell, (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is ValidationException) {
          _errorMessage = e.message;
        } else if (e is AppDatabaseException) {
          _errorMessage = 'Database error: ${e.message}';
        } else {
          _errorMessage =
              'An error occurred while saving class profile. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Profile Setup'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Indicator & Info Banner
                AppCard(
                  color: isDark
                      ? AppColors.darkElevatedSurface
                      : AppColors.lightSurface,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkNavSelected
                              : AppColors.lightNavSelected,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step 2 of 2: Class Details',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configure Your Class',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Define the cohort you represent as CR',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Error Banner if present
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkErrorSubtle
                          : AppColors.lightErrorSubtle,
                      borderRadius: AppSpacing.borderRadiusMd,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkError.withValues(alpha: 0.3)
                            : AppColors.lightError.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: isDark
                              ? AppColors.darkError
                              : AppColors.lightError,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkError
                                  : AppColors.lightError,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Form Fields Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Information',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'This information anchors student enrollment, subject definitions, and daily attendance sessions.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Class Name Field (Required)
                      AppTextField(
                        controller: _classNameController,
                        labelText: 'Class / Program Name *',
                        hintText: 'e.g., Computer Science & Engineering',
                        prefixIcon: const Icon(Icons.class_rounded, size: 20),
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          final trimmed = val?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Class name is required.';
                          }
                          if (trimmed.length < 3) {
                            return 'Class name must be at least 3 characters.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Academic Year & Section Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: AppTextField(
                              controller: _academicYearController,
                              labelText: 'Academic Year *',
                              hintText: 'e.g., 2026-2027',
                              prefixIcon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                              ),
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                              validator: (val) {
                                final trimmed = val?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Required.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _sectionController,
                              labelText: 'Section *',
                              hintText: 'e.g., A',
                              prefixIcon: const Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                              ),
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                              validator: (val) {
                                final trimmed = val?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Required.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Semester Dropdown
                      Text(
                        'Semester / Academic Period (Optional)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSemester,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.timeline_rounded, size: 20),
                        ),
                        items: _commonSemesters.map((sem) {
                          return DropdownMenuItem(
                            value: sem,
                            child: Text(sem, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _isSaving
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedSemester = val);
                                }
                              },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Save & Complete Button
                AppButton.primary(
                  label: 'Save & Launch Application',
                  icon: Icons.check_circle_rounded,
                  isFullWidth: true,
                  height: 52,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submitClassProfile,
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
