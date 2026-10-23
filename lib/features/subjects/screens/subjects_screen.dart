import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../widgets/subject_form_sheet.dart';

/// Screen displaying all curriculum subjects scoped strictly to the current active class.
/// Provides capabilities to create, edit, and deactivate/archive subjects while safeguarding
/// historical attendance sessions.
class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  ClassModel? _activeClass;
  bool _isLoadingClass = true;
  bool _isLoadingSubjects = false;
  String? _errorMessage;

  List<SubjectModel> _subjects = [];
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initClassAndSubjects();
    });
  }

  Future<void> _initClassAndSubjects() async {
    if (!mounted) return;
    setState(() {
      _isLoadingClass = true;
      _errorMessage = null;
    });

    try {
      final container = RepositoryProvider.of(context);
      final owner = await container.ownerRepository.getCurrentOwner();

      ClassModel? activeClass;
      if (owner != null) {
        activeClass = await container.classRepository.getActiveClassForOwner(
          owner.id,
        );
      }

      if (!mounted) return;
      setState(() {
        _activeClass = activeClass;
        _isLoadingClass = false;
      });

      if (activeClass != null) {
        await _fetchSubjects();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingClass = false;
        _errorMessage = 'Failed to load class: $e';
      });
    }
  }

  Future<void> _fetchSubjects() async {
    final activeClass = _activeClass;
    if (activeClass == null) return;

    setState(() {
      _isLoadingSubjects = true;
      _errorMessage = null;
    });

    try {
      final subjectRepo = RepositoryProvider.of(context).subjectRepository;
      final results = await subjectRepo.getSubjectsByClass(
        activeClass.id,
        activeOnly: !_showInactive,
      );

      if (!mounted) return;
      setState(() {
        _subjects = results;
        _isLoadingSubjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSubjects = false;
        _errorMessage = 'Failed to load subjects: $e';
      });
    }
  }

  void _toggleShowInactive(bool value) {
    setState(() {
      _showInactive = value;
    });
    _fetchSubjects();
  }

  Future<void> _openAddSubjectSheet() async {
    final activeClass = _activeClass;
    if (activeClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure an active class first.'),
        ),
      );
      return;
    }

    final saved = await SubjectFormSheet.show(context, classId: activeClass.id);

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject added to curriculum successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _fetchSubjects();
    }
  }

  Future<void> _openEditSubjectSheet(SubjectModel subject) async {
    final activeClass = _activeClass;
    if (activeClass == null) return;

    final saved = await SubjectFormSheet.show(
      context,
      classId: activeClass.id,
      subject: subject,
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject updated successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _fetchSubjects();
    }
  }

  Future<void> _confirmDeactivateSubject(SubjectModel subject) async {
    final repo = RepositoryProvider.of(context).subjectRepository;
    bool hasHistory = false;
    try {
      hasHistory = await repo.hasHistoricalSessions(subject.id);
    } catch (_) {}

    if (!mounted) return;

    final String message = hasHistory
        ? 'Are you sure you want to archive "${subject.name}"?\n\n'
              'This subject has historical attendance sessions recorded. Archiving '
              'removes it from active attendance tracking, but all past records will remain safe and viewable in reports.'
        : 'Are you sure you want to deactivate "${subject.name}"?\n\n'
              'It will be hidden from new attendance sessions.';

    final confirmed = await ConfirmationDialog.show(
      context,
      title: hasHistory ? 'Archive Subject' : 'Deactivate Subject',
      message: message,
      confirmLabel: hasHistory ? 'Archive' : 'Deactivate',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await repo.deactivateSubject(subject.id);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${subject.name} deactivated.')));
        _fetchSubjects();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deactivate subject: $e'),
            backgroundColor: AppColors.lightError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subjects (${_subjects.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            if (_activeClass != null)
              Text(
                '${_activeClass!.name} · Sec ${_activeClass!.section}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          if (_activeClass != null) ...[
            IconButton(
              icon: Icon(
                _showInactive
                    ? Icons.visibility_rounded
                    : Icons.visibility_outlined,
                color: _showInactive ? AppColors.primary : null,
              ),
              tooltip: _showInactive
                  ? 'Showing all subjects'
                  : 'Showing active only',
              onPressed: () => _toggleShowInactive(!_showInactive),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Subject',
              onPressed: _openAddSubjectSheet,
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: _activeClass != null
          ? FloatingActionButton(
              onPressed: _openAddSubjectSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Add Subject',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(child: _buildBody(theme, isDark)),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoadingClass) {
      return const LoadingStateView(message: 'Loading curriculum subjects...');
    }

    if (_errorMessage != null && _activeClass == null) {
      return ErrorStateView(
        title: 'Unable to Load Class',
        message: _errorMessage!,
        onRetry: _initClassAndSubjects,
      );
    }

    if (_activeClass == null) {
      return const EmptyStateView(
        icon: Icons.school_outlined,
        title: 'No Active Class',
        description: 'Please complete your class profile configuration before managing subjects.',
      );
    }

    if (_isLoadingSubjects) {
      return const LoadingStateView(message: 'Fetching subjects...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Failed to Retrieve Subjects',
        message: _errorMessage!,
        onRetry: _fetchSubjects,
      );
    }

    if (_subjects.isEmpty) {
      return EmptyStateView(
        icon: Icons.menu_book_outlined,
        title: 'No Subjects Found',
        description: _showInactive
            ? 'No subjects configured for ${_activeClass!.name}.'
            : 'No active subjects configured for ${_activeClass!.name}. Add curriculum subjects to begin taking attendance.',
        actionLabel: 'Add First Subject',
        onAction: _openAddSubjectSheet,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSubjects,
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: 88.0,
        ),
        itemCount: _subjects.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          final isActive = subject.isActive;

          return AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Subject Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDark
                              ? AppColors.darkNavSelected
                              : AppColors.lightNavSelected)
                        : (isDark
                              ? AppColors.darkNeutralSubtle
                              : AppColors.lightNeutralSubtle),
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: isActive
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.darkNeutral
                              : AppColors.lightNeutral),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name & Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary)
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          decoration: isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (subject.code != null &&
                              subject.code!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkDivider
                                    : AppColors.lightDivider,
                                borderRadius: AppSpacing.borderRadiusSm,
                              ),
                              child: Text(
                                subject.code!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isDark
                                        ? AppColors.darkSuccessSubtle
                                        : AppColors.lightSuccessSubtle)
                                  : (isDark
                                        ? AppColors.darkNeutralSubtle
                                        : AppColors.lightNeutralSubtle),
                              borderRadius: AppSpacing.borderRadiusFull,
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Archived',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? (isDark
                                          ? AppColors.darkSuccess
                                          : AppColors.lightSuccess)
                                    : (isDark
                                          ? AppColors.darkNeutral
                                          : AppColors.lightNeutral),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  tooltip: 'Options',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openEditSubjectSheet(subject);
                    } else if (action == 'deactivate') {
                      _confirmDeactivateSubject(subject);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Edit Subject'),
                        ],
                      ),
                    ),
                    if (isActive)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Row(
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              size: 18,
                              color: AppColors.lightError,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Archive Subject',
                              style: TextStyle(color: AppColors.lightError),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
