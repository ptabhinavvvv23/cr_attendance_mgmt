import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/attendance_session_model.dart';
import '../../../data/models/attendance_stats_models.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/owner_model.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/repository_provider.dart';
import '../../../data/services/export/attendance_export_service.dart';
import '../../../routes/app_routes.dart';

enum ReportTimeframe { thisMonth, lastMonth, lastThreeMonths, allTime, custom }

enum StudentSortOption { rollNumberAsc, attendanceDesc, attendanceAsc, nameAsc }

/// Comprehensive Reports & Analytics screen for viewing historical attendance summaries,
/// monthly/semester breakdowns, student-wise statistics, and subject-wise metrics.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  OwnerModel? _currentOwner;
  ClassModel? _activeClass;
  List<SubjectModel> _subjects = [];
  String? _selectedSubjectId; // null = 'All Subjects'

  ReportTimeframe _selectedTimeframe = ReportTimeframe.thisMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  ClassAttendanceReport? _report;
  bool _isLoading = true;
  String? _errorMessage;

  // View state: 0 = Students, 1 = Subjects
  int _activeTab = 0;

  // Student filtering & sorting
  String _studentSearchQuery = '';
  StudentSortOption _sortOption = StudentSortOption.rollNumberAsc;
  String _attendanceThresholdFilter = 'ALL'; // 'ALL', 'BELOW_75', 'ABOVE_75'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassAndReport();
    });
  }

  Future<void> _loadClassAndReport() async {
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
      _currentOwner = owner;
      _activeClass = activeClass;
      _subjects = subjects;

      if (activeClass != null) {
        await _fetchReportData(activeClass.id);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load report data: $e';
      });
    }
  }

  Future<void> _fetchReportData(String classId) async {
    try {
      final container = RepositoryProvider.of(context);
      final range = _getDateRange();

      final report = await container.attendanceRepository
          .getClassAttendanceReport(
            classId: classId,
            startDate: range?.start,
            endDate: range?.end,
            subjectId: _selectedSubjectId,
          );

      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to calculate attendance statistics: $e';
      });
    }
  }

  DateTimeRange? _getDateRange() {
    final now = DateTime.now();
    switch (_selectedTimeframe) {
      case ReportTimeframe.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case ReportTimeframe.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: start, end: end);
      case ReportTimeframe.lastThreeMonths:
        final start = DateTime(now.year, now.month - 2, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case ReportTimeframe.allTime:
        return null;
      case ReportTimeframe.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return DateTimeRange(start: _customStartDate!, end: _customEndDate!);
        }
        return null;
    }
  }

  String _getTimeframeLabel() {
    final now = DateTime.now();
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
    switch (_selectedTimeframe) {
      case ReportTimeframe.thisMonth:
        return 'This Month (${months[now.month - 1]} ${now.year})';
      case ReportTimeframe.lastMonth:
        final prevMonthDate = DateTime(now.year, now.month - 1, 1);
        return 'Last Month (${months[prevMonthDate.month - 1]} ${prevMonthDate.year})';
      case ReportTimeframe.lastThreeMonths:
        final start = DateTime(now.year, now.month - 2, 1);
        return 'Last 3 Months (${months[start.month - 1]} - ${months[now.month - 1]} ${now.year})';
      case ReportTimeframe.allTime:
        return 'Full Semester / All Time';
      case ReportTimeframe.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return '${AttendanceSessionModel.formatDate(_customStartDate!)} to ${AttendanceSessionModel.formatDate(_customEndDate!)}';
        }
        return 'Custom Date Range';
    }
  }

  Future<void> _pickCustomDateRange() async {
    final initialRange =
        _getDateRange() ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      helpText: 'Select Report Date Range',
    );

    if (picked != null) {
      setState(() {
        _selectedTimeframe = ReportTimeframe.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      if (_activeClass != null) {
        _fetchReportData(_activeClass!.id);
      }
    }
  }

  Future<void> _handleExport(ExportFormat format) async {
    final report = _report;
    if (report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance report data available to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show non-blocking progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Generating ${format.label}...',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Preparing document for export',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      const exportService = AttendanceExportService();
      final result = await exportService.exportAndShare(
        format: format,
        report: report,
        owner: _currentOwner,
      );

      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Dismiss progress dialog

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Export failed.'),
            backgroundColor: AppColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<StudentAttendanceStats> _getFilteredStudents() {
    final report = _report;
    if (report == null) return [];

    var list = report.studentStats.where((s) {
      if (_studentSearchQuery.isNotEmpty) {
        final q = _studentSearchQuery.toLowerCase();
        final matchRoll = s.student.rollNumber.toLowerCase().contains(q);
        final matchName = s.student.name.toLowerCase().contains(q);
        if (!matchRoll && !matchName) return false;
      }

      if (_attendanceThresholdFilter == 'BELOW_75') {
        return (s.percentage ?? 0.0) < 75.0;
      } else if (_attendanceThresholdFilter == 'ABOVE_75') {
        return (s.percentage ?? 0.0) >= 75.0;
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case StudentSortOption.rollNumberAsc:
        list.sort(
          (a, b) => a.student.normalizedRollNumber.compareTo(
            b.student.normalizedRollNumber,
          ),
        );
        break;
      case StudentSortOption.attendanceDesc:
        list.sort(
          (a, b) => (b.percentage ?? -1.0).compareTo(a.percentage ?? -1.0),
        );
        break;
      case StudentSortOption.attendanceAsc:
        list.sort(
          (a, b) => (a.percentage ?? -1.0).compareTo(b.percentage ?? -1.0),
        );
        break;
      case StudentSortOption.nameAsc:
        list.sort(
          (a, b) => a.student.name.toLowerCase().compareTo(
            b.student.name.toLowerCase(),
          ),
        );
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance Reports',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Reports',
            onPressed: () {
              if (_activeClass != null) {
                _fetchReportData(_activeClass!.id);
              } else {
                _loadClassAndReport();
              }
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
            ? ErrorStateView(
                message: _errorMessage!,
                onRetry: _loadClassAndReport,
              )
            : _activeClass == null
            ? EmptyStateView(
                title: 'No Active Class',
                description: 'Configure your class profile first to generate attendance reports.',
                actionLabel: 'Setup Class',
                onAction: () async {
                  await Navigator.of(context).pushNamed(
                    AppRoutes.onboardingClass,
                    arguments: {'ownerId': _currentOwner?.id},
                  );
                  _loadClassAndReport();
                },
              )
            : RefreshIndicator(
                onRefresh: () async {
                  if (_activeClass != null) {
                    await _fetchReportData(_activeClass!.id);
                  }
                },
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Report Filters Card
                      _buildFiltersCard(context, isDark, theme),

                      const SizedBox(height: AppSpacing.md),

                      // 2. Class Overview Metrics Card
                      _buildMetricsOverviewCard(context, isDark, theme),

                      const SizedBox(height: AppSpacing.lg),

                      // 3. Export Actions Card
                      _buildExportSection(context, isDark, theme),

                      const SizedBox(height: AppSpacing.lg),

                      // 4. View Switcher Tabs (Students vs Subjects)
                      _buildViewTabs(context, isDark, theme),

                      const SizedBox(height: AppSpacing.md),

                      // 5. Dynamic Content (Students Summary or Subjects Summary)
                      if (_activeTab == 0)
                        _buildStudentsSection(context, isDark, theme)
                      else
                        _buildSubjectsSection(context, isDark, theme),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Filters Card
  // ---------------------------------------------------------------------------
  Widget _buildFiltersCard(BuildContext context, bool isDark, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Report Scope & Filters',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Timeframe Dropdown
          DropdownButtonFormField<ReportTimeframe>(
            initialValue: _selectedTimeframe,
            decoration: const InputDecoration(
              labelText: 'Timeframe',
              prefixIcon: Icon(Icons.calendar_month_rounded, size: 20),
            ),
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: ReportTimeframe.thisMonth,
                child: Text(
                  _getTimeframeOptionLabel(ReportTimeframe.thisMonth),
                ),
              ),
              DropdownMenuItem(
                value: ReportTimeframe.lastMonth,
                child: Text(
                  _getTimeframeOptionLabel(ReportTimeframe.lastMonth),
                ),
              ),
              DropdownMenuItem(
                value: ReportTimeframe.lastThreeMonths,
                child: Text(
                  _getTimeframeOptionLabel(ReportTimeframe.lastThreeMonths),
                ),
              ),
              DropdownMenuItem(
                value: ReportTimeframe.allTime,
                child: Text(_getTimeframeOptionLabel(ReportTimeframe.allTime)),
              ),
              DropdownMenuItem(
                value: ReportTimeframe.custom,
                child: Text(_getTimeframeOptionLabel(ReportTimeframe.custom)),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                if (val == ReportTimeframe.custom) {
                  _pickCustomDateRange();
                } else {
                  setState(() => _selectedTimeframe = val);
                  if (_activeClass != null) {
                    _fetchReportData(_activeClass!.id);
                  }
                }
              }
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Subject Dropdown
          DropdownButtonFormField<String?>(
            initialValue: _selectedSubjectId,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Subjects'),
              ),
              ..._subjects.map((s) {
                final codePart = s.code != null && s.code!.isNotEmpty
                    ? ' (${s.code})'
                    : '';
                final archivePart = !s.isActive ? ' [Archived]' : '';
                return DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(
                    '${s.name}$codePart$archivePart',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (val) {
              setState(() => _selectedSubjectId = val);
              if (_activeClass != null) {
                _fetchReportData(_activeClass!.id);
              }
            },
          ),
        ],
      ),
    );
  }

  String _getTimeframeOptionLabel(ReportTimeframe timeframe) {
    switch (timeframe) {
      case ReportTimeframe.thisMonth:
        return 'Current Month';
      case ReportTimeframe.lastMonth:
        return 'Previous Month';
      case ReportTimeframe.lastThreeMonths:
        return 'Last 3 Months';
      case ReportTimeframe.allTime:
        return 'Full Semester / All Recorded Time';
      case ReportTimeframe.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return 'Custom: ${AttendanceSessionModel.formatDate(_customStartDate!)} - ${AttendanceSessionModel.formatDate(_customEndDate!)}';
        }
        return 'Custom Date Range...';
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Metrics Overview Card
  // ---------------------------------------------------------------------------
  Widget _buildMetricsOverviewCard(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    final report = _report;
    final totalCompleted = report?.totalCompletedSessions ?? 0;
    final pctString = AttendanceCalculationPolicy.formatPercentage(
      report?.overallPercentage,
    );

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
              Text(
                'Class Performance Summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkNavSelected
                      : AppColors.lightNavSelected,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
                child: Text(
                  _getTimeframeLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Primary Stats Row
          Row(
            children: [
              // Sessions Completed
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
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
                        style: theme.textTheme.titleLarge?.copyWith(
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
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Overall Attendance %
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: pctColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Class Attendance',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pctColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Total Evaluated Records
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
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
                        '${report?.totalRecords ?? 0}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Attendance Marks',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
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

          // Secondary Counts Pill Row
          if (report != null && totalCompleted > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildStatusChip(
                  'Present',
                  report.totalPresent,
                  AppColors.lightSuccess,
                  isDark,
                ),
                _buildStatusChip(
                  'Absent',
                  report.totalAbsent,
                  AppColors.lightError,
                  isDark,
                ),
                if (report.totalLate > 0)
                  _buildStatusChip(
                    'Late',
                    report.totalLate,
                    AppColors.lightWarning,
                    isDark,
                  ),
                if (report.totalLeave > 0)
                  _buildStatusChip(
                    'Leave',
                    report.totalLeave,
                    AppColors.secondary,
                    isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: AppSpacing.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Export Actions Card
  // ---------------------------------------------------------------------------
  Widget _buildExportSection(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Export Options',
          subtitle: 'Generate printable documents or spreadsheets',
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: 'PDF Document',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () => _handleExport(ExportFormat.pdf),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppButton.secondary(
                label: 'Excel (.xlsx)',
                icon: Icons.table_chart_outlined,
                onPressed: () => _handleExport(ExportFormat.excel),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppButton.secondary(
                label: 'CSV Data',
                icon: Icons.description_outlined,
                onPressed: () => _handleExport(ExportFormat.csv),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. View Switcher Tabs
  // ---------------------------------------------------------------------------
  Widget _buildViewTabs(BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              borderRadius: AppSpacing.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 0
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 18,
                      color: _activeTab == 0
                          ? Colors.white
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Students Summary',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 0
                            ? Colors.white
                            : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              borderRadius: AppSpacing.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 1
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: _activeTab == 1
                          ? Colors.white
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Subjects Summary',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 1
                            ? Colors.white
                            : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Students Summary View
  // ---------------------------------------------------------------------------
  Widget _buildStudentsSection(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    final filteredStudents = _getFilteredStudents();
    final totalCompleted = _report?.totalCompletedSessions ?? 0;

    if (totalCompleted == 0) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.md,
        ),
        child: Column(
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
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Completed Sessions in Selected Period',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mark and complete attendance sessions to generate student attendance statistics.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(
              label: 'Mark Attendance Now',
              icon: Icons.checklist_rounded,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.attendanceSetup);
              },
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter controls
        AppTextField(
          hintText: 'Search by roll number or student name...',
          prefixIcon: const Icon(Icons.search_rounded),
          onChanged: (val) {
            setState(() {
              _studentSearchQuery = val;
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        // Quick Filter and Sort Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Students'),
                selected: _attendanceThresholdFilter == 'ALL',
                onSelected: (sel) {
                  if (sel) setState(() => _attendanceThresholdFilter = 'ALL');
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              FilterChip(
                label: const Text('< 75% Attendance'),
                selected: _attendanceThresholdFilter == 'BELOW_75',
                selectedColor: AppColors.lightErrorSubtle,
                checkmarkColor: AppColors.lightError,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _attendanceThresholdFilter = 'BELOW_75');
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              FilterChip(
                label: const Text('≥ 75% Attendance'),
                selected: _attendanceThresholdFilter == 'ABOVE_75',
                selectedColor: AppColors.lightSuccessSubtle,
                checkmarkColor: AppColors.lightSuccess,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _attendanceThresholdFilter = 'ABOVE_75');
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              PopupMenuButton<StudentSortOption>(
                initialValue: _sortOption,
                tooltip: 'Sort Students',
                child: Chip(
                  avatar: const Icon(Icons.sort_rounded, size: 16),
                  label: const Text('Sort'),
                ),
                onSelected: (opt) => setState(() => _sortOption = opt),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: StudentSortOption.rollNumberAsc,
                    child: Text('Roll Number'),
                  ),
                  const PopupMenuItem(
                    value: StudentSortOption.attendanceDesc,
                    child: Text('Attendance % (High to Low)'),
                  ),
                  const PopupMenuItem(
                    value: StudentSortOption.attendanceAsc,
                    child: Text('Attendance % (Low to High)'),
                  ),
                  const PopupMenuItem(
                    value: StudentSortOption.nameAsc,
                    child: Text('Student Name'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Student List
        if (filteredStudents.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'No students match the current filters.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredStudents.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final item = filteredStudents[index];
              return _buildStudentCard(context, item, isDark, theme);
            },
          ),
      ],
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    StudentAttendanceStats item,
    bool isDark,
    ThemeData theme,
  ) {
    final pctString = AttendanceCalculationPolicy.formatPercentage(
      item.percentage,
    );

    Color pctColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    Color pctBgColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightBackground;
    if (item.percentage != null) {
      final p = item.percentage!;
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
      onTap: () => _showStudentDetailSheet(context, item),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Roll Number Box
          Container(
            width: 48,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkElevatedSurface
                  : AppColors.lightBackground,
              borderRadius: AppSpacing.borderRadiusSm,
              border: Border.all(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              item.student.rollNumber,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Name and Counts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.student.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isDeactivated) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        child: Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.presentCount}P · ${item.absentCount}A · ${item.lateCount}L · ${item.leaveCount}Lv',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Percentage Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pctBgColor,
              borderRadius: AppSpacing.borderRadiusFull,
            ),
            child: Text(
              pctString,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pctColor,
              ),
            ),
          ),

          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Subjects Summary View
  // ---------------------------------------------------------------------------
  Widget _buildSubjectsSection(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    final report = _report;
    final subjectStats = report?.subjectStats ?? [];
    final totalCompleted = report?.totalCompletedSessions ?? 0;

    if (totalCompleted == 0 || subjectStats.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.md,
        ),
        child: Column(
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
                Icons.menu_book_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Subject Attendance Records',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Subjects will display attendance statistics once sessions are completed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subjectStats.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = subjectStats[index];
        final pctString = AttendanceCalculationPolicy.formatPercentage(
          item.percentage,
        );

        Color pctColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;
        Color pctBgColor = isDark
            ? AppColors.darkSurface
            : AppColors.lightBackground;
        if (item.percentage != null) {
          final p = item.percentage!;
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

        final codeLabel =
            item.subject.code != null && item.subject.code!.isNotEmpty
            ? ' (${item.subject.code})'
            : '';

        return AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkNavSelected
                      : AppColors.lightNavSelected,
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.subject.name}$codeLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isArchived) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkDivider
                                  : AppColors.lightDivider,
                              borderRadius: AppSpacing.borderRadiusSm,
                            ),
                            child: Text(
                              'Archived',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.totalSessions} Sessions · ${item.presentCount}P · ${item.absentCount}A',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pctBgColor,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
                child: Text(
                  pctString,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pctColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Student Detail Bottom Sheet (Subject Breakdown)
  // ---------------------------------------------------------------------------
  void _showStudentDetailSheet(
    BuildContext context,
    StudentAttendanceStats stats,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pctString = AttendanceCalculationPolicy.formatPercentage(
      stats.percentage,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? AppColors.darkElevatedSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            final breakdownItems = stats.subjectBreakdown.values.toList();
            return SingleChildScrollView(
              controller: scrollController,
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                        borderRadius: AppSpacing.borderRadiusFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Student Header
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
                        alignment: Alignment.center,
                        child: Text(
                          stats.student.rollNumber,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats.student.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              'Overall Attendance: $pctString (${stats.presentCount}P · ${stats.absentCount}A · ${stats.lateCount}L)',
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

                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Subject-Wise Attendance Breakdown',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (breakdownItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(
                        child: Text(
                          'No subject-specific attendance recorded in this period.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: breakdownItems.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (c, i) {
                        final b = breakdownItems[i];
                        final subPctString =
                            AttendanceCalculationPolicy.formatPercentage(
                              b.percentage,
                            );
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.subject.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                    ),
                                    Text(
                                      '${b.presentCount} Present · ${b.absentCount} Absent · ${b.lateCount} Late',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkNavSelected
                                      : AppColors.lightNavSelected,
                                  borderRadius: AppSpacing.borderRadiusSm,
                                ),
                                child: Text(
                                  subPctString,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: AppSpacing.lg),
                  AppButton.secondary(
                    label: 'Close',
                    isFullWidth: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
