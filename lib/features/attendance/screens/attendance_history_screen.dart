import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/attendance_session_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

class _SessionListItemData {
  final AttendanceSessionModel session;
  final SubjectModel? subject;
  final int totalCount;
  final int presentCount;
  final int absentCount;

  _SessionListItemData({
    required this.session,
    required this.subject,
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
  });
}

/// Screen displaying all historical attendance sessions scoped to the active class.
/// Allows filtering by subject and search query, and allows opening any historical session
/// to review or update attendance records.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  ClassModel? _activeClass;
  List<SubjectModel> _subjects = [];
  String? _selectedSubjectId; // null means 'All Subjects'
  String _searchQuery = '';

  List<_SessionListItemData> _sessionItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            activeOnly: false,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _activeClass = activeClass;
        _subjects = subjects;
      });

      if (activeClass != null) {
        await _fetchSessions(activeClass, subjects);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load attendance history: $e';
      });
    }
  }

  Future<void> _fetchSessions(
    ClassModel activeClass,
    List<SubjectModel> subjects,
  ) async {
    final container = RepositoryProvider.of(context);
    final subjectMap = {for (final s in subjects) s.id: s};

    try {
      List<AttendanceSessionModel> rawSessions;
      if (_selectedSubjectId != null && _selectedSubjectId!.isNotEmpty) {
        rawSessions = await container.attendanceRepository.getSessionsBySubject(
          _selectedSubjectId!,
        );
        // Ensure class scoping
        rawSessions = rawSessions
            .where((s) => s.classId == activeClass.id)
            .toList();
      } else {
        rawSessions = await container.attendanceRepository.getSessionsByClass(
          activeClass.id,
        );
      }

      final items = <_SessionListItemData>[];
      for (final session in rawSessions) {
        final records = await container.attendanceRepository
            .getRecordsForSession(session.id);
        final presentCount = records
            .where((r) => r.status == AttendanceStatus.present)
            .length;
        final absentCount = records
            .where((r) => r.status == AttendanceStatus.absent)
            .length;

        items.add(
          _SessionListItemData(
            session: session,
            subject: subjectMap[session.subjectId],
            totalCount: records.length,
            presentCount: presentCount,
            absentCount: absentCount,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _sessionItems = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load attendance sessions: $e';
      });
    }
  }

  Future<void> _openSession(_SessionListItemData item) async {
    final activeClass = _activeClass;
    if (activeClass == null) return;

    final session = item.session;
    final subjectName = item.subject?.name ?? 'Subject';
    final subjectCode = item.subject?.code;

    final refreshed = await Navigator.of(context).pushNamed(
      AppRoutes.attendanceRoster,
      arguments: {
        'session': session,
        'sessionId': session.id,
        'subject': subjectName,
        'subjectCode': subjectCode,
        'date': session.parsedDate,
        'period': session.period,
        'classId': activeClass.id,
        'className': activeClass.name,
        'section': activeClass.section,
      },
    );

    if (refreshed == true && mounted && _activeClass != null) {
      _fetchSessions(_activeClass!, _subjects);
    }
  }

  String _formatSessionDate(DateTime date) {
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
              'Attendance History',
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
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Mark Attendance',
            onPressed: () async {
              await Navigator.of(context).pushNamed(AppRoutes.attendanceSetup);
              if (_activeClass != null) {
                _fetchSessions(_activeClass!, _subjects);
              }
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed(AppRoutes.attendanceSetup);
          if (_activeClass != null) {
            _fetchSessions(_activeClass!, _subjects);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Mark Session'),
      ),
      body: SafeArea(child: _buildBody(theme, isDark)),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading attendance history...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Unable to Load History',
        message: _errorMessage!,
        onRetry: _loadInitialData,
      );
    }

    final activeClass = _activeClass;
    if (activeClass == null) {
      return EmptyStateView(
        icon: Icons.school_outlined,
        title: 'No Active Class',
        description:
            'Please complete class setup before viewing attendance history.',
        actionLabel: 'Go to Class Setup',
        onAction: () => Navigator.pushNamed(context, AppRoutes.onboardingClass),
      );
    }

    final filteredItems = _sessionItems.where((item) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      final subjectName = (item.subject?.name ?? '').toLowerCase();
      final subjectCode = (item.subject?.code ?? '').toLowerCase();
      final dateStr = item.session.sessionDate.toLowerCase();
      final periodStr = item.session.period.toLowerCase();
      return subjectName.contains(q) ||
          subjectCode.contains(q) ||
          dateStr.contains(q) ||
          periodStr.contains(q);
    }).toList();

    return Column(
      children: [
        // Filter Controls Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              // Search input
              AppTextField(
                controller: _searchController,
                hintText: 'Search by subject, date, or period...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
              const SizedBox(height: AppSpacing.xs),

              // Subject filter chip row
              if (_subjects.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: const Text('All Subjects'),
                          selected: _selectedSubjectId == null,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedSubjectId = null;
                                _isLoading = true;
                              });
                              _fetchSessions(activeClass, _subjects);
                            }
                          },
                        ),
                      ),
                      ..._subjects.map((sub) {
                        final isSelected = _selectedSubjectId == sub.id;
                        final label = sub.code != null && sub.code!.isNotEmpty
                            ? sub.code!
                            : sub.name;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedSubjectId = selected ? sub.id : null;
                                _isLoading = true;
                              });
                              _fetchSessions(activeClass, _subjects);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Session List
        Expanded(
          child: filteredItems.isEmpty
              ? EmptyStateView(
                  icon: Icons.history_rounded,
                  title: _sessionItems.isEmpty
                      ? 'No Attendance Sessions'
                      : 'No Matching Sessions',
                  description: _sessionItems.isEmpty
                      ? 'No attendance sessions recorded for ${activeClass.name} yet. Mark your first session to see history.'
                      : 'No sessions match your search filter "$_searchQuery".',
                  actionLabel: _sessionItems.isEmpty
                      ? 'Mark First Session'
                      : 'Clear Filter',
                  onAction: () async {
                    if (_sessionItems.isEmpty) {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.attendanceSetup,
                      );
                      _loadInitialData();
                    } else {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedSubjectId = null;
                      });
                      _fetchSessions(activeClass, _subjects);
                    }
                  },
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchSessions(activeClass, _subjects),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      top: AppSpacing.sm,
                      bottom: 88.0,
                    ),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildSessionCard(context, item, isDark, theme);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    _SessionListItemData item,
    bool isDark,
    ThemeData theme,
  ) {
    final session = item.session;
    final subject = item.subject;
    final isCompleted = session.status.toUpperCase() == 'COMPLETED';

    final subjectTitle = subject != null
        ? (subject.code != null && subject.code!.isNotEmpty
              ? '${subject.name} (${subject.code})'
              : subject.name)
        : 'Unknown Subject';

    return AppCard(
      onTap: () => _openSession(item),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Subject Name & Status Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  subjectTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isDark
                            ? AppColors.darkSuccessSubtle
                            : AppColors.lightSuccessSubtle)
                      : (isDark
                            ? AppColors.darkNavSelected
                            : AppColors.lightNavSelected),
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
                child: Text(
                  isCompleted ? 'COMPLETED' : 'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isCompleted
                        ? (isDark
                              ? AppColors.darkSuccess
                              : AppColors.lightSuccess)
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Date & Period Info
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatSessionDate(session.parsedDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Period ${session.period}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),

          // Attendance Stat Summary & Chevron
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.totalCount > 0
                    ? '${item.presentCount}/${item.totalCount} Present · ${item.absentCount} Absent'
                    : 'No student records yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: item.totalCount > 0
                      ? (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary)
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Open Roster',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
