import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/backup_metadata_model.dart';

/// Data Access Object for Backup Metadata records.
class BackupMetadataDao {
  final AppDatabase _db;

  BackupMetadataDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    BackupMetadataModel backup, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableBackupMetadata,
      backup.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<BackupMetadataModel?> getById(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableBackupMetadata,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return BackupMetadataModel.fromMap(results.first);
  }

  Future<BackupMetadataModel?> getLatestForOwner(
    String ownerId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableBackupMetadata,
      where: '${DbConstants.colBackupOwnerId} = ?',
      whereArgs: [ownerId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return BackupMetadataModel.fromMap(results.first);
  }

  Future<List<BackupMetadataModel>> getAllForOwner(
    String ownerId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableBackupMetadata,
      where: '${DbConstants.colBackupOwnerId} = ?',
      whereArgs: [ownerId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return results.map((m) => BackupMetadataModel.fromMap(m)).toList();
  }

  Future<int> update(
    BackupMetadataModel backup, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    return await exec.update(
      DbConstants.tableBackupMetadata,
      backup.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [backup.id],
    );
  }
}
