import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/class_model.dart';

/// Data Access Object for Class profile records.
class ClassDao {
  final AppDatabase _db;

  ClassDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    ClassModel classModel, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableClasses,
      classModel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<ClassModel?> getById(String id, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableClasses,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ClassModel.fromMap(results.first);
  }

  Future<List<ClassModel>> getByOwnerId(
    String ownerId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableClasses,
      where: '${DbConstants.colOwnerId} = ?',
      whereArgs: [ownerId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return results.map((m) => ClassModel.fromMap(m)).toList();
  }

  Future<ClassModel?> getActiveClassForOwner(
    String ownerId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableClasses,
      where: '${DbConstants.colOwnerId} = ? AND ${DbConstants.colIsActive} = 1',
      whereArgs: [ownerId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ClassModel.fromMap(results.first);
  }

  Future<int> update(
    ClassModel classModel, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableClasses,
      classModel.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [classModel.id],
    );
  }
}
