/// Base class for all database and persistence-related domain exceptions in the application.
class AppDatabaseException implements Exception {
  final String message;
  final dynamic cause;
  final StackTrace? stackTrace;

  const AppDatabaseException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() {
    if (cause != null) {
      return 'AppDatabaseException: $message (Caused by: $cause)';
    }
    return 'AppDatabaseException: $message';
  }
}

/// Backward-compatible alias for [AppDatabaseException].
typedef DatabaseException = AppDatabaseException;

/// Thrown when an expected entity record cannot be located in the local database.
class RecordNotFoundException extends AppDatabaseException {
  final String entityType;
  final String entityId;

  RecordNotFoundException(this.entityType, this.entityId)
    : super('$entityType with ID "$entityId" was not found.');
}

/// Thrown when an entity violates uniqueness constraints (e.g. duplicate roll number or session).
class DuplicateEntityException extends AppDatabaseException {
  final String entityType;
  final String field;
  final String value;

  DuplicateEntityException(this.entityType, this.field, this.value)
    : super('$entityType with $field "$value" already exists in this scope.');
}

/// Specialized exception for duplicate student roll numbers within a class.
class DuplicateRollNumberException extends DuplicateEntityException {
  final String classId;

  DuplicateRollNumberException({
    required String rollNumber,
    required this.classId,
  }) : super('Student', 'rollNumber', rollNumber);
}

/// Specialized exception when an attendance session with same subject, date, and period already exists.
class DuplicateSessionException extends DuplicateEntityException {
  DuplicateSessionException({
    required String subjectId,
    required String sessionDate,
    required String period,
  }) : super(
         'AttendanceSession',
         'subject/date/period',
         '$subjectId on $sessionDate (Period $period)',
       );
}

/// Thrown when an attendance record attempts to link a student to a session from a different class.
class CrossClassRelationshipException extends AppDatabaseException {
  final String studentId;
  final String studentClassId;
  final String sessionId;
  final String sessionClassId;

  CrossClassRelationshipException({
    required this.studentId,
    required this.studentClassId,
    required this.sessionId,
    required this.sessionClassId,
  }) : super(
         'Cross-class relationship rejected: Student $studentId belongs to class $studentClassId, '
         'but Session $sessionId belongs to class $sessionClassId.',
       );
}

/// Thrown when data validation fails before or during persistence.
class ValidationException extends AppDatabaseException {
  final Map<String, String> fieldErrors;

  ValidationException(super.message, {this.fieldErrors = const {}});
}

/// Thrown when an atomic transaction fails and is rolled back.
class TransactionException extends AppDatabaseException {
  TransactionException(
    String operation,
    dynamic error, [
    StackTrace? stackTrace,
  ]) : super('Transaction failed during $operation: $error', error, stackTrace);
}
