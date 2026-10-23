import '../../core/theme/app_colors.dart';

/// Persistent representation of a single Student's Attendance Record in a Session.
class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String studentId;
  final AttendanceStatus status;
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.status,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Maps [AttendanceStatus] enum to a stable, explicit uppercase string in the database.
  /// Never relies on enum ordinals which can shift when code changes.
  static String statusToDbString(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'PRESENT';
      case AttendanceStatus.absent:
        return 'ABSENT';
      case AttendanceStatus.late:
        return 'LATE';
      case AttendanceStatus.leave:
        return 'LEAVE';
      case AttendanceStatus.unmarked:
        return 'UNMARKED';
    }
  }

  /// Parses a database status string into the domain [AttendanceStatus] enum.
  static AttendanceStatus parseDbStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LATE':
        return AttendanceStatus.late;
      case 'LEAVE':
        return AttendanceStatus.leave;
      case 'UNMARKED':
      default:
        return AttendanceStatus.unmarked;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'status': statusToDbString(status),
      'remarks': remarks?.trim(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      studentId: map['student_id'] as String,
      status: parseDbStatus(map['status'] as String? ?? 'UNMARKED'),
      remarks: map['remarks'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  AttendanceRecordModel copyWith({
    String? id,
    String? sessionId,
    String? studentId,
    AttendanceStatus? status,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceRecordModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecordModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
