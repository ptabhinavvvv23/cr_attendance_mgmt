import 'package:flutter/material.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/repository_provider.dart';

/// Modal bottom sheet for creating or editing an academic subject in the active class.
class SubjectFormSheet extends StatefulWidget {
  final String classId;
  final SubjectModel? initialSubject;

  const SubjectFormSheet({
    super.key,
    required this.classId,
    this.initialSubject,
  });

  /// Displays the modal sheet and returns true if the subject was successfully saved.
  static Future<bool?> show(
    BuildContext context, {
    required String classId,
    SubjectModel? subject,
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
          SubjectFormSheet(classId: classId, initialSubject: subject),
    );
  }

  @override
  State<SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<SubjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialSubject != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialSubject?.name ?? '',
    );
    _codeController = TextEditingController(
      text: widget.initialSubject?.code ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _saveSubject() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repo = RepositoryProvider.of(context).subjectRepository;
    final name = _nameController.text.trim();
    final rawCode = _codeController.text.trim();
    final code = rawCode.isEmpty ? null : rawCode.toUpperCase();

    try {
      if (_isEditing) {
        final updated = widget.initialSubject!.copyWith(name: name, code: code);
        await repo.updateSubject(updated);
      } else {
        await repo.createSubject(
          classId: widget.classId,
          name: name,
          code: code,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is DuplicateEntityException) {
          _errorMessage =
              'A subject named "$name" already exists in this class.';
        } else if (e is ValidationException) {
          _errorMessage = e.message;
        } else if (e is AppDatabaseException) {
          _errorMessage = 'Database error: ${e.message}';
        } else {
          _errorMessage = 'An unexpected error occurred while saving subject. Please try again.';
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
                  _isEditing ? 'Edit Subject' : 'Add Subject',
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
              _isEditing ? 'Update curriculum subject title and course code.' : 'Add a new subject to this class curriculum for attendance tracking.',
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

            // Subject Name Field
            AppTextField(
              controller: _nameController,
              labelText: 'Subject Name *',
              hintText: 'e.g., Data Structures & Algorithms',
              prefixIcon: const Icon(Icons.book_outlined, size: 20),
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Subject name is required.';
                }
                if (trimmed.length < 2) {
                  return 'Subject name must be at least 2 characters.';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Subject Code Field (Optional)
            AppTextField(
              controller: _codeController,
              labelText: 'Subject Code (Optional)',
              hintText: 'e.g., CS301 or MATH202',
              prefixIcon: const Icon(Icons.code_rounded, size: 20),
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveSubject(),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isNotEmpty && trimmed.length > 20) {
                  return 'Code must be 20 characters or fewer.';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Submit Button
            AppButton.primary(
              label: _isEditing ? 'Save Changes' : 'Create Subject',
              icon: _isEditing ? Icons.save_rounded : Icons.add_rounded,
              isFullWidth: true,
              height: 50,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveSubject,
            ),
          ],
        ),
      ),
    );
  }
}
