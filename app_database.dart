import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'migrations.dart';

/// Single shared database connection for the whole app.
///
/// Everything that touches storage goes through here so we have one place
/// to enforce foreign keys, wrap multi-table writes in transactions, and
/// keep the WAL journal mode for concurrent read performance.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'exam_prep.db');

    return openDatabase(
      path,
      version: Migrations.latestVersion,
      onConfigure: (db) async {
        // Foreign keys are OFF by default in sqlite; without this, cascade
        // deletes (e.g. deleting a subject) silently leave orphan topics.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) => Migrations.runAll(db, version),
      onUpgrade: (db, oldV, newV) => Migrations.upgrade(db, oldV, newV),
    );
  }

  /// Runs [action] inside a single transaction. Use this for any write that
  /// touches more than one table (e.g. completing a revision updates
  /// revision_schedules + revision_history + daily_tasks together) so a
  /// crash mid-write can't leave the database half-updated.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
