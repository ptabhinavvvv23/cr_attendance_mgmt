import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/attendance_session_model.dart';

/// Data Access Object for Attendance Session records.
class AttendanceSessionDao {
  final AppDatabase _db;

  AttendanceSessionDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    AttendanceSessionModel session, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableAttendanceSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<AttendanceSessionModel?> getById(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceSessions,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AttendanceSessionModel.fromMap(results.first);
  }

  Future<List<AttendanceSessionModel>> getByClassId(
    String classId, {
    int? limit,
    int? offset,
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceSessions,
      where: '${DbConstants.colSessionClassId} = ?',
      whereArgs: [classId],
      orderBy:
          '${DbConstants.colSessionDate} DESC, ${DbConstants.colPeriod} ASC',
      limit: limit,
      offset: offset,
    );
    return results.map((m) => AttendanceSessionModel.fromMap(m)).toList();
  }

  Future<List<AttendanceSessionModel>> getByDateRange(
    String classId,
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceSessions,
      where:
          '${DbConstants.colSessionClassId} = ? AND '
          '${DbConstants.colSessionDate} >= ? AND ${DbConstants.colSessionDate} <= ?',
      whereArgs: [classId, startDate, endDate],
      orderBy:
          '${DbConstants.colSessionDate} DESC, ${DbConstants.colPeriod} ASC',
    );
    return results.map((m) => AttendanceSessionModel.fromMap(m)).toList();
  }

  Future<List<AttendanceSessionModel>> getBySubject(
    String subjectId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceSessions,
      where: '${DbConstants.colSessionSubjectId} = ?',
      whereArgs: [subjectId],
      orderBy:
          '${DbConstants.colSessionDate} DESC, ${DbConstants.colPeriod} ASC',
    );
    return results.map((m) => AttendanceSessionModel.fromMap(m)).toList();
  }

  Future<List<AttendanceSessionModel>> getCompletedSessions(
    String classId, {
    String? subjectId,
    String? startDate,
    String? endDate,
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final whereClauses = <String>[
      '${DbConstants.colSessionClassId} = ?',
      'UPPER(${DbConstants.colSessionStatus}) = ?',
    ];
    final whereArgs = <dynamic>[classId, 'COMPLETED'];

    if (subjectId != null && subjectId.isNotEmpty) {
      whereClauses.add('${DbConstants.colSessionSubjectId} = ?');
      whereArgs.add(subjectId);
    }
    if (startDate != null && startDate.isNotEmpty) {
      whereClauses.add('${DbConstants.colSessionDate} >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClauses.add('${DbConstants.colSessionDate} <= ?');
      whereArgs.add(endDate);
    }

    final results = await exec.query(
      DbConstants.tableAttendanceSessions,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy:
          '${DbConstants.colSessionDate} DESC, ${DbConstants.colPeriod} ASC',
    );
    return results.map((m) => AttendanceSessionModel.fromMap(m)).toList();
  }

  Future<AttendanceSessionModel?> checkDuplicateSession(
    String classId,
    String subjectId,
    String sessionDate,
    String period, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceSessions,
      where:
          '${DbConstants.colSessionClassId} = ? AND '
          '${DbConstants.colSessionSubjectId} = ? AND '
          '${DbConstants.colSessionDate} = ? AND '
          '${DbConstants.colPeriod} = ?',
      whereArgs: [
        classId,
        subjectId,
        sessionDate,
        period.trim().isEmpty ? '1' : period.trim(),
      ],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AttendanceSessionModel.fromMap(results.first);
  }

  Future<int> update(
    AttendanceSessionModel session, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableAttendanceSessions,
      session.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [session.id],
    );
  }
}
