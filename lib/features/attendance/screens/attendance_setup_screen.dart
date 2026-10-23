import 'package:flutter/material.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/attendance_session_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

/// Attendance Session Setup screen allowing subject selection, date choice, and period specification.
/// Validates active class and subjects from SQLite, prevents duplicate sessions, and initializes
/// or retrieves the persisted attendance session before opening the roster.
class AttendanceSetupScreen extends StatefulWidget {
  const AttendanceSetupScreen({super.key});

  @override
  State<AttendanceSetupScreen> createState() => _AttendanceSetupScreenState();
}

class _AttendanceSetupScreenState extends State<AttendanceSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _periodController = TextEditingController(
    text: '1',
  );

  ClassModel? _activeClass;
  List<SubjectModel> _subjects = [];
  SubjectModel? _selectedSubject;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isStarting = false;
  String? _errorMessage;

  static const List<String> _suggestedPeriods = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    'Lab',
    'Tutorial',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = RepositoryProvider.of(context);
      final owner = await container.ownerRepository.getCurrentOwner();

      ClassModel? activeClass;
      List<SubjectModel> subjects = [];

      if (owner != null) {
        activeClass = await container.classRepository.getActiveClassForOwner(
          owner.id,
        );
        if (activeClass != null) {
          subjects = await container.subjectRepository.getSubjectsByClass(
            activeClass.id,
            activeOnly: true,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _activeClass = activeClass;
        _subjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load class configuration: $e';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: now.add(const Duration(days: 7)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDisplayDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = months[date.month - 1];
    final weekdayStr = weekdays[date.weekday - 1];
    return '$weekdayStr, $dayStr $monthStr ${date.year}';
  }

  Future<void> _startAttendanceSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final activeClass = _activeClass;
    final subject = _selectedSubject;
    if (activeClass == null || subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active subject to proceed.'),
        ),
      );
      return;
    }

    final cleanPeriod = _periodController.text.trim();
    final attendanceRepo = RepositoryProvider.of(context).attendanceRepository;

    setState(() {
      _isStarting = true;
    });

    try {
      // 1. Check if a session for this class, subject, date, and period already exists
      final existingSession = await attendanceRepo.findExistingSession(
        classId: activeClass.id,
        subjectId: subject.id,
        sessionDate: _selectedDate,
        period: cleanPeriod,
      );

      if (!mounted) return;

      if (existingSession != null) {
        // Duplicate session detected: prompt user to resume/open the existing session
        final records = await attendanceRepo.getRecordsForSession(
          existingSession.id,
        );

        if (!mounted) return;
        setState(() {
          _isStarting = false;
        });

        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Session Already Exists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'An attendance session for ${subject.name} on '
                    '${AttendanceSessionModel.formatDate(_selectedDate)} (Period $cleanPeriod) '
                    'already exists in this class.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkNavSelected
                          : AppColors.lightNavSelected,
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${existingSession.status}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          records.isNotEmpty
                              ? '${records.length} student records previously recorded'
                              : 'No student records saved yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Would you like to open and view the existing session, or cancel to change the period or date?',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                AppButton.text(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(ctx).pop(false),
                  height: 38,
                ),
                AppButton.primary(
                  label: 'Open Existing Session',
                  onPressed: () => Navigator.of(ctx).pop(true),
                  height: 38,
                ),
              ],
            );
          },
        );

        if (resume == true && mounted) {
          _navigateToRoster(existingSession);
        }
        return;
      }

      // 2. No duplicate session: persist newly initialized session record in SQLite
      final newSession = await attendanceRepo.createSession(
        classId: activeClass.id,
        subjectId: subject.id,
        sessionDate: _selectedDate,
        period: cleanPeriod,
        status: 'SCHEDULED',
      );

      if (!mounted) return;
      setState(() {
        _isStarting = false;
      });

      _navigateToRoster(newSession);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
      });

      if (e is DuplicateSessionException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A session with this subject, date, and period was just created.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize session: $e'),
            backgroundColor: AppColors.lightError,
          ),
        );
      }
    }
  }

  void _navigateToRoster(AttendanceSessionModel session) {
    Navigator.of(context).pushNamed(
      AppRoutes.attendanceRoster,
      arguments: {
        'session': session,
        'sessionId': session.id,
        'subject': _selectedSubject!.name,
        'subjectCode': _selectedSubject!.code,
        'subjectId': _selectedSubject!.id,
        'date': _selectedDate,
        'period': session.period,
        'classId': _activeClass!.id,
        'className': _activeClass!.name,
        'section': _activeClass!.section,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Start Attendance Session',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody(theme, isDark)),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading session setup...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Unable to Load Session Setup',
        message: _errorMessage!,
        onRetry: _loadInitialData,
      );
    }

    final activeClass = _activeClass;
    if (activeClass == null) {
      return EmptyStateView(
        icon: Icons.school_outlined,
        title: 'No Active Class',
        description: 'Please complete your class profile configuration before starting attendance sessions.',
        actionLabel: 'Go to Class Setup',
        onAction: () async {
          await Navigator.pushNamed(context, AppRoutes.onboardingClass);
          _loadInitialData();
        },
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator & Class Header
                  AppCard(
                    color: isDark
                        ? AppColors.darkElevatedSurface
                        : AppColors.lightSurface,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkNavSelected
                                : AppColors.lightNavSelected,
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                          child: const Icon(
                            Icons.edit_calendar_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activeClass.name} · Sec ${activeClass.section}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Step 1 of 2: Configure Session',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (activeClass.semester != null)
                                Text(
                                  activeClass.semester!,
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

                  // If no active subjects exist, show prompt to manage subjects
                  if (_subjects.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkWarningSubtle
                            : AppColors.lightWarningSubtle,
                        borderRadius: AppSpacing.borderRadiusMd,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkWarning.withValues(alpha: 0.3)
                              : AppColors.lightWarning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: isDark
                                    ? AppColors.darkWarning
                                    : AppColors.lightWarning,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'No Curriculum Subjects Configured',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkWarning
                                      : AppColors.lightWarning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'To start taking attendance, add at least one subject to ${activeClass.name}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton.secondary(
                            label: 'Manage Curriculum Subjects',
                            icon: Icons.menu_book_rounded,
                            height: 40,
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                AppRoutes.subjects,
                              );
                              _loadInitialData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Form Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Subject Dropdown
                          Text(
                            'Select Subject *',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<SubjectModel>(
                            initialValue: _selectedSubject,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.book_rounded, size: 20),
                            ),
                            items: _subjects.map((sub) {
                              final label =
                                  sub.code != null && sub.code!.isNotEmpty
                                  ? '${sub.name} (${sub.code})'
                                  : sub.name;
                              return DropdownMenuItem<SubjectModel>(
                                value: sub,
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSubject = val);
                              }
                            },
                            validator: (val) {
                              if (val == null) {
                                return 'Please select a subject.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // 2. Attendance Date Picker
                          Text(
                            'Attendance Date *',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: AppSpacing.borderRadiusMd,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 20,
                                ),
                                suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                              ),
                              child: Text(
                                _formatDisplayDate(_selectedDate),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // 3. Period Specification
                          Text(
                            'Lecture Period / Slot *',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppTextField(
                            controller: _periodController,
                            hintText: 'e.g. 1, 2, Lab, or Morning',
                            prefixIcon: const Icon(
                              Icons.schedule_rounded,
                              size: 20,
                            ),
                            textInputAction: TextInputAction.done,
                            validator: (val) {
                              final trimmed = val?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'Period cannot be empty.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.xs),

                          // Quick Period Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _suggestedPeriods.map((period) {
                                final isSelected =
                                    _periodController.text.trim() == period;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.xs,
                                  ),
                                  child: ChoiceChip(
                                    label: Text('Period $period'),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _periodController.text = period;
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action
          if (_subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton.primary(
                label: 'Open Attendance Roster',
                icon: Icons.checklist_rounded,
                isFullWidth: true,
                height: 52,
                isLoading: _isStarting,
                onPressed: _isStarting ? null : _startAttendanceSession,
              ),
            ),
        ],
      ),
    );
  }
}
