import '../../core/theme/app_colors.dart';

/// Persistent metadata representing a backup snapshot record for future cloud/local sync.
class BackupMetadataModel {
  final String id;
  final String ownerId;
  final String classId;
  final int formatVersion;
  final int schemaVersion;
  final BackupStatusState status;
  final String? storageReference;
  final String? checksum;
  final int? fileSizeBytes;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupMetadataModel({
    required this.id,
    required this.ownerId,
    required this.classId,
    this.formatVersion = 1,
    required this.schemaVersion,
    this.status = BackupStatusState.neverBackedUp,
    this.storageReference,
    this.checksum,
    this.fileSizeBytes,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  static String statusToDbString(BackupStatusState state) {
    switch (state) {
      case BackupStatusState.neverBackedUp:
        return 'NEVER_BACKED_UP';
      case BackupStatusState.pending:
        return 'PENDING';
      case BackupStatusState.successful:
        return 'SUCCESSFUL';
      case BackupStatusState.failed:
        return 'FAILED';
    }
  }

  static BackupStatusState parseDbStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'PENDING':
        return BackupStatusState.pending;
      case 'SUCCESSFUL':
        return BackupStatusState.successful;
      case 'FAILED':
        return BackupStatusState.failed;
      case 'NEVER_BACKED_UP':
      default:
        return BackupStatusState.neverBackedUp;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'class_id': classId,
      'format_version': formatVersion,
      'schema_version': schemaVersion,
      'status': statusToDbString(status),
      'storage_reference': storageReference?.trim(),
      'checksum': checksum?.trim(),
      'file_size_bytes': fileSizeBytes,
      'error_message': errorMessage?.trim(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BackupMetadataModel.fromMap(Map<String, dynamic> map) {
    return BackupMetadataModel(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      classId: map['class_id'] as String,
      formatVersion: map['format_version'] as int? ?? 1,
      schemaVersion: map['schema_version'] as int,
      status: parseDbStatus(map['status'] as String? ?? 'NEVER_BACKED_UP'),
      storageReference: map['storage_reference'] as String?,
      checksum: map['checksum'] as String?,
      fileSizeBytes: map['file_size_bytes'] as int?,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  BackupMetadataModel copyWith({
    String? id,
    String? ownerId,
    String? classId,
    int? formatVersion,
    int? schemaVersion,
    BackupStatusState? status,
    String? storageReference,
    String? checksum,
    int? fileSizeBytes,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BackupMetadataModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      classId: classId ?? this.classId,
      formatVersion: formatVersion ?? this.formatVersion,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      status: status ?? this.status,
      storageReference: storageReference ?? this.storageReference,
      checksum: checksum ?? this.checksum,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupMetadataModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
