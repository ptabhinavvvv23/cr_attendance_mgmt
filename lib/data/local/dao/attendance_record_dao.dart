import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/attendance_record_model.dart';

/// Data Access Object for individual Student Attendance Records in a session.
class AttendanceRecordDao {
  final AppDatabase _db;

  AttendanceRecordDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    AttendanceRecordModel record, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableAttendanceRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> insertBatch(
    List<AttendanceRecordModel> records, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    if (exec is Batch) {
      for (final record in records) {
        exec.insert(
          DbConstants.tableAttendanceRecords,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    } else {
      // Use SQLite batch if not already on a Batch object
      final db = await _db.database;
      final batch = db.batch();
      for (final record in records) {
        batch.insert(
          DbConstants.tableAttendanceRecords,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<AttendanceRecordModel>> getBySessionId(
    String sessionId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceRecords,
      where: '${DbConstants.colRecordSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: '${DbConstants.colCreatedAt} ASC',
    );
    return results.map((m) => AttendanceRecordModel.fromMap(m)).toList();
  }

  Future<List<AttendanceRecordModel>> getBySessionIds(
    List<String> sessionIds, {
    DatabaseExecutor? executor,
  }) async {
    if (sessionIds.isEmpty) return [];
    final exec = await _getExecutor(executor);
    final List<AttendanceRecordModel> allRecords = [];
    const chunkSize = 500;
    for (var i = 0; i < sessionIds.length; i += chunkSize) {
      final chunk = sessionIds.sublist(
        i,
        i + chunkSize > sessionIds.length ? sessionIds.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final results = await exec.query(
        DbConstants.tableAttendanceRecords,
        where: '${DbConstants.colRecordSessionId} IN ($placeholders)',
        whereArgs: chunk,
        orderBy: '${DbConstants.colCreatedAt} ASC',
      );
      allRecords.addAll(results.map((m) => AttendanceRecordModel.fromMap(m)));
    }
    return allRecords;
  }

  Future<List<AttendanceRecordModel>> getByStudentId(
    String studentId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceRecords,
      where: '${DbConstants.colRecordStudentId} = ?',
      whereArgs: [studentId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return results.map((m) => AttendanceRecordModel.fromMap(m)).toList();
  }

  Future<AttendanceRecordModel?> getBySessionAndStudent(
    String sessionId,
    String studentId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAttendanceRecords,
      where:
          '${DbConstants.colRecordSessionId} = ? AND ${DbConstants.colRecordStudentId} = ?',
      whereArgs: [sessionId, studentId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AttendanceRecordModel.fromMap(results.first);
  }

  Future<int> update(
    AttendanceRecordModel record, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableAttendanceRecords,
      record.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> upsert(
    AttendanceRecordModel record, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableAttendanceRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteBySessionId(
    String sessionId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    return await exec.delete(
      DbConstants.tableAttendanceRecords,
      where: '${DbConstants.colRecordSessionId} = ?',
      whereArgs: [sessionId],
    );
  }
}
