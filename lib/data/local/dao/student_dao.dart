import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/student_model.dart';

/// Data Access Object for Student records.
class StudentDao {
  final AppDatabase _db;

  StudentDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    StudentModel student, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableStudents,
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<StudentModel?> getById(String id, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableStudents,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return StudentModel.fromMap(results.first);
  }

  Future<StudentModel?> getByRollNumber(
    String classId,
    String normalizedRoll, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableStudents,
      where:
          '${DbConstants.colStudentClassId} = ? AND ${DbConstants.colNormalizedRollNumber} = ?',
      whereArgs: [classId, normalizedRoll],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return StudentModel.fromMap(results.first);
  }

  Future<List<StudentModel>> getByClassId(
    String classId, {
    bool activeOnly = false,
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final whereClause = activeOnly
        ? '${DbConstants.colStudentClassId} = ? AND ${DbConstants.colIsActive} = 1'
        : '${DbConstants.colStudentClassId} = ?';

    final results = await exec.query(
      DbConstants.tableStudents,
      where: whereClause,
      whereArgs: [classId],
      orderBy: '${DbConstants.colNormalizedRollNumber} ASC',
    );
    return results.map((m) => StudentModel.fromMap(m)).toList();
  }

  Future<List<StudentModel>> search(
    String classId,
    String query, {
    bool activeOnly = false,
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final cleanQuery = '%${query.trim().toLowerCase()}%';
    final normalizedRollQuery = '%${StudentModel.normalizeRollNumber(query)}%';

    String whereClause =
        '(${DbConstants.colStudentClassId} = ?) AND '
        '(${DbConstants.colNormalizedRollNumber} LIKE ? OR LOWER(${DbConstants.colStudentName}) LIKE ?)';
    List<dynamic> whereArgs = [classId, normalizedRollQuery, cleanQuery];

    if (activeOnly) {
      whereClause += ' AND ${DbConstants.colIsActive} = 1';
    }

    final results = await exec.query(
      DbConstants.tableStudents,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: '${DbConstants.colNormalizedRollNumber} ASC',
    );
    return results.map((m) => StudentModel.fromMap(m)).toList();
  }

  Future<int> update(StudentModel student, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableStudents,
      student.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deactivate(String studentId, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableStudents,
      {
        DbConstants.colIsActive: 0,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [studentId],
    );
  }

  Future<int> countAttendanceRecords(
    String studentId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableAttendanceRecords} '
      'WHERE ${DbConstants.colRecordStudentId} = ?',
      [studentId],
    );
    return Sqflite.firstIntValue(results) ?? 0;
  }
}
