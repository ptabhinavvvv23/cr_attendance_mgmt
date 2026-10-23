import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../db_constants.dart';
import '../../models/audit_event_model.dart';

/// Data Access Object for append-oriented Audit Event records.
class AuditEventDao {
  final AppDatabase _db;

  AuditEventDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db.database;
  }

  Future<void> insert(
    AuditEventModel event, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    await exec.insert(
      DbConstants.tableAuditEvents,
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<AuditEventModel>> getByEntity(
    String entityType,
    String entityId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAuditEvents,
      where:
          '${DbConstants.colEntityType} = ? AND ${DbConstants.colEntityId} = ?',
      whereArgs: [entityType, entityId],
      orderBy: '${DbConstants.colCreatedAt} ASC',
    );
    return results.map((m) => AuditEventModel.fromMap(m)).toList();
  }

  Future<List<AuditEventModel>> getRecent({
    int limit = 50,
    DatabaseExecutor? executor,
  }) async {
    final exec = await _getExecutor(executor);
    final results = await exec.query(
      DbConstants.tableAuditEvents,
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: limit,
    );
    return results.map((m) => AuditEventModel.fromMap(m)).toList();
  }
}
