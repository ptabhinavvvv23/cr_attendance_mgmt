import '../local/app_database.dart';
import '../local/dao/daos.dart';
import 'owner_repository.dart';
import 'class_repository.dart';
import 'subject_repository.dart';
import 'student_repository.dart';
import 'attendance_repository.dart';
import 'audit_repository.dart';
import 'backup_metadata_repository.dart';

/// Central dependency container holding instantiated repositories and database services.
/// Provides a unified, decoupled access point for presentation and business logic layers
/// without coupling UI widgets to SQLite or raw database queries.
class RepositoryContainer {
  final AppDatabase database;

  // Repositories
  final OwnerRepository ownerRepository;
  final ClassRepository classRepository;
  final SubjectRepository subjectRepository;
  final StudentRepository studentRepository;
  final AttendanceRepository attendanceRepository;
  final AuditRepository auditRepository;
  final BackupMetadataRepository backupMetadataRepository;

  RepositoryContainer._({
    required this.database,
    required this.ownerRepository,
    required this.classRepository,
    required this.subjectRepository,
    required this.studentRepository,
    required this.attendanceRepository,
    required this.auditRepository,
    required this.backupMetadataRepository,
  });

  /// Factory constructor assembling the default repositories connected to [AppDatabase.instance].
  factory RepositoryContainer.create({AppDatabase? db}) {
    final appDb = db ?? AppDatabase.instance;

    final ownerDao = OwnerDao(appDb);
    final classDao = ClassDao(appDb);
    final subjectDao = SubjectDao(appDb);
    final studentDao = StudentDao(appDb);
    final sessionDao = AttendanceSessionDao(appDb);
    final recordDao = AttendanceRecordDao(appDb);
    final auditDao = AuditEventDao(appDb);
    final backupDao = BackupMetadataDao(appDb);

    return RepositoryContainer._(
      database: appDb,
      ownerRepository: OwnerRepositoryImpl(ownerDao: ownerDao),
      classRepository: ClassRepositoryImpl(
        classDao: classDao,
        ownerDao: ownerDao,
      ),
      subjectRepository: SubjectRepositoryImpl(
        subjectDao: subjectDao,
        classDao: classDao,
      ),
      studentRepository: StudentRepositoryImpl(
        studentDao: studentDao,
        classDao: classDao,
      ),
      attendanceRepository: AttendanceRepositoryImpl(
        db: appDb,
        sessionDao: sessionDao,
        recordDao: recordDao,
        studentDao: studentDao,
        classDao: classDao,
        subjectDao: subjectDao,
        auditDao: auditDao,
      ),
      auditRepository: AuditRepositoryImpl(auditDao: auditDao),
      backupMetadataRepository: BackupMetadataRepositoryImpl(
        backupDao: backupDao,
      ),
    );
  }

  /// Closes database connection cleanly.
  Future<void> dispose() async {
    await database.close();
  }
}
