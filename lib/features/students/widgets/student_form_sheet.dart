import 'package:flutter/material.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/repository_provider.dart';

/// Modal bottom sheet for creating or editing a student in the active class.
class StudentFormSheet extends StatefulWidget {
  final String classId;
  final StudentModel? initialStudent;

  const StudentFormSheet({
    super.key,
    required this.classId,
    this.initialStudent,
  });

  /// Displays the modal sheet and returns true if student was successfully saved.
  static Future<bool?> show(
    BuildContext context, {
    required String classId,
    StudentModel? student,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) =>
          StudentFormSheet(classId: classId, initialStudent: student),
    );
  }

  @override
  State<StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends State<StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rollController;
  late final TextEditingController _nameController;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialStudent != null;

  @override
  void initState() {
    super.initState();
    _rollController = TextEditingController(
      text: widget.initialStudent?.rollNumber ?? '',
    );
    _nameController = TextEditingController(
      text: widget.initialStudent?.name ?? '',
    );
  }

  @override
  void dispose() {
    _rollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repo = RepositoryProvider.of(context).studentRepository;
    final roll = _rollController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_isEditing) {
        final updated = widget.initialStudent!.copyWith(
          rollNumber: roll,
          name: name,
        );
        await repo.updateStudent(updated);
      } else {
        await repo.createStudent(
          classId: widget.classId,
          rollNumber: roll,
          name: name,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is DuplicateRollNumberException) {
          _errorMessage =
              'Roll number "$roll" is already assigned to a student in this class.';
        } else if (e is ValidationException) {
          _errorMessage = e.message;
        } else if (e is AppDatabaseException) {
          _errorMessage = 'Database error: ${e.message}';
        } else {
          _errorMessage = 'An unexpected error occurred while saving student. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Student' : 'Add New Student',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isEditing
                  ? 'Update student details. Roll numbers must be unique within this class.'
                  : 'Enroll a new student. Roll numbers are normalized and unique within this class.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

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

            // Roll Number Field
            AppTextField(
              controller: _rollController,
              labelText: 'Roll Number *',
              hintText: 'e.g., 01 or 2026/CS/01',
              prefixIcon: const Icon(Icons.tag_rounded, size: 20),
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Roll number is required.';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Student Full Name Field
            AppTextField(
              controller: _nameController,
              labelText: 'Full Name *',
              hintText: 'e.g., Aarav Sharma',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveStudent(),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Student name is required.';
                }
                if (trimmed.length < 2) {
                  return 'Please enter a valid student name.';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Submit Button
            AppButton.primary(
              label: _isEditing ? 'Save Changes' : 'Enroll Student',
              icon: _isEditing ? Icons.save_rounded : Icons.person_add_rounded,
              isFullWidth: true,
              height: 50,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveStudent,
            ),
          ],
        ),
      ),
    );
  }
}
