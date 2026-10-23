import 'package:sqflite/sqflite.dart';

import '../db_constants.dart';

/// Database schema definition containing all table DDL scripts, constraints, and indexes.
class AppSchema {
  AppSchema._();

  static const List<String> createTablesQueries = [
    // 1. Owners
    '''
    CREATE TABLE ${DbConstants.tableOwners} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colRegistrationNumber} TEXT NOT NULL,
      ${DbConstants.colDisplayName} TEXT,
      ${DbConstants.colEmail} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      ${DbConstants.colMetadata} TEXT
    );
    ''',

    // 2. Classes
    '''
    CREATE TABLE ${DbConstants.tableClasses} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colOwnerId} TEXT NOT NULL,
      ${DbConstants.colClassName} TEXT NOT NULL,
      ${DbConstants.colAcademicYear} TEXT NOT NULL,
      ${DbConstants.colSection} TEXT NOT NULL,
      ${DbConstants.colSemester} TEXT,
      ${DbConstants.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colOwnerId}) REFERENCES ${DbConstants.tableOwners} (${DbConstants.colId}) ON DELETE RESTRICT
    );
    ''',

    // 3. Subjects
    '''
    CREATE TABLE ${DbConstants.tableSubjects} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colSubjectClassId} TEXT NOT NULL,
      ${DbConstants.colSubjectName} TEXT NOT NULL,
      ${DbConstants.colSubjectCode} TEXT,
      ${DbConstants.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colSubjectClassId}) REFERENCES ${DbConstants.tableClasses} (${DbConstants.colId}) ON DELETE RESTRICT,
      CONSTRAINT uq_subject_class_name UNIQUE (${DbConstants.colSubjectClassId}, ${DbConstants.colSubjectName})
    );
    ''',

    // 4. Students
    '''
    CREATE TABLE ${DbConstants.tableStudents} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colStudentClassId} TEXT NOT NULL,
      ${DbConstants.colRollNumber} TEXT NOT NULL,
      ${DbConstants.colNormalizedRollNumber} TEXT NOT NULL,
      ${DbConstants.colStudentName} TEXT NOT NULL,
      ${DbConstants.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colStudentClassId}) REFERENCES ${DbConstants.tableClasses} (${DbConstants.colId}) ON DELETE RESTRICT,
      CONSTRAINT uq_student_class_roll UNIQUE (${DbConstants.colStudentClassId}, ${DbConstants.colNormalizedRollNumber})
    );
    ''',

    // 5. Attendance Sessions
    '''
    CREATE TABLE ${DbConstants.tableAttendanceSessions} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colSessionClassId} TEXT NOT NULL,
      ${DbConstants.colSessionSubjectId} TEXT NOT NULL,
      ${DbConstants.colSessionDate} TEXT NOT NULL,
      ${DbConstants.colPeriod} TEXT NOT NULL DEFAULT '1',
      ${DbConstants.colSessionStatus} TEXT NOT NULL DEFAULT 'COMPLETED',
      ${DbConstants.colNotes} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colSessionClassId}) REFERENCES ${DbConstants.tableClasses} (${DbConstants.colId}) ON DELETE RESTRICT,
      FOREIGN KEY (${DbConstants.colSessionSubjectId}) REFERENCES ${DbConstants.tableSubjects} (${DbConstants.colId}) ON DELETE RESTRICT,
      CONSTRAINT uq_session_class_sub_date_period UNIQUE (${DbConstants.colSessionClassId}, ${DbConstants.colSessionSubjectId}, ${DbConstants.colSessionDate}, ${DbConstants.colPeriod})
    );
    ''',

    // 6. Attendance Records
    '''
    CREATE TABLE ${DbConstants.tableAttendanceRecords} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colRecordSessionId} TEXT NOT NULL,
      ${DbConstants.colRecordStudentId} TEXT NOT NULL,
      ${DbConstants.colRecordStatus} TEXT NOT NULL,
      ${DbConstants.colRemarks} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colRecordSessionId}) REFERENCES ${DbConstants.tableAttendanceSessions} (${DbConstants.colId}) ON DELETE CASCADE,
      FOREIGN KEY (${DbConstants.colRecordStudentId}) REFERENCES ${DbConstants.tableStudents} (${DbConstants.colId}) ON DELETE RESTRICT,
      CONSTRAINT uq_record_session_student UNIQUE (${DbConstants.colRecordSessionId}, ${DbConstants.colRecordStudentId})
    );
    ''',

    // 7. Audit Events
    '''
    CREATE TABLE ${DbConstants.tableAuditEvents} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colEntityType} TEXT NOT NULL,
      ${DbConstants.colEntityId} TEXT NOT NULL,
      ${DbConstants.colEventType} TEXT NOT NULL,
      ${DbConstants.colPreviousValue} TEXT,
      ${DbConstants.colNewValue} TEXT,
      ${DbConstants.colActorReference} TEXT,
      ${DbConstants.colReason} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL
    );
    ''',

    // 8. Backup Metadata
    '''
    CREATE TABLE ${DbConstants.tableBackupMetadata} (
      ${DbConstants.colId} TEXT PRIMARY KEY,
      ${DbConstants.colBackupOwnerId} TEXT NOT NULL,
      ${DbConstants.colBackupClassId} TEXT NOT NULL,
      ${DbConstants.colFormatVersion} INTEGER NOT NULL DEFAULT 1,
      ${DbConstants.colSchemaVersion} INTEGER NOT NULL,
      ${DbConstants.colBackupStatus} TEXT NOT NULL,
      ${DbConstants.colStorageReference} TEXT,
      ${DbConstants.colChecksum} TEXT,
      ${DbConstants.colFileSizeBytes} INTEGER,
      ${DbConstants.colErrorMessage} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      FOREIGN KEY (${DbConstants.colBackupOwnerId}) REFERENCES ${DbConstants.tableOwners} (${DbConstants.colId}) ON DELETE RESTRICT,
      FOREIGN KEY (${DbConstants.colBackupClassId}) REFERENCES ${DbConstants.tableClasses} (${DbConstants.colId}) ON DELETE RESTRICT
    );
    ''',
  ];

  static const List<String> createIndexesQueries = [
    // Students
    'CREATE INDEX idx_students_class ON ${DbConstants.tableStudents} (${DbConstants.colStudentClassId});',
    'CREATE INDEX idx_students_class_roll ON ${DbConstants.tableStudents} (${DbConstants.colStudentClassId}, ${DbConstants.colNormalizedRollNumber});',
    'CREATE INDEX idx_students_name ON ${DbConstants.tableStudents} (${DbConstants.colStudentName});',

    // Subjects
    'CREATE INDEX idx_subjects_class ON ${DbConstants.tableSubjects} (${DbConstants.colSubjectClassId});',

    // Attendance Sessions
    'CREATE INDEX idx_sessions_class_date ON ${DbConstants.tableAttendanceSessions} (${DbConstants.colSessionClassId}, ${DbConstants.colSessionDate});',
    'CREATE INDEX idx_sessions_subject_date ON ${DbConstants.tableAttendanceSessions} (${DbConstants.colSessionSubjectId}, ${DbConstants.colSessionDate});',

    // Attendance Records
    'CREATE INDEX idx_records_session ON ${DbConstants.tableAttendanceRecords} (${DbConstants.colRecordSessionId});',
    'CREATE INDEX idx_records_student ON ${DbConstants.tableAttendanceRecords} (${DbConstants.colRecordStudentId});',

    // Audit Events
    'CREATE INDEX idx_audit_entity ON ${DbConstants.tableAuditEvents} (${DbConstants.colEntityType}, ${DbConstants.colEntityId});',
    'CREATE INDEX idx_audit_created ON ${DbConstants.tableAuditEvents} (${DbConstants.colCreatedAt});',

    // Backup Metadata
    'CREATE INDEX idx_backup_owner_time ON ${DbConstants.tableBackupMetadata} (${DbConstants.colBackupOwnerId}, ${DbConstants.colCreatedAt});',
  ];

  /// Creates all tables and indexes on a newly opened database.
  static Future<void> createSchema(Database db) async {
    for (final query in createTablesQueries) {
      await db.execute(query);
    }
    for (final query in createIndexesQueries) {
      await db.execute(query);
    }
  }
}
