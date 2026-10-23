import 'package:uuid/uuid.dart';

import '../../core/errors/database_exception.dart';
import '../../core/theme/app_colors.dart';
import '../local/app_database.dart';
import '../local/dao/attendance_record_dao.dart';
import '../local/dao/attendance_session_dao.dart';
import '../local/dao/audit_event_dao.dart';
import '../local/dao/class_dao.dart';
import '../local/dao/student_dao.dart';
import '../local/dao/subject_dao.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_stats_models.dart';
import '../models/audit_event_model.dart';

/// Composite container bundling an [AttendanceSessionModel] and its [AttendanceRecordModel] items.
class AttendanceSessionWithRecords {
  final AttendanceSessionModel session;
  final List<AttendanceRecordModel> records;

  const AttendanceSessionWithRecords({
    required this.session,
    required this.records,
  });
}

/// Repository contract for Attendance Sessions, Records, and atomic transaction-safe operations.
abstract class AttendanceRepository {
  Future<AttendanceSessionModel?> getSessionById(String id);
  Future<List<AttendanceSessionModel>> getSessionsByClass(
    String classId, {
    int? limit,
    int? offset,
  });
  Future<List<AttendanceSessionModel>> getSessionsByDateRange(
    String classId,
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<AttendanceSessionModel>> getSessionsBySubject(String subjectId);
  Future<bool> checkDuplicateSession(
    String classId,
    String subjectId,
    DateTime sessionDate,
    String period, {
    String? excludeSessionId,
  });
  Future<AttendanceSessionModel?> findExistingSession({
    required String classId,
    required String subjectId,
    required DateTime sessionDate,
    required String period,
  });
  Future<AttendanceSessionModel> createSession({
    required String classId,
    required String subjectId,
    required DateTime sessionDate,
    String period = '1',
    String status = 'SCHEDULED',
    String? notes,
  });
  Future<List<AttendanceRecordModel>> getRecordsForSession(String sessionId);
  Future<List<AttendanceRecordModel>> getRecordsForSessions(
    List<String> sessionIds,
  );
  Future<List<AttendanceRecordModel>> getRecordsForStudent(String studentId);

  /// Generates a complete, class-scoped attendance report with student-level,
  /// subject-level, and overall statistical aggregations.
  Future<ClassAttendanceReport> getClassAttendanceReport({
    required String classId,
    DateTime? startDate,
    DateTime? endDate,
    String? subjectId,
    AttendanceCalculationPolicy policy = AttendanceCalculationPolicy.standard,
  });

  /// Atomic transaction-safe persistence for a full attendance session and all student records.
  /// Validates cross-class relationship constraints, uniqueness rules, and commits all changes
  /// along with an audit event in a single atomic database transaction.
  Future<AttendanceSessionWithRecords> saveSessionWithRecordsAtomic({
    required AttendanceSessionModel session,
    required List<AttendanceRecordModel> records,
    String? actorReference,
    String? reason,
  });

  /// Updates an individual student attendance record with an append-only audit event.
  Future<AttendanceRecordModel> updateRecordStatusWithAudit({
    required AttendanceRecordModel record,
    required AttendanceStatus oldStatus,
    String? actorReference,
    String? reason,
  });
}

/// Concrete SQLite implementation of [AttendanceRepository].
class AttendanceRepositoryImpl implements AttendanceRepository {
  final AppDatabase _db;
  final AttendanceSessionDao _sessionDao;
  final AttendanceRecordDao _recordDao;
  final StudentDao _studentDao;
  final ClassDao _classDao;
  final SubjectDao _subjectDao;
  final AuditEventDao _auditDao;
  final Uuid _uuid;

  AttendanceRepositoryImpl({
    AppDatabase? db,
    AttendanceSessionDao? sessionDao,
    AttendanceRecordDao? recordDao,
    StudentDao? studentDao,
    ClassDao? classDao,
    SubjectDao? subjectDao,
    AuditEventDao? auditDao,
    Uuid? uuid,
  }) : _db = db ?? AppDatabase.instance,
       _sessionDao = sessionDao ?? AttendanceSessionDao(db),
       _recordDao = recordDao ?? AttendanceRecordDao(db),
       _studentDao = studentDao ?? StudentDao(db),
       _classDao = classDao ?? ClassDao(db),
       _subjectDao = subjectDao ?? SubjectDao(db),
       _auditDao = auditDao ?? AuditEventDao(db),
       _uuid = uuid ?? const Uuid();

  @override
  Future<AttendanceSessionModel?> getSessionById(String id) async {
    try {
      return await _sessionDao.getById(id);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to retrieve session $id: $e', e, st);
    }
  }

  @override
  Future<List<AttendanceSessionModel>> getSessionsByClass(
    String classId, {
    int? limit,
    int? offset,
  }) async {
    try {
      return await _sessionDao.getByClassId(
        classId,
        limit: limit,
        offset: offset,
      );
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve sessions for class $classId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<AttendanceSessionModel>> getSessionsByDateRange(
    String classId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = AttendanceSessionModel.formatDate(startDate);
    final endStr = AttendanceSessionModel.formatDate(endDate);
    try {
      return await _sessionDao.getByDateRange(classId, startStr, endStr);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve sessions for class $classId between $startStr and $endStr: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<AttendanceSessionModel>> getSessionsBySubject(
    String subjectId,
  ) async {
    try {
      return await _sessionDao.getBySubject(subjectId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve sessions for subject $subjectId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<bool> checkDuplicateSession(
    String classId,
    String subjectId,
    DateTime sessionDate,
    String period, {
    String? excludeSessionId,
  }) async {
    final existing = await findExistingSession(
      classId: classId,
      subjectId: subjectId,
      sessionDate: sessionDate,
      period: period,
    );
    if (existing == null) return false;
    if (excludeSessionId != null && existing.id == excludeSessionId) {
      return false;
    }
    return true;
  }

  @override
  Future<AttendanceSessionModel?> findExistingSession({
    required String classId,
    required String subjectId,
    required DateTime sessionDate,
    required String period,
  }) async {
    final dateStr = AttendanceSessionModel.formatDate(sessionDate);
    final cleanPeriod = period.trim().isEmpty ? '1' : period.trim();
    try {
      return await _sessionDao.checkDuplicateSession(
        classId,
        subjectId,
        dateStr,
        cleanPeriod,
      );
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to check existing session: $e', e, st);
    }
  }

  @override
  Future<AttendanceSessionModel> createSession({
    required String classId,
    required String subjectId,
    required DateTime sessionDate,
    String period = '1',
    String status = 'SCHEDULED',
    String? notes,
  }) async {
    final cleanPeriod = period.trim().isEmpty ? '1' : period.trim();

    // Verify parent class exists
    final targetClass = await _classDao.getById(classId);
    if (targetClass == null) {
      throw RecordNotFoundException('Class', classId);
    }

    // Verify subject exists and belongs to class
    final targetSubject = await _subjectDao.getById(subjectId);
    if (targetSubject == null) {
      throw RecordNotFoundException('Subject', subjectId);
    }
    if (targetSubject.classId != classId) {
      throw ValidationException(
        'Subject "${targetSubject.name}" does not belong to Class $classId.',
      );
    }

    // Check duplicate session
    final existing = await findExistingSession(
      classId: classId,
      subjectId: subjectId,
      sessionDate: sessionDate,
      period: cleanPeriod,
    );
    if (existing != null) {
      throw DuplicateSessionException(
        subjectId: subjectId,
        sessionDate: AttendanceSessionModel.formatDate(sessionDate),
        period: cleanPeriod,
      );
    }

    final now = DateTime.now();
    final session = AttendanceSessionModel(
      id: _uuid.v4(),
      classId: classId,
      subjectId: subjectId,
      sessionDate: AttendanceSessionModel.formatDate(sessionDate),
      period: cleanPeriod,
      status: status,
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _sessionDao.insert(session);
      return session;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to create attendance session: $e', e, st);
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getRecordsForSession(
    String sessionId,
  ) async {
    try {
      return await _recordDao.getBySessionId(sessionId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve records for session $sessionId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getRecordsForSessions(
    List<String> sessionIds,
  ) async {
    try {
      return await _recordDao.getBySessionIds(sessionIds);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve records for sessions: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<ClassAttendanceReport> getClassAttendanceReport({
    required String classId,
    DateTime? startDate,
    DateTime? endDate,
    String? subjectId,
    AttendanceCalculationPolicy policy = AttendanceCalculationPolicy.standard,
  }) async {
    try {
      // 1. Fetch class entity
      final classModel = await _classDao.getById(classId);

      // 2. Format dates if provided (using YYYY-MM-DD)
      final startStr = startDate != null
          ? AttendanceSessionModel.formatDate(startDate)
          : null;
      final endStr = endDate != null
          ? AttendanceSessionModel.formatDate(endDate)
          : null;

      // 3. Fetch completed sessions
      final completedSessions = await _sessionDao.getCompletedSessions(
        classId,
        subjectId: subjectId,
        startDate: startStr,
        endDate: endStr,
      );

      // 4. Fetch students (both active and inactive to preserve historical records)
      final allStudents = await _studentDao.getByClassId(
        classId,
        activeOnly: false,
      );
      final subjectsList = await _subjectDao.getByClassId(
        classId,
        activeOnly: false,
      );
      final subjectsMap = {for (final s in subjectsList) s.id: s};

      // If no completed sessions exist, return empty report safely
      if (completedSessions.isEmpty) {
        final activeStudents = allStudents.where((s) => s.isActive).toList();
        final emptyStudentStats = activeStudents.map((student) {
          return StudentAttendanceStats(
            student: student,
            totalSessions: 0,
            presentCount: 0,
            absentCount: 0,
            lateCount: 0,
            leaveCount: 0,
            unmarkedCount: 0,
            percentage: null,
            isDeactivated: false,
          );
        }).toList();

        final activeSubjects = subjectsList.where((s) => s.isActive).toList();
        final emptySubjectStats = activeSubjects.map((subject) {
          return SubjectAttendanceStats(
            subject: subject,
            totalSessions: 0,
            presentCount: 0,
            absentCount: 0,
            lateCount: 0,
            leaveCount: 0,
            unmarkedCount: 0,
            percentage: null,
            isArchived: false,
          );
        }).toList();

        return ClassAttendanceReport(
          classId: classId,
          classModel: classModel,
          startDate: startDate,
          endDate: endDate,
          subjectId: subjectId,
          totalCompletedSessions: 0,
          totalRecords: 0,
          totalPresent: 0,
          totalAbsent: 0,
          totalLate: 0,
          totalLeave: 0,
          totalUnmarked: 0,
          overallPercentage: null,
          studentStats: emptyStudentStats,
          subjectStats: emptySubjectStats,
          policy: policy,
        );
      }

      // 5. Fetch all records across completed sessions in a single efficient batch query
      final sessionIds = completedSessions.map((s) => s.id).toList();
      final records = await _recordDao.getBySessionIds(sessionIds);

      final sessionMap = {for (final s in completedSessions) s.id: s};

      // Class-wide totals
      int totalPresent = 0;
      int totalAbsent = 0;
      int totalLate = 0;
      int totalLeave = 0;
      int totalUnmarked = 0;

      final studentCounts = <String, Map<AttendanceStatus, int>>{};
      final studentSubjectCounts =
          <String, Map<String, Map<AttendanceStatus, int>>>{};
      final studentSessions = <String, Set<String>>{};

      final subjectCounts = <String, Map<AttendanceStatus, int>>{};

      for (final r in records) {
        final session = sessionMap[r.sessionId];
        if (session == null) continue;

        switch (r.status) {
          case AttendanceStatus.present:
            totalPresent++;
            break;
          case AttendanceStatus.absent:
            totalAbsent++;
            break;
          case AttendanceStatus.late:
            totalLate++;
            break;
          case AttendanceStatus.leave:
            totalLeave++;
            break;
          case AttendanceStatus.unmarked:
            totalUnmarked++;
            break;
        }

        studentCounts.putIfAbsent(r.studentId, () => {});
        studentCounts[r.studentId]![r.status] =
            (studentCounts[r.studentId]![r.status] ?? 0) + 1;

        studentSessions.putIfAbsent(r.studentId, () => {});
        studentSessions[r.studentId]!.add(r.sessionId);

        studentSubjectCounts.putIfAbsent(r.studentId, () => {});
        studentSubjectCounts[r.studentId]!.putIfAbsent(
          session.subjectId,
          () => {},
        );
        studentSubjectCounts[r.studentId]![session.subjectId]![r.status] =
            (studentSubjectCounts[r.studentId]![session.subjectId]![r.status] ??
                0) +
            1;

        subjectCounts.putIfAbsent(session.subjectId, () => {});
        subjectCounts[session.subjectId]![r.status] =
            (subjectCounts[session.subjectId]![r.status] ?? 0) + 1;
      }

      // 6. Build StudentAttendanceStats list
      final List<StudentAttendanceStats> studentStatsList = [];
      for (final student in allStudents) {
        final counts = studentCounts[student.id];
        final hasRecords = counts != null && counts.isNotEmpty;

        // Skip deactivated students if they have no records in this period
        if (!student.isActive && !hasRecords) {
          continue;
        }

        final p = counts?[AttendanceStatus.present] ?? 0;
        final a = counts?[AttendanceStatus.absent] ?? 0;
        final l = counts?[AttendanceStatus.late] ?? 0;
        final lv = counts?[AttendanceStatus.leave] ?? 0;
        final u = counts?[AttendanceStatus.unmarked] ?? 0;
        final sessionsCount =
            studentSessions[student.id]?.length ??
            (student.isActive ? completedSessions.length : 0);

        final pct = policy.calculatePercentage(
          presentCount: p,
          absentCount: a,
          lateCount: l,
          leaveCount: lv,
          unmarkedCount: u,
        );

        final subjectBreakdown = <String, SubjectAttendanceStats>{};
        final subMap = studentSubjectCounts[student.id];
        if (subMap != null) {
          for (final entry in subMap.entries) {
            final sId = entry.key;
            final subCounts = entry.value;
            final subModel = subjectsMap[sId];
            if (subModel != null) {
              final sp = subCounts[AttendanceStatus.present] ?? 0;
              final sa = subCounts[AttendanceStatus.absent] ?? 0;
              final sl = subCounts[AttendanceStatus.late] ?? 0;
              final slv = subCounts[AttendanceStatus.leave] ?? 0;
              final su = subCounts[AttendanceStatus.unmarked] ?? 0;
              final subSessions = completedSessions
                  .where((s) => s.subjectId == sId)
                  .length;
              final subPct = policy.calculatePercentage(
                presentCount: sp,
                absentCount: sa,
                lateCount: sl,
                leaveCount: slv,
                unmarkedCount: su,
              );
              subjectBreakdown[sId] = SubjectAttendanceStats(
                subject: subModel,
                totalSessions: subSessions,
                presentCount: sp,
                absentCount: sa,
                lateCount: sl,
                leaveCount: slv,
                unmarkedCount: su,
                percentage: subPct,
                isArchived: !subModel.isActive,
              );
            }
          }
        }

        studentStatsList.add(
          StudentAttendanceStats(
            student: student,
            totalSessions: sessionsCount,
            presentCount: p,
            absentCount: a,
            lateCount: l,
            leaveCount: lv,
            unmarkedCount: u,
            percentage: pct,
            isDeactivated: !student.isActive,
            subjectBreakdown: subjectBreakdown,
          ),
        );
      }

      // Sort students by normalized roll number
      studentStatsList.sort(
        (x, y) => x.student.normalizedRollNumber.compareTo(
          y.student.normalizedRollNumber,
        ),
      );

      // 7. Build SubjectAttendanceStats list
      final List<SubjectAttendanceStats> subjectStatsList = [];
      for (final subject in subjectsList) {
        final sessionsForSubject = completedSessions
            .where((s) => s.subjectId == subject.id)
            .length;
        final counts = subjectCounts[subject.id];
        final hasActivity =
            sessionsForSubject > 0 || (counts != null && counts.isNotEmpty);

        // Skip archived subject if it has no activity in this period
        if (!subject.isActive && !hasActivity) {
          continue;
        }

        final p = counts?[AttendanceStatus.present] ?? 0;
        final a = counts?[AttendanceStatus.absent] ?? 0;
        final l = counts?[AttendanceStatus.late] ?? 0;
        final lv = counts?[AttendanceStatus.leave] ?? 0;
        final u = counts?[AttendanceStatus.unmarked] ?? 0;

        final pct = policy.calculatePercentage(
          presentCount: p,
          absentCount: a,
          lateCount: l,
          leaveCount: lv,
          unmarkedCount: u,
        );

        subjectStatsList.add(
          SubjectAttendanceStats(
            subject: subject,
            totalSessions: sessionsForSubject,
            presentCount: p,
            absentCount: a,
            lateCount: l,
            leaveCount: lv,
            unmarkedCount: u,
            percentage: pct,
            isArchived: !subject.isActive,
          ),
        );
      }

      subjectStatsList.sort(
        (x, y) => x.subject.name.toLowerCase().compareTo(
          y.subject.name.toLowerCase(),
        ),
      );

      // 8. Overall class percentage
      final overallPct = policy.calculatePercentage(
        presentCount: totalPresent,
        absentCount: totalAbsent,
        lateCount: totalLate,
        leaveCount: totalLeave,
        unmarkedCount: totalUnmarked,
      );

      return ClassAttendanceReport(
        classId: classId,
        classModel: classModel,
        startDate: startDate,
        endDate: endDate,
        subjectId: subjectId,
        totalCompletedSessions: completedSessions.length,
        totalRecords: records.length,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
        totalLate: totalLate,
        totalLeave: totalLeave,
        totalUnmarked: totalUnmarked,
        overallPercentage: overallPct,
        studentStats: studentStatsList,
        subjectStats: subjectStatsList,
        policy: policy,
      );
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to generate class attendance report for class $classId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getRecordsForStudent(
    String studentId,
  ) async {
    try {
      return await _recordDao.getByStudentId(studentId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve records for student $studentId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<AttendanceSessionWithRecords> saveSessionWithRecordsAtomic({
    required AttendanceSessionModel session,
    required List<AttendanceRecordModel> records,
    String? actorReference,
    String? reason,
  }) async {
    // -------------------------------------------------------------------------
    // 1. DATA VALIDATION & RELATIONSHIP INTEGRITY CHECKS (Before Transaction)
    // -------------------------------------------------------------------------
    final targetClass = await _classDao.getById(session.classId);
    if (targetClass == null) {
      throw RecordNotFoundException('Class', session.classId);
    }

    final targetSubject = await _subjectDao.getById(session.subjectId);
    if (targetSubject == null) {
      throw RecordNotFoundException('Subject', session.subjectId);
    }
    if (targetSubject.classId != session.classId) {
      throw ValidationException(
        'Subject "${targetSubject.name}" (${targetSubject.id}) does not belong to Class ${session.classId}.',
      );
    }

    // Check Duplicate Session Rule
    final isDuplicate = await checkDuplicateSession(
      session.classId,
      session.subjectId,
      session.parsedDate,
      session.period,
      excludeSessionId: session.id,
    );
    if (isDuplicate) {
      throw DuplicateSessionException(
        subjectId: session.subjectId,
        sessionDate: session.sessionDate,
        period: session.period,
      );
    }

    // Check duplicate student records within the same input batch
    final seenStudentIds = <String>{};
    for (final record in records) {
      if (!seenStudentIds.add(record.studentId)) {
        throw ValidationException(
          'Duplicate attendance record submitted for student ID "${record.studentId}" in session ${session.id}.',
        );
      }
    }

    // Cross-Class Relationship Check: Verify every student belongs to session.classId
    for (final record in records) {
      final student = await _studentDao.getById(record.studentId);
      if (student == null) {
        throw RecordNotFoundException('Student', record.studentId);
      }
      if (student.classId != session.classId) {
        throw CrossClassRelationshipException(
          studentId: student.id,
          studentClassId: student.classId,
          sessionId: session.id,
          sessionClassId: session.classId,
        );
      }
    }

    // Check Attendance Completion Policy
    if (session.status.toUpperCase() == 'COMPLETED') {
      final hasUnmarked = records.any(
        (r) => r.status == AttendanceStatus.unmarked,
      );
      if (hasUnmarked) {
        throw ValidationException(
          'Cannot mark attendance session as COMPLETED while unmarked students remain.',
        );
      }
    }

    // -------------------------------------------------------------------------
    // 2. ATOMIC TRANSACTION EXECUTION
    // -------------------------------------------------------------------------
    return await _db.runInTransaction((txn) async {
      final existingSession = await _sessionDao.getById(
        session.id,
        executor: txn,
      );
      final isNewSession = existingSession == null;

      if (isNewSession) {
        await _sessionDao.insert(session, executor: txn);
      } else {
        await _sessionDao.update(session, executor: txn);
      }

      final now = DateTime.now();
      final savedRecords = <AttendanceRecordModel>[];

      // Upsert all student attendance records & record audit events
      for (final record in records) {
        final existingRecord = await _recordDao.getBySessionAndStudent(
          session.id,
          record.studentId,
          executor: txn,
        );

        final stableId =
            existingRecord?.id ?? (record.id.isEmpty ? _uuid.v4() : record.id);
        final normalizedRecord = record.copyWith(
          id: stableId,
          sessionId: session.id,
          updatedAt: now,
        );

        await _recordDao.upsert(normalizedRecord, executor: txn);
        savedRecords.add(normalizedRecord);

        // Record-level audit logging within transaction
        if (existingRecord == null) {
          final recordAudit = AuditEventModel(
            id: _uuid.v4(),
            entityType: 'attendance_record',
            entityId: stableId,
            eventType: 'RECORD_CREATED',
            previousValue: null,
            newValue: AttendanceRecordModel.statusToDbString(
              normalizedRecord.status,
            ),
            actorReference: actorReference,
            reason: reason ?? 'Initial attendance record',
            createdAt: now,
          );
          await _auditDao.insert(recordAudit, executor: txn);
        } else if (existingRecord.status != normalizedRecord.status) {
          final recordAudit = AuditEventModel(
            id: _uuid.v4(),
            entityType: 'attendance_record',
            entityId: stableId,
            eventType: 'STATUS_CORRECTION',
            previousValue: AttendanceRecordModel.statusToDbString(
              existingRecord.status,
            ),
            newValue: AttendanceRecordModel.statusToDbString(
              normalizedRecord.status,
            ),
            actorReference: actorReference,
            reason: reason ?? 'Attendance status correction',
            createdAt: now,
          );
          await _auditDao.insert(recordAudit, executor: txn);
        }
      }

      // Session-level audit logging within transaction
      final sessionEventType = isNewSession
          ? 'SESSION_CREATED'
          : (session.status.toUpperCase() == 'COMPLETED' &&
                    existingSession.status.toUpperCase() != 'COMPLETED'
                ? 'SESSION_COMPLETED'
                : 'SESSION_UPDATED');

      final sessionAudit = AuditEventModel(
        id: _uuid.v4(),
        entityType: 'attendance_session',
        entityId: session.id,
        eventType: sessionEventType,
        previousValue: isNewSession ? null : existingSession.status,
        newValue: session.status,
        actorReference: actorReference,
        reason:
            reason ??
            (isNewSession
                ? 'Initial session recording'
                : (session.status.toUpperCase() == 'COMPLETED'
                      ? 'Session completed'
                      : 'Session updated')),
        createdAt: now,
      );
      await _auditDao.insert(sessionAudit, executor: txn);

      return AttendanceSessionWithRecords(
        session: session,
        records: savedRecords,
      );
    });
  }

  @override
  Future<AttendanceRecordModel> updateRecordStatusWithAudit({
    required AttendanceRecordModel record,
    required AttendanceStatus oldStatus,
    String? actorReference,
    String? reason,
  }) async {
    final existing = await _recordDao.getBySessionAndStudent(
      record.sessionId,
      record.studentId,
    );
    if (existing == null) {
      throw RecordNotFoundException('AttendanceRecord', record.id);
    }

    return await _db.runInTransaction((txn) async {
      final updated = record.copyWith(updatedAt: DateTime.now());
      final rows = await _recordDao.update(updated, executor: txn);
      if (rows == 0) {
        throw RecordNotFoundException('AttendanceRecord', record.id);
      }

      // Audit event for single record correction
      final auditEvent = AuditEventModel(
        id: _uuid.v4(),
        entityType: 'attendance_record',
        entityId: record.id,
        eventType: 'STATUS_CORRECTION',
        previousValue: AttendanceRecordModel.statusToDbString(oldStatus),
        newValue: AttendanceRecordModel.statusToDbString(record.status),
        actorReference: actorReference,
        reason: reason ?? 'Correction of attendance status',
        createdAt: DateTime.now(),
      );
      await _auditDao.insert(auditEvent, executor: txn);

      return updated;
    });
  }
}
