/// Database constants including filename, schema version, table names, and column definitions.
class DbConstants {
  DbConstants._();

  static const String databaseName = 'cr_attendance.db';
  static const int currentSchemaVersion = 1;

  // Table names
  static const String tableOwners = 'owners';
  static const String tableClasses = 'classes';
  static const String tableSubjects = 'subjects';
  static const String tableStudents = 'students';
  static const String tableAttendanceSessions = 'attendance_sessions';
  static const String tableAttendanceRecords = 'attendance_records';
  static const String tableAuditEvents = 'audit_events';
  static const String tableBackupMetadata = 'backup_metadata';

  // Common columns
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colIsActive = 'is_active';

  // Owners columns
  static const String colRegistrationNumber = 'registration_number';
  static const String colDisplayName = 'display_name';
  static const String colEmail = 'email';
  static const String colMetadata = 'metadata';

  // Classes columns
  static const String colOwnerId = 'owner_id';
  static const String colClassName = 'name';
  static const String colAcademicYear = 'academic_year';
  static const String colSection = 'section';
  static const String colSemester = 'semester';

  // Subjects columns
  static const String colSubjectClassId = 'class_id';
  static const String colSubjectName = 'name';
  static const String colSubjectCode = 'code';

  // Students columns
  static const String colStudentClassId = 'class_id';
  static const String colRollNumber = 'roll_number';
  static const String colNormalizedRollNumber = 'normalized_roll_number';
  static const String colStudentName = 'name';

  // Attendance Sessions columns
  static const String colSessionClassId = 'class_id';
  static const String colSessionSubjectId = 'subject_id';
  static const String colSessionDate = 'session_date';
  static const String colPeriod = 'period';
  static const String colSessionStatus = 'status';
  static const String colNotes = 'notes';

  // Attendance Records columns
  static const String colRecordSessionId = 'session_id';
  static const String colRecordStudentId = 'student_id';
  static const String colRecordStatus = 'status';
  static const String colRemarks = 'remarks';

  // Audit Events columns
  static const String colEntityType = 'entity_type';
  static const String colEntityId = 'entity_id';
  static const String colEventType = 'event_type';
  static const String colPreviousValue = 'previous_value';
  static const String colNewValue = 'new_value';
  static const String colActorReference = 'actor_reference';
  static const String colReason = 'reason';

  // Backup Metadata columns
  static const String colBackupOwnerId = 'owner_id';
  static const String colBackupClassId = 'class_id';
  static const String colFormatVersion = 'format_version';
  static const String colSchemaVersion = 'schema_version';
  static const String colBackupStatus = 'status';
  static const String colStorageReference = 'storage_reference';
  static const String colChecksum = 'checksum';
  static const String colFileSizeBytes = 'file_size_bytes';
  static const String colErrorMessage = 'error_message';
}
