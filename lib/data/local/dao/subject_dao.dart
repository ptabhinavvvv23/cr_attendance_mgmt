import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/subject_model.dart';

/// Data Access Object for Subject records.
class SubjectDao {
  final AppDatabase _db;

  SubjectDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    SubjectModel subject, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableSubjects,
      subject.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<SubjectModel?> getById(String id, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableSubjects,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SubjectModel.fromMap(results.first);
  }

  Future<List<SubjectModel>> getByClassId(
    String classId, {
    bool activeOnly = false,
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final whereClause = activeOnly
        ? '${DbConstants.colSubjectClassId} = ? AND ${DbConstants.colIsActive} = 1'
        : '${DbConstants.colSubjectClassId} = ?';

    final results = await exec.query(
      DbConstants.tableSubjects,
      where: whereClause,
      whereArgs: [classId],
      orderBy: '${DbConstants.colSubjectName} ASC',
    );
    return results.map((m) => SubjectModel.fromMap(m)).toList();
  }

  Future<SubjectModel?> getByName(
    String classId,
    String name, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableSubjects,
      where:
          '${DbConstants.colSubjectClassId} = ? AND ${DbConstants.colSubjectName} = ?',
      whereArgs: [classId, name.trim()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SubjectModel.fromMap(results.first);
  }

  Future<int> update(SubjectModel subject, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableSubjects,
      subject.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [subject.id],
    );
  }

  Future<int> countSessionsForSubject(
    String subjectId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableAttendanceSessions} '
      'WHERE ${DbConstants.colSessionSubjectId} = ?',
      [subjectId],
    );
    return Sqflite.firstIntValue(results) ?? 0;
  }
}
