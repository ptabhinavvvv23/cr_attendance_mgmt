/// Persistent representation of an Attendance Session.
///
/// An attendance session represents a single classroom period or attendance-taking
/// instance for a specific subject, class, and calendar date.
class AttendanceSessionModel {
  final String id;
  final String classId;
  final String subjectId;

  /// Normalized calendar date stored as 'YYYY-MM-DD'.
  final String sessionDate;

  /// Period or lecture slot identifier (e.g. '1', '2', 'Lab', 'Morning').
  /// Allows the same subject to legitimately have multiple distinct sessions on the same date.
  final String period;

  /// Session status: e.g. 'COMPLETED', 'SCHEDULED', 'CANCELLED'.
  final String status;

  /// Optional notes or remarks regarding the session.
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceSessionModel({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.sessionDate,
    this.period = '1',
    this.status = 'COMPLETED',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Normalizes a [DateTime] into a standard 'YYYY-MM-DD' string for session grouping.
  static String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses the normalized 'YYYY-MM-DD' [sessionDate] back to a [DateTime].
  DateTime get parsedDate => DateTime.parse(sessionDate);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'subject_id': subjectId,
      'session_date': sessionDate,
      'period': period.trim().isEmpty ? '1' : period.trim(),
      'status': status.toUpperCase(),
      'notes': notes?.trim(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AttendanceSessionModel.fromMap(Map<String, dynamic> map) {
    return AttendanceSessionModel(
      id: map['id'] as String,
      classId: map['class_id'] as String,
      subjectId: map['subject_id'] as String,
      sessionDate: map['session_date'] as String,
      period: (map['period'] as String?) ?? '1',
      status: (map['status'] as String?) ?? 'COMPLETED',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  AttendanceSessionModel copyWith({
    String? id,
    String? classId,
    String? subjectId,
    String? sessionDate,
    String? period,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceSessionModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      subjectId: subjectId ?? this.subjectId,
      sessionDate: sessionDate ?? this.sessionDate,
      period: period ?? this.period,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceSessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
