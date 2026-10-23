import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/owner_model.dart';
import '../../../data/models/attendance_session_model.dart';
import '../../../data/models/attendance_stats_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../routes/app_routes.dart';

/// Home Dashboard screen displaying live CR identity and active class profile
/// loaded from SQLite via [OwnerRepository] and [ClassRepository].
class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const HomeScreen({super.key, this.onSwitchTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  OwnerModel? _currentOwner;
  ClassModel? _activeClass;
  List<AttendanceSessionModel> _recentSessions = [];
  Map<String, SubjectModel> _subjectsMap = {};
  ClassAttendanceReport? _classReport;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = RepositoryProvider.of(context);
      final owner = await container.ownerRepository.getCurrentOwner();

      ClassModel? activeClass;
      List<AttendanceSessionModel> recentSessions = [];
      Map<String, SubjectModel> subjectsMap = {};
      ClassAttendanceReport? classReport;

      if (owner != null) {
        activeClass = await container.classRepository.getActiveClassForOwner(
          owner.id,
        );
        if (activeClass != null) {
          recentSessions = await container.attendanceRepository
              .getSessionsByClass(activeClass.id, limit: 4);
          final subjects = await container.subjectRepository.getSubjectsByClass(
            activeClass.id,
            activeOnly: false,
          );
          subjectsMap = {for (final s in subjects) s.id: s};
          classReport = await container.attendanceRepository
              .getClassAttendanceReport(classId: activeClass.id);
        }
      }

      if (!mounted) return;
      setState(() {
        _currentOwner = owner;
        _activeClass = activeClass;
        _recentSessions = recentSessions;
        _subjectsMap = subjectsMap;
        _classReport = classReport;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load class information: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final dateString = _formatCurrentDate(now);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CR Attendance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              dateString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => widget.onSwitchTab?.call(3),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Live Class & CR Banner Card
                _buildClassBanner(context, isDark, theme),

                const SizedBox(height: AppSpacing.md),

                // 2. Attendance Overview Statistics Card
                if (_activeClass != null && !_isLoading) ...[
                  _buildAttendanceOverview(context, isDark, theme),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 3. Backup Status Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cloud Backup Status',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          StatusBadge.backup(
                            BackupStatusState.neverBackedUp,
                            context,
                            isCompact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Local attendance database is active and ready for offline use. Link your Google account in Settings to enable automated backups.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () => widget.onSwitchTab?.call(3),
                        borderRadius: AppSpacing.borderRadiusSm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Configure Drive Backup in Settings',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // 3. Primary Action: Mark Attendance
                const SectionHeader(
                  title: 'Quick Actions',
                  subtitle: 'Daily attendance tasks',
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton.primary(
                  label: 'Mark Attendance Now',
                  icon: Icons.checklist_rounded,
                  isFullWidth: true,
                  height: 52,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.attendanceSetup);
                  },
                ),

                const SizedBox(height: AppSpacing.sm),

                // 4. Secondary Actions
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Students',
                        icon: Icons.person_add_outlined,
                        height: 44,
                        onPressed: () => widget.onSwitchTab?.call(1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Reports',
                        icon: Icons.analytics_outlined,
                        height: 44,
                        onPressed: () => widget.onSwitchTab?.call(2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 5. Recent Activity Section
                SectionHeader(
                  title: 'Recent Sessions',
                  subtitle: 'History of attendance marked on this device',
                  trailing: AppButton.text(
                    label: 'View All',
                    onPressed: () async {
                      await Navigator.of(context)
                          .pushNamed(AppRoutes.attendanceHistory);
                      _loadDashboardData();
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                if (_recentSessions.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                      horizontal: AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkNavSelected
                                : AppColors.lightNavSelected,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history_toggle_off_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No Sessions Recorded Yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Attendance records will appear here after you save your first session.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentSessions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final session = _recentSessions[index];
                      final subject = _subjectsMap[session.subjectId];
                      final isCompleted =
                          session.status.toUpperCase() == 'COMPLETED';

                      final subjectTitle = subject != null
                          ? (subject.code != null && subject.code!.isNotEmpty
                                ? '${subject.name} (${subject.code})'
                                : subject.name)
                          : 'Subject';

                      return AppCard(
                        onTap: () async {
                          final activeClass = _activeClass;
                          if (activeClass == null) return;
                          await Navigator.of(context).pushNamed(
                            AppRoutes.attendanceRoster,
                            arguments: {
                              'session': session,
                              'sessionId': session.id,
                              'subject': subject?.name ?? 'Subject',
                              'subjectCode': subject?.code,
                              'date': session.parsedDate,
                              'period': session.period,
                              'classId': activeClass.id,
                              'className': activeClass.name,
                              'section': activeClass.section,
                            },
                          );
                          _loadDashboardData();
                        },
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? (isDark
                                          ? AppColors.darkSuccessSubtle
                                          : AppColors.lightSuccessSubtle)
                                    : (isDark
                                          ? AppColors.darkNavSelected
                                          : AppColors.lightNavSelected),
                                borderRadius: AppSpacing.borderRadiusSm,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_actions_rounded,
                                color: isCompleted
                                    ? (isDark
                                          ? AppColors.darkSuccess
                                          : AppColors.lightSuccess)
                                    : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subjectTitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${session.sessionDate} · Period ${session.period}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                                isCompleted ? 'Completed' : 'In Progress',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? (isDark
                                            ? AppColors.darkSuccess
                                            : AppColors.lightSuccess)
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 16),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the dynamic class banner with loading, error, empty, and populated states.
  Widget _buildClassBanner(BuildContext context, bool isDark, ThemeData theme) {
    if (_isLoading) {
      return AppCard(
        color: isDark ? AppColors.darkElevatedSurface : AppColors.lightSurface,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkNavSelected
                    : AppColors.lightNavSelected,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading Class Profile...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Retrieving offline database records',
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
      );
    }

    if (_errorMessage != null) {
      return AppCard(
        color: isDark ? AppColors.darkErrorSubtle : AppColors.lightErrorSubtle,
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isDark ? AppColors.darkError : AppColors.lightError,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Profile Notice',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkError
                          : AppColors.lightError,
                    ),
                  ),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadDashboardData,
              tooltip: 'Retry',
            ),
          ],
        ),
      );
    }

    // Missing class state
    if (_activeClass == null) {
      return AppCard(
        color: isDark ? AppColors.darkElevatedSurface : AppColors.lightSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkNavSelected
                        : AppColors.lightNavSelected,
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentOwner != null
                            ? 'CR: ${_currentOwner!.displayName ?? _currentOwner!.registrationNumber}'
                            : 'Class Representative Portal',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No Active Class Configured',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set up your class profile to start adding subjects, enrolling students, and marking attendance.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: 'Configure Class Profile',
              icon: Icons.add_rounded,
              height: 40,
              onPressed: () async {
                await Navigator.of(context).pushNamed(
                  AppRoutes.onboardingClass,
                  arguments: {'ownerId': _currentOwner?.id},
                );
                _loadDashboardData();
              },
            ),
          ],
        ),
      );
    }

    // Success State with Real Database Records
    final activeClass = _activeClass!;
    final owner = _currentOwner;

    final crLabel = owner != null
        ? (owner.displayName != null && owner.displayName!.isNotEmpty
              ? 'CR: ${owner.displayName!} (${owner.registrationNumber})'
              : 'CR: ${owner.registrationNumber}')
        : 'Class Representative Portal';

    final classTitle = '${activeClass.name} — Section ${activeClass.section}';
    final periodSubtitle =
        'Academic Year ${activeClass.academicYear}${activeClass.semester != null ? ' • ${activeClass.semester}' : ''}';

    return AppCard(
      color: isDark ? AppColors.darkElevatedSurface : AppColors.lightSurface,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkNavSelected
                  : AppColors.lightNavSelected,
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  classTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  periodSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceOverview(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    final report = _classReport;
    final totalCompleted = report?.totalCompletedSessions ?? 0;
    final pctString = AttendanceCalculationPolicy.formatPercentage(
      report?.overallPercentage,
    );
    final totalStudents = report?.studentStats.length ?? 0;

    Color pctColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    Color pctBgColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightBackground;
    if (report?.overallPercentage != null) {
      final p = report!.overallPercentage!;
      if (p >= 75.0) {
        pctColor = isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
        pctBgColor = isDark
            ? AppColors.darkSuccessSubtle
            : AppColors.lightSuccessSubtle;
      } else if (p >= 65.0) {
        pctColor = isDark ? AppColors.darkWarning : AppColors.lightWarning;
        pctBgColor = isDark
            ? AppColors.darkWarningSubtle
            : AppColors.lightWarningSubtle;
      } else {
        pctColor = isDark ? AppColors.darkError : AppColors.lightError;
        pctBgColor = isDark
            ? AppColors.darkErrorSubtle
            : AppColors.lightErrorSubtle;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkNavSelected
                          : AppColors.lightNavSelected,
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Attendance Overview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onSwitchTab?.call(2),
                borderRadius: AppSpacing.borderRadiusSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detailed Reports',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // 1. Completed Sessions
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkElevatedSurface
                        : AppColors.lightBackground,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$totalCompleted',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Completed Sessions',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // 2. Class Attendance %
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: pctBgColor,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: Column(
                    children: [
                      Text(
                        pctString,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: pctColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Class Attendance',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: pctColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // 3. Active Students
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkElevatedSurface
                        : AppColors.lightBackground,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$totalStudents',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enrolled Students',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (totalCompleted > 0 && report != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniCountPill(
                  'Present',
                  report.totalPresent,
                  AppColors.lightSuccess,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildMiniCountPill(
                  'Absent',
                  report.totalAbsent,
                  AppColors.lightError,
                  isDark,
                ),
                if (report.totalLate > 0) ...[
                  const SizedBox(width: 8),
                  _buildMiniCountPill(
                    'Late',
                    report.totalLate,
                    AppColors.lightWarning,
                    isDark,
                  ),
                ],
                if (report.totalLeave > 0) ...[
                  const SizedBox(width: 8),
                  _buildMiniCountPill(
                    'Leave',
                    report.totalLeave,
                    AppColors.secondary,
                    isDark,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCountPill(
    String label,
    int count,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static String _formatCurrentDate(DateTime date) {
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
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = weekdays[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }
}
