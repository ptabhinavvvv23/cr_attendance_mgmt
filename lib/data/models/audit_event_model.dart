/// Persistent representation of an append-oriented Audit Event for historical traceability.
class AuditEventModel {
  final String id;
  final String entityType;
  final String entityId;
  final String eventType;
  final String? previousValue;
  final String? newValue;
  final String? actorReference;
  final String? reason;
  final DateTime createdAt;

  const AuditEventModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.eventType,
    this.previousValue,
    this.newValue,
    this.actorReference,
    this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType.trim(),
      'entity_id': entityId.trim(),
      'event_type': eventType.trim().toUpperCase(),
      'previous_value': previousValue,
      'new_value': newValue,
      'actor_reference': actorReference?.trim(),
      'reason': reason?.trim(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AuditEventModel.fromMap(Map<String, dynamic> map) {
    return AuditEventModel(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      eventType: map['event_type'] as String,
      previousValue: map['previous_value'] as String?,
      newValue: map['new_value'] as String?,
      actorReference: map['actor_reference'] as String?,
      reason: map['reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEventModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
