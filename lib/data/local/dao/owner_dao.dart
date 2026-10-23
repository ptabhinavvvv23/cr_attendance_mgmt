import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/owner_model.dart';

/// Data Access Object for CR identity and local owner records.
class OwnerDao {
  final AppDatabase _db;

  OwnerDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(OwnerModel owner, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableOwners,
      owner.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<OwnerModel?> getById(String id, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableOwners,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return OwnerModel.fromMap(results.first);
  }

  Future<OwnerModel?> getCurrentOwner({DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableOwners,
      orderBy: '${DbConstants.colCreatedAt} ASC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return OwnerModel.fromMap(results.first);
  }

  Future<int> update(OwnerModel owner, {DatabaseExecutor? executor}) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableOwners,
      owner.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [owner.id],
    );
  }
}
