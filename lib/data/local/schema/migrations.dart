import 'package:sqflite/sqflite.dart';

/// Single migration step definition between two sequential database versions.
class Migration {
  final int fromVersion;
  final int toVersion;
  final Future<void> Function(Database db) migrate;

  const Migration({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  });
}

/// Migration manager providing non-destructive schema evolution.
class MigrationManager {
  MigrationManager._();

  /// Registry of schema migrations.
  /// When adding future schema revisions (e.g. v2, v3):
  /// 1. Increment [DbConstants.currentSchemaVersion].
  /// 2. Append a new [Migration] instance here.
  /// 3. Never alter past migrations or execute destructive drops on user data.
  static final List<Migration> _migrations = [
    // Future migrations will be registered here sequentially, e.g.:
    // Migration(
    //   fromVersion: 1,
    //   toVersion: 2,
    //   migrate: (db) async {
    //     await db.execute('ALTER TABLE ... ADD COLUMN ...');
    //   },
    // ),
  ];

  /// Executes registered migrations sequentially from [oldVersion] up to [newVersion].
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (int v = oldVersion; v < newVersion; v++) {
      final migration = _migrations.firstWhere(
        (m) => m.fromVersion == v && m.toVersion == v + 1,
        orElse: () => throw StateError(
          'Missing migration path from database version $v to ${v + 1}',
        ),
      );
      await migration.migrate(db);
    }
  }

  /// Handles database downgrade attempts safely (prevent accidental data corruption).
  static Future<void> onDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'Database downgrade from version $oldVersion to $newVersion is not supported '
      'to prevent data loss and corruption.',
    );
  }
}
