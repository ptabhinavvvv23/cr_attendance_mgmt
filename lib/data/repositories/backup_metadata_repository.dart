import '../../core/errors/database_exception.dart';
import '../../core/theme/app_colors.dart';
import '../local/dao/backup_metadata_dao.dart';
import '../models/backup_metadata_model.dart';

/// Repository contract for Backup Metadata records.
abstract class BackupMetadataRepository {
  Future<BackupMetadataModel> recordBackupMetadata(BackupMetadataModel backup);
  Future<BackupMetadataModel?> getLatestBackup(String ownerId);
  Future<List<BackupMetadataModel>> getBackupHistory(String ownerId);
  Future<void> updateBackupStatus({
    required String backupId,
    required BackupStatusState status,
    String? storageReference,
    String? checksum,
    int? fileSizeBytes,
    String? errorMessage,
  });
}

/// Concrete SQLite implementation of [BackupMetadataRepository].
class BackupMetadataRepositoryImpl implements BackupMetadataRepository {
  final BackupMetadataDao _backupDao;

  BackupMetadataRepositoryImpl({BackupMetadataDao? backupDao})
    : _backupDao = backupDao ?? BackupMetadataDao();

  @override
  Future<BackupMetadataModel> recordBackupMetadata(
    BackupMetadataModel backup,
  ) async {
    try {
      await _backupDao.insert(backup);
      return backup;
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to record backup metadata: $e', e, st);
    }
  }

  @override
  Future<BackupMetadataModel?> getLatestBackup(String ownerId) async {
    try {
      return await _backupDao.getLatestForOwner(ownerId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve latest backup for $ownerId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<List<BackupMetadataModel>> getBackupHistory(String ownerId) async {
    try {
      return await _backupDao.getAllForOwner(ownerId);
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to retrieve backup history for $ownerId: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<void> updateBackupStatus({
    required String backupId,
    required BackupStatusState status,
    String? storageReference,
    String? checksum,
    int? fileSizeBytes,
    String? errorMessage,
  }) async {
    final existing = await _backupDao.getById(backupId);
    if (existing == null) {
      throw RecordNotFoundException('BackupMetadata', backupId);
    }

    final updated = existing.copyWith(
      status: status,
      storageReference: storageReference ?? existing.storageReference,
      checksum: checksum ?? existing.checksum,
      fileSizeBytes: fileSizeBytes ?? existing.fileSizeBytes,
      errorMessage: errorMessage ?? existing.errorMessage,
      updatedAt: DateTime.now(),
    );

    try {
      final rows = await _backupDao.update(updated);
      if (rows == 0) {
        throw RecordNotFoundException('BackupMetadata', backupId);
      }
    } catch (e, st) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to update backup status for $backupId: $e',
        e,
        st,
      );
    }
  }
}
