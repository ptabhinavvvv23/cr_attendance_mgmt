import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../core/errors/database_exception.dart';
import 'db_constants.dart';
import 'schema/app_schema.dart';
import 'schema/migrations.dart';

/// Centralized manager for SQLite database lifecycle, connection pooling,
/// foreign key configuration, and atomic transaction execution.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;
  Completer<Database>? _dbOpenCompleter;
  String? _customPath;

  AppDatabase._internal();

  /// Factory constructor returning the singleton instance.
  factory AppDatabase() => instance;

  /// Visible for testing or custom path configuration (e.g., in-memory or custom directory).
  void setCustomPath(String? path) {
    if (_db != null && _db!.isOpen) {
      throw StateError(
        'Cannot set custom database path while database is open.',
      );
    }
    _customPath = path;
  }

  /// Returns the open [Database] instance, initializing it if not already opened.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    if (_dbOpenCompleter != null) {
      return _dbOpenCompleter!.future;
    }

    _dbOpenCompleter = Completer<Database>();

    try {
      final dbPath =
          _customPath ??
          p.join(await getDatabasesPath(), DbConstants.databaseName);

      final db = await openDatabase(
        dbPath,
        version: DbConstants.currentSchemaVersion,
        onConfigure: (db) async {
          // Mandatory: Enforce foreign key constraints in SQLite
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await AppSchema.createSchema(db);
        },
        onUpgrade: MigrationManager.onUpgrade,
        onDowngrade: MigrationManager.onDowngrade,
      );

      _db = db;
      _dbOpenCompleter!.complete(db);
      return db;
    } catch (e, stackTrace) {
      _dbOpenCompleter!.completeError(
        AppDatabaseException(
          'Failed to initialize local SQLite database: $e',
          e,
          stackTrace,
        ),
      );
      _dbOpenCompleter = null;
      rethrow;
    } finally {
      if (_dbOpenCompleter?.isCompleted ?? false) {
        _dbOpenCompleter = null;
      }
    }
  }

  /// Runs an atomic transaction across multiple database operations.
  /// Automatically rolls back if an exception occurs.
  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    try {
      return await db.transaction<T>((txn) async {
        return await action(txn);
      });
    } catch (e, stackTrace) {
      if (e is AppDatabaseException) {
        rethrow;
      }
      throw TransactionException(
        'Atomic transaction failed: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Closes the database connection cleanly.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
