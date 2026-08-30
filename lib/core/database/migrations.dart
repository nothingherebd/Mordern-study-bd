import 'package:sqflite/sqflite.dart';

/// All schema migrations live here, in order. Each migration is idempotent
/// and only ever moves the schema forward. Never edit an already-shipped
/// migration — add a new one instead, so upgrading users don't lose data.
class Migrations {
  static const int latestVersion = 1;

  static Future<void> runAll(Database db, int version) async {
    if (version >= 1) await _v1(db);
  }

  static Future<void> upgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1 && newVersion >= 1) await _v1(db);
    // Future migrations: if (oldVersion < 2 && newVersion >= 2) await _v2(db);
  }

  static Future<void> _v1(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE IF NOT EXISTS subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        color INTEGER NOT NULL DEFAULT 4280391411,
        icon TEXT,
        created_at INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS topics (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        priority INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'not_started',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        estimated_minutes INTEGER NOT NULL DEFAULT 30,
        target_date INTEGER,
        archived INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS revision_schedules (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        interval_type TEXT NOT NULL DEFAULT 'custom',
        -- interval_stages: JSON array of ints (days) e.g. [1,3,7,14,30]
        interval_stages TEXT NOT NULL DEFAULT '[1,3,7,14,30]',
        current_stage INTEGER NOT NULL DEFAULT 0,
        next_revision_at INTEGER,
        last_revision_at INTEGER,
        revision_count INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS revision_history (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        schedule_id TEXT,
        scheduled_at INTEGER,
        completed_at INTEGER,
        result TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS daily_tasks (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        date TEXT NOT NULL, -- yyyy-MM-dd, local calendar day this task belongs to
        task_type TEXT NOT NULL DEFAULT 'revision', -- study | revision
        priority INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'pending', -- pending | completed | skipped
        estimated_minutes INTEGER NOT NULL DEFAULT 30,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        source_schedule_id TEXT,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS focus_sessions (
        id TEXT PRIMARY KEY,
        topic_id TEXT,
        task_id TEXT,
        label TEXT,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        planned_seconds INTEGER NOT NULL,
        elapsed_seconds INTEGER NOT NULL DEFAULT 0,
        mode TEXT NOT NULL DEFAULT 'countdown', -- countdown | countup
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Indexes for the queries the app actually runs.
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_topics_subject ON topics(subject_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_schedules_topic ON revision_schedules(topic_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_schedules_next ON revision_schedules(next_revision_at)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_topic ON revision_history(topic_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_date ON daily_tasks(date)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_topic ON daily_tasks(topic_id)');

    await batch.commit(noResult: true);
  }
}
