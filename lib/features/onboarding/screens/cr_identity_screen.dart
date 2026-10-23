import 'package:flutter/material.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/owner_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

/// Step 1 of Onboarding: CR Identity and Local Owner Setup.
/// Captures the Class Representative's registration number and display name,
/// persisting the identity to SQLite through [OwnerRepository].
class CrIdentityScreen extends StatefulWidget {
  const CrIdentityScreen({super.key});

  @override
  State<CrIdentityScreen> createState() => _CrIdentityScreenState();
}

class _CrIdentityScreenState extends State<CrIdentityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _regNoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitCrIdentity() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repo = RepositoryProvider.of(context).ownerRepository;
    final regNo = _regNoController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      // Avoid duplicate owner identities if user revisits or retries
      final existingOwner = await repo.getCurrentOwner();
      final OwnerModel savedOwner;

      if (existingOwner != null) {
        final updated = existingOwner.copyWith(
          registrationNumber: regNo,
          displayName: name.isEmpty ? null : name,
          email: email.isEmpty ? null : email,
          updatedAt: DateTime.now(),
        );
        savedOwner = await repo.updateOwner(updated);
      } else {
        savedOwner = await repo.createOwner(
          registrationNumber: regNo,
          displayName: name.isEmpty ? null : name,
          email: email.isEmpty ? null : email,
        );
      }

      if (!mounted) return;

      // Navigate to Step 2: Class Setup
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.onboardingClass,
        arguments: {'ownerId': savedOwner.id},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is ValidationException) {
          _errorMessage = e.message;
        } else if (e is AppDatabaseException) {
          _errorMessage = 'Database error: ${e.message}';
        } else {
          _errorMessage = 'An unexpected error occurred while saving your profile. Please try again.';
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
        title: const Text('CR Onboarding'),
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
                // Step Indicator & Welcome Banner
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
                          Icons.badge_rounded,
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
                              'Step 1 of 2: CR Profile',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Class Representative Setup',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Anchors your local attendance data & backups',
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
                        'Identity Information',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Please enter your institutional registration ID and full name. This references all records created on this device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Registration Number Field (Required)
                      AppTextField(
                        controller: _regNoController,
                        labelText: 'Registration / Roll Number *',
                        hintText: 'e.g., 2026/CS/042 or REG1089',
                        prefixIcon: const Icon(
                          Icons.assignment_ind_rounded,
                          size: 20,
                        ),
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Registration number is required.';
                          }
                          if (trimmed.length < 2) {
                            return 'Registration number must be at least 2 characters.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Full Name Field (Required)
                      AppTextField(
                        controller: _nameController,
                        labelText: 'CR Full Name *',
                        hintText: 'e.g., Abhinav Patel',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Full name is required.';
                          }
                          if (trimmed.length < 2) {
                            return 'Please enter a valid name.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Email Field (Optional)
                      AppTextField(
                        controller: _emailController,
                        labelText: 'Email Address (Optional)',
                        hintText: 'e.g., cr.cs2026@college.edu',
                        prefixIcon: const Icon(
                          Icons.alternate_email_rounded,
                          size: 20,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitCrIdentity(),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isNotEmpty) {
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!emailRegex.hasMatch(trimmed)) {
                              return 'Please enter a valid email format.';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                AppButton.primary(
                  label: 'Continue to Class Setup',
                  icon: Icons.arrow_forward_rounded,
                  isFullWidth: true,
                  height: 52,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submitCrIdentity,
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
