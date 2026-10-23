import 'package:flutter/material.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../data/models/attendance_session_model.dart';
import '../../../data/repositories/repository_provider.dart';

class _StudentAttendanceItem {
  final String studentId;
  final String rollNo;
  final String name;
  AttendanceStatus status;
  String? remarks;
  String? recordId;
  final bool isDeactivated;

  _StudentAttendanceItem({
    required this.studentId,
    required this.rollNo,
    required this.name,
    this.status = AttendanceStatus.unmarked,
    this.remarks,
    this.recordId,
    this.isDeactivated = false,
  });
}

/// Attendance Roster screen providing student attendance status selection,
/// "Mark All Present", real-time progress indicators, and atomic SQLite persistence.
/// Commits attendance sessions and records atomically with append-only audit logging.
class AttendanceRosterScreen extends StatefulWidget {
  final AttendanceSessionModel? session;
  final String? sessionId;
  final String subjectName;
  final String? subjectCode;
  final DateTime sessionDate;
  final String period;
  final String? classId;
  final String? className;
  final String? section;

  const AttendanceRosterScreen({
    super.key,
    this.session,
    this.sessionId,
    required this.subjectName,
    this.subjectCode,
    required this.sessionDate,
    this.period = '1',
    this.classId,
    this.className,
    this.section,
  });

  @override
  State<AttendanceRosterScreen> createState() => _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends State<AttendanceRosterScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<_StudentAttendanceItem> _allStudents = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  AttendanceSessionModel? _session;
  bool _hasUnsavedChanges = false;
  bool _hasExistingRecords = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRosterData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRosterData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = RepositoryProvider.of(context);

      // 1. Resolve Class ID
      String? classId = widget.classId ?? _session?.classId;
      if (classId == null) {
        final owner = await container.ownerRepository.getCurrentOwner();
        if (owner != null) {
          final activeClass = await container.classRepository
              .getActiveClassForOwner(owner.id);
          classId = activeClass?.id;
        }
      }

      if (classId == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to identify the class associated with this attendance session.';
        });
        return;
      }

      // 2. Resolve Session Model if missing
      final sid = widget.sessionId ?? _session?.id;
      if (_session == null && sid != null) {
        _session = await container.attendanceRepository.getSessionById(sid);
      }

      // 3. Load Active Students for Class
      final activeStudents = await container.studentRepository
          .getActiveStudentsByClass(classId);

      // 4. Load Any Existing Records for this Session
      Map<String, AttendanceRecordModel> existingRecordMap = {};

      if (sid != null) {
        final records = await container.attendanceRepository
            .getRecordsForSession(sid);
        if (records.isNotEmpty) {
          _hasExistingRecords = true;
          for (final r in records) {
            existingRecordMap[r.studentId] = r;
          }
        }
      }

      // 5. Construct Roster Items starting with active students
      final items = activeStudents.map((s) {
        final rec = existingRecordMap[s.id];
        return _StudentAttendanceItem(
          studentId: s.id,
          rollNo: s.rollNumber,
          name: s.name,
          status: rec?.status ?? AttendanceStatus.unmarked,
          remarks: rec?.remarks,
          recordId: rec?.id,
          isDeactivated: false,
        );
      }).toList();

      // 6. Handle historical students who may have since been deactivated
      for (final entry in existingRecordMap.entries) {
        final studentId = entry.key;
        final rec = entry.value;
        final isAlreadyInList = items.any(
          (item) => item.studentId == studentId,
        );

        if (!isAlreadyInList) {
          final pastStudent = await container.studentRepository.getStudentById(
            studentId,
          );
          if (pastStudent != null) {
            items.add(
              _StudentAttendanceItem(
                studentId: pastStudent.id,
                rollNo: pastStudent.rollNumber,
                name: pastStudent.name,
                status: rec.status,
                remarks: rec.remarks,
                recordId: rec.id,
                isDeactivated: true,
              ),
            );
          }
        }
      }

      // Sort students by normalized roll number
      items.sort((a, b) => a.rollNo.compareTo(b.rollNo));

      if (!mounted) return;
      setState(() {
        _allStudents = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load roster data: $e';
      });
    }
  }

  void _markAllPresent() {
    setState(() {
      for (final s in _allStudents) {
        s.status = AttendanceStatus.present;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _setStatus(String studentId, AttendanceStatus status) {
    setState(() {
      final index = _allStudents.indexWhere((s) => s.studentId == studentId);
      if (index != -1) {
        _allStudents[index].status = status;
        _hasUnsavedChanges = true;
      }
    });
  }

  Future<void> _editRemarks(_StudentAttendanceItem item) async {
    final controller = TextEditingController(text: item.remarks ?? '');
    final updatedRemarks = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remarks for ${item.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., Medical leave, approved duty, late slip',
            labelText: 'Remarks / Notes',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          if (item.remarks != null && item.remarks!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Clear'),
            ),
          AppButton.primary(
            label: 'Save Remark',
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            height: 38,
          ),
        ],
      ),
    );

    if (updatedRemarks != null && mounted) {
      setState(() {
        item.remarks = updatedRemarks.isEmpty ? null : updatedRemarks;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await ConfirmationDialog.show(
      context,
      title: 'Discard Unsaved Changes?',
      message: 'You have unrecorded attendance status changes on this roster. Are you sure you want to go back without saving?',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Marking',
      isDestructive: true,
    );
    return discard ?? false;
  }

  Future<void> _saveAttendance() async {
    final unmarkedCount = _allStudents
        .where((s) => s.status == AttendanceStatus.unmarked)
        .length;

    // Enforce attendance completion policy: no UNMARKED students when completing
    if (unmarkedCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unmarked Students'),
          content: Text(
            '$unmarkedCount student${unmarkedCount > 1 ? 's are' : ' is'} still unmarked.\n\n'
            'Please record a status (Present, Absent, Late, or Leave) for every student or tap "Mark All Present" to complete attendance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Review Roster'),
            ),
          ],
        ),
      );
      return;
    }

    final container = RepositoryProvider.of(context);
    final currentSession = _session ?? widget.session;

    if (currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save: Session context is missing.'),
          backgroundColor: AppColors.lightError,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Build updated session model marked as COMPLETED
      final completedSession = currentSession.copyWith(
        status: 'COMPLETED',
        updatedAt: DateTime.now(),
      );

      // 2. Map all roster items to AttendanceRecordModel preserving stable IDs
      final now = DateTime.now();
      final records = _allStudents.map((s) {
        return AttendanceRecordModel(
          id: s.recordId ?? '',
          sessionId: completedSession.id,
          studentId: s.studentId,
          status: s.status,
          remarks: s.remarks,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      // 3. Resolve actor reference for audit event
      final owner = await container.ownerRepository.getCurrentOwner();
      final actorReference =
          owner?.displayName ?? owner?.registrationNumber ?? 'CR';

      // 4. Execute atomic transaction save with audit logging
      final result = await container.attendanceRepository
          .saveSessionWithRecordsAtomic(
            session: completedSession,
            records: records,
            actorReference: actorReference,
            reason: _hasExistingRecords
                ? 'Attendance records updated'
                : 'Session attendance completed',
          );

      if (!mounted) return;

      setState(() {
        _session = result.session;
        _hasUnsavedChanges = false;
        _hasExistingRecords = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Attendance saved successfully (${records.length} students recorded).',
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.lightSuccess,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      final String message = e is AppDatabaseException
          ? e.message
          : 'Failed to save attendance: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredStudents = _allStudents.where((s) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.rollNo.toLowerCase().contains(q);
    }).toList();

    final total = _allStudents.length;
    final present = _allStudents
        .where((s) => s.status == AttendanceStatus.present)
        .length;
    final absent = _allStudents
        .where((s) => s.status == AttendanceStatus.absent)
        .length;
    final lateCount = _allStudents
        .where((s) => s.status == AttendanceStatus.late)
        .length;
    final leave = _allStudents
        .where((s) => s.status == AttendanceStatus.leave)
        .length;
    final unmarked = _allStudents
        .where((s) => s.status == AttendanceStatus.unmarked)
        .length;

    final dateFormatted =
        '${widget.sessionDate.day.toString().padLeft(2, '0')}/${widget.sessionDate.month.toString().padLeft(2, '0')}/${widget.sessionDate.year}';

    final subjectTitle =
        widget.subjectCode != null && widget.subjectCode!.isNotEmpty
        ? '${widget.subjectName} (${widget.subjectCode})'
        : widget.subjectName;

    final isCompleted = _session?.status.toUpperCase() == 'COMPLETED';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subjectTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$dateFormatted · Period ${widget.period}',
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
            if (!_isLoading && _allStudents.isNotEmpty)
              TextButton.icon(
                onPressed: _isSaving ? null : _markAllPresent,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark All Present'),
              ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: SafeArea(
          child: _buildBody(
            theme,
            isDark,
            filteredStudents,
            total,
            present,
            absent,
            lateCount,
            leave,
            unmarked,
            isCompleted,
          ),
        ),
        bottomNavigationBar: !_isLoading && _allStudents.isNotEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SafeArea(
                  top: false,
                  child: AppButton.primary(
                    label: _hasExistingRecords
                        ? 'Update Attendance ($present/$total Present)'
                        : 'Save Attendance ($present/$total Present)',
                    icon: Icons.save_rounded,
                    isFullWidth: true,
                    height: 52,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveAttendance,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    bool isDark,
    List<_StudentAttendanceItem> filteredStudents,
    int total,
    int present,
    int absent,
    int lateCount,
    int leave,
    int unmarked,
    bool isCompleted,
  ) {
    if (_isLoading) {
      return const LoadingStateView(
        message: 'Preparing class attendance roster...',
      );
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Unable to Load Roster',
        message: _errorMessage!,
        onRetry: _loadRosterData,
      );
    }

    if (_allStudents.isEmpty) {
      return EmptyStateView(
        icon: Icons.groups_outlined,
        title: 'No Students Found',
        description: 'No active students are enrolled in this class. Please enroll students in the Students tab before starting attendance sessions.',
        actionLabel: 'Go to Students Tab',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    return Column(
      children: [
        // Session Status & Class Info Banner
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: isDark
              ? AppColors.darkElevatedSurface
              : AppColors.lightBackground,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.className != null)
                Text(
                  '${widget.className}${widget.section != null ? ' · Sec ${widget.section!}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.pending_actions_rounded,
                      size: 12,
                      color: isCompleted
                          ? (isDark
                                ? AppColors.darkSuccess
                                : AppColors.lightSuccess)
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
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
                  ],
                ),
              ),
            ],
          ),
        ),

        // Attendance Progress Bar & Metrics
        Container(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricChip(
                    context,
                    label: 'Total',
                    count: total,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  _buildMetricChip(
                    context,
                    label: 'Present',
                    count: present,
                    color: isDark
                        ? AppColors.darkSuccess
                        : AppColors.lightSuccess,
                  ),
                  _buildMetricChip(
                    context,
                    label: 'Absent',
                    count: absent,
                    color: isDark ? AppColors.darkError : AppColors.lightError,
                  ),
                  _buildMetricChip(
                    context,
                    label: 'Late',
                    count: lateCount,
                    color: isDark
                        ? AppColors.darkWarning
                        : AppColors.lightWarning,
                  ),
                  _buildMetricChip(
                    context,
                    label: 'Leave',
                    count: leave,
                    color: isDark ? AppColors.darkInfo : AppColors.lightInfo,
                  ),
                  _buildMetricChip(
                    context,
                    label: 'Unmarked',
                    count: unmarked,
                    color: isDark
                        ? AppColors.darkNeutral
                        : AppColors.lightNeutral,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusFull,
                child: LinearProgressIndicator(
                  value: total > 0 ? (total - unmarked) / total : 0,
                  backgroundColor: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),

        // Search Bar in Roster
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: AppTextField(
            controller: _searchController,
            hintText: 'Filter roster by student name or roll...',
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
        ),

        const Divider(height: 1),

        // Roster Student List
        Expanded(
          child: filteredStudents.isEmpty
              ? EmptyStateView(
                  icon: Icons.person_search_rounded,
                  title: 'No Matching Students',
                  description:
                      'No students match "$_searchQuery" on this roster.',
                  actionLabel: 'Clear Filter',
                  onAction: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.xs,
                    bottom: 96.0,
                  ),
                  itemCount: filteredStudents.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final item = filteredStudents[index];
                    return _buildRosterRow(context, item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRosterRow(BuildContext context, _StudentAttendanceItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 38),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkNavSelected
                      : AppColors.lightNavSelected,
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                alignment: Alignment.center,
                child: Text(
                  item.rollNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isDeactivated) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkNeutralSubtle
                                  : AppColors.lightNeutralSubtle,
                              borderRadius: AppSpacing.borderRadiusFull,
                            ),
                            child: const Text(
                              'Deactivated',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Roll #${item.rollNo}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        if (item.remarks != null &&
                            item.remarks!.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '• ${item.remarks!}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Remarks trigger button
              IconButton(
                icon: Icon(
                  item.remarks != null && item.remarks!.isNotEmpty
                      ? Icons.comment_rounded
                      : Icons.add_comment_outlined,
                  size: 18,
                  color: item.remarks != null && item.remarks!.isNotEmpty
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
                tooltip: item.remarks != null && item.remarks!.isNotEmpty
                    ? 'Remark: ${item.remarks}'
                    : 'Add Remark',
                onPressed: () => _editRemarks(item),
              ),
              // Current status badge
              _buildStatusPill(context, item.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Status Selector Segment
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusOption(
                  item.studentId,
                  item.status,
                  AttendanceStatus.present,
                ),
                const SizedBox(width: AppSpacing.xxs),
                _buildStatusOption(
                  item.studentId,
                  item.status,
                  AttendanceStatus.absent,
                ),
                const SizedBox(width: AppSpacing.xxs),
                _buildStatusOption(
                  item.studentId,
                  item.status,
                  AttendanceStatus.late,
                ),
                const SizedBox(width: AppSpacing.xxs),
                _buildStatusOption(
                  item.studentId,
                  item.status,
                  AttendanceStatus.leave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    String studentId,
    AttendanceStatus current,
    AttendanceStatus option,
  ) {
    final isSelected = current == option;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color activeColor = AppColors.statusColor(option, isDark: isDark);
    Color subtleColor = AppColors.statusSubtleColor(option, isDark: isDark);

    return InkWell(
      onTap: () => _setStatus(studentId, option),
      borderRadius: AppSpacing.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? subtleColor : Colors.transparent,
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 14,
              color: isSelected
                  ? activeColor
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, AttendanceStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.statusColor(status, isDark: isDark);
    final subtle = AppColors.statusSubtleColor(status, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: subtle,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
