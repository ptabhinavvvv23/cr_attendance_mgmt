import 'package:uuid/uuid.dart';

import '../../core/errors/database_exception.dart';
import '../local/dao/audit_event_dao.dart';
import '../models/audit_event_model.dart';

/// Repository contract for append-oriented Audit Event operations.
abstract class AuditRepository {
  Future<void> recordEvent({
    required String entityType,
    required String entityId,
    required String eventType,
    String? previousValue,
    String? newValue,
    String? actorReference,
    String? reason,
  });

  Future<List<AuditEventModel>> getEventsForEntity(
    String entityType,
    String entityId,
  );

  Future<List<AuditEventModel>> getRecentEvents({int limit = 50});
}

/// Concrete SQLite implementation of [AuditRepository].
class AuditRepositoryImpl implements AuditRepository {
  final AuditEventDao _auditDao;
  final Uuid _uuid;

  AuditRepositoryImpl({AuditEventDao? auditDao, Uuid? uuid})
    : _auditDao = auditDao ?? AuditEventDao(),
      _uuid = uuid ?? const Uuid();

  @override
  Future<void> recordEvent({
    required String entityType,
    required String entityId,
    required String eventType,
    String? previousValue,
    String? newValue,
    String? actorReference,
    String? reason,
  }) async {
    final event = AuditEventModel(
      id: _uuid.v4(),
      entityType: entityType.trim(),
      entityId: entityId.trim(),
      eventType: eventType.trim().toUpperCase(),
      previousValue: previousValue,
      newValue: newValue,
      actorReference: actorReference?.trim(),
      reason: reason?.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _auditDao.insert(event);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to record audit event: $e', e, st);
    }
  }

  @override
  Future<List<AuditEventModel>> getEventsForEntity(
    String entityType,
    String entityId,
  ) async {
    try {
      return await _auditDao.getByEntity(entityType, entityId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve audit events for $entityType $entityId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<AuditEventModel>> getRecentEvents({int limit = 50}) async {
    try {
      return await _auditDao.getRecent(limit: limit);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve recent audit events: $e',
        e,
        st,
      );
    }
  }
}
