import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../widgets/student_form_sheet.dart';

/// Students screen displaying live database-backed student roster scoped to the active class.
/// Supports student enrollment, editing, searching by name or roll number, and soft deactivation.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  ClassModel? _activeClass;
  bool _isLoadingClass = true;
  bool _isLoadingStudents = false;
  String? _errorMessage;

  List<StudentModel> _students = [];
  String _searchQuery = '';
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initClassAndStudents();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Resolves the current CR and their active class, then loads the student roster.
  Future<void> _initClassAndStudents() async {
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
        await _fetchStudents();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingClass = false;
        _errorMessage = 'Failed to load class: $e';
      });
    }
  }

  /// Queries the StudentRepository scoped strictly to the current active class.
  Future<void> _fetchStudents() async {
    final activeClass = _activeClass;
    if (activeClass == null) return;

    setState(() {
      _isLoadingStudents = true;
      _errorMessage = null;
    });

    try {
      final studentRepo = RepositoryProvider.of(context).studentRepository;
      final query = _searchQuery.trim();

      List<StudentModel> results;
      if (query.isNotEmpty) {
        results = await studentRepo.searchStudents(
          activeClass.id,
          query,
          activeOnly: !_showInactive,
        );
      } else if (_showInactive) {
        results = await studentRepo.getAllStudentsByClass(activeClass.id);
      } else {
        results = await studentRepo.getActiveStudentsByClass(activeClass.id);
      }

      if (!mounted) return;
      setState(() {
        _students = results;
        _isLoadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStudents = false;
        _errorMessage = 'Failed to load students: $e';
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = val;
      });
      _fetchStudents();
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _fetchStudents();
  }

  void _toggleShowInactive(bool value) {
    setState(() {
      _showInactive = value;
    });
    _fetchStudents();
  }

  Future<void> _openAddStudentSheet() async {
    final activeClass = _activeClass;
    if (activeClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure an active class first.'),
        ),
      );
      return;
    }

    final saved = await StudentFormSheet.show(context, classId: activeClass.id);

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student enrolled successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _fetchStudents();
    }
  }

  Future<void> _openEditStudentSheet(StudentModel student) async {
    final activeClass = _activeClass;
    if (activeClass == null) return;

    final saved = await StudentFormSheet.show(
      context,
      classId: activeClass.id,
      student: student,
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student details updated successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _fetchStudents();
    }
  }

  Future<void> _confirmDeactivateStudent(StudentModel student) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Deactivate Student',
      message:
          'Are you sure you want to deactivate "${student.name}" (Roll #${student.rollNumber})?\n\n'
          'The student will no longer appear in active attendance sessions, but all historical '
          'attendance records will be safely preserved.',
      confirmLabel: 'Deactivate',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        final repo = RepositoryProvider.of(context).studentRepository;
        await repo.deactivateStudent(student.id);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${student.name} deactivated.')));
        _fetchStudents();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deactivate student: $e'),
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
              'Students (${_students.length})',
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
                  ? 'Showing all students'
                  : 'Showing active only',
              onPressed: () => _toggleShowInactive(!_showInactive),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              tooltip: 'Add Student',
              onPressed: _openAddStudentSheet,
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: _activeClass != null
          ? FloatingActionButton(
              onPressed: _openAddStudentSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Add Student',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(child: _buildBody(theme, isDark)),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    // 1. Initial Class Loading
    if (_isLoadingClass) {
      return const LoadingStateView(message: 'Loading class roster...');
    }

    // 2. Class Error
    if (_errorMessage != null && _activeClass == null) {
      return ErrorStateView(
        title: 'Unable to Load Class',
        message: _errorMessage!,
        onRetry: _initClassAndStudents,
      );
    }

    // 3. No Active Class Found
    if (_activeClass == null) {
      return const EmptyStateView(
        icon: Icons.school_outlined,
        title: 'No Active Class',
        description: 'Please complete your class profile configuration before managing student rosters.',
      );
    }

    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              AppTextField(
                controller: _searchController,
                hintText: 'Search by student name or roll number...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                onChanged: _onSearchChanged,
              ),
              if (_showInactive) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Showing active and deactivated students',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Student List View
        Expanded(child: _buildStudentList(theme, isDark)),
      ],
    );
  }

  Widget _buildStudentList(ThemeData theme, bool isDark) {
    if (_isLoadingStudents) {
      return const LoadingStateView(message: 'Fetching students...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Failed to Retrieve Students',
        message: _errorMessage!,
        onRetry: _fetchStudents,
      );
    }

    if (_students.isEmpty) {
      if (_searchQuery.trim().isNotEmpty) {
        return EmptyStateView(
          icon: Icons.person_search_rounded,
          title: 'No Students Found',
          description:
              'No students match "$_searchQuery". Check the roll number or clear your search query.',
          actionLabel: 'Clear Search',
          onAction: _clearSearch,
        );
      }

      return EmptyStateView(
        icon: Icons.group_outlined,
        title: 'No Students Enrolled',
        description:
            'No students have been added to ${_activeClass?.name ?? "this class"} yet. Start by enrolling your first student.',
        actionLabel: 'Add Student',
        onAction: _openAddStudentSheet,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchStudents,
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.xs,
          bottom: 88.0,
        ),
        itemCount: _students.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final student = _students[index];
          final isActive = student.isActive;

          return AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Roll Number Avatar Badge
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
                  child: Text(
                    student.rollNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isActive
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.darkNeutral
                                : AppColors.lightNeutral),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name & Roll subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
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
                          Text(
                            'Roll #${student.rollNumber}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Status Indicator Chip
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
                              isActive ? 'Active' : 'Inactive',
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
                      _openEditStudentSheet(student);
                    } else if (action == 'deactivate') {
                      _confirmDeactivateStudent(student);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    if (isActive)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 18,
                              color: AppColors.lightError,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Deactivate',
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
