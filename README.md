# Exam Prep — local-first revision app

A Flutter app for subjects → topics → spaced revision → daily plan → focus timer → progress,
built around the architecture we discussed: SQLite as the single source of truth, a
repository layer between UI and database, and a revision engine that's decoupled from
the daily-plan generator.

## Getting it running

This is source code only — no platform folders (`android/`, `ios/`), since those are
generated binaries/config that don't belong hand-written. To run it:

```bash
# 1. Unzip this into a folder, then from inside it:
flutter create . --project-name exam_prep --org com.yourname

# This generates android/, ios/, and other platform folders around the
# existing lib/ and pubspec.yaml without touching them.

# 2. Install dependencies
flutter pub get

# 3. Run
flutter run
```

Requires Flutter 3.19+ (Dart 3.3+). If `flutter create .` complains about an
existing `lib/`, that's expected and fine — it only scaffolds the missing
platform folders.

### Android notification icon
`flutter_local_notifications` expects a small icon at
`android/app/src/main/res/drawable/ic_launcher` or similar — after
`flutter create .` runs, the default `@mipmap/ic_launcher` referenced in
`notification_service.dart` will already exist from the template, so
notifications work out of the box. Swap in your own icon later if you want.

## What's implemented

- **Database** (`lib/core/database/`): SQLite via sqflite, foreign keys on,
  versioned migrations (`migrations.dart`) so upgrades never touch shipped
  migrations — new schema changes get a new migration function.
- **Models + repositories** (`lib/data/`): one repository per table family.
  Every multi-table write (completing a revision, deleting a subject/topic)
  runs inside `AppDatabase.transaction()` so a crash mid-write can't leave
  orphaned rows.
- **Revision engine** (`lib/core/services/revision_engine.dart`): configurable
  interval stages (e.g. `[1,3,7,14,30]` days) instead of a hardcoded curve.
  Supports `custom` (always advance one stage) and `adaptive` (easy/good/
  difficult/forgotten change how far the schedule jumps) modes.
- **Daily plan service** (`lib/core/services/daily_plan_service.dart`): the
  "don't nuke yesterday's list at midnight" logic. On every app start/resume
  it compares a stored `last_processed_date` against today; if they differ,
  it generates today's tasks once and leaves old pending tasks as their own
  overdue rows rather than duplicating or deleting anything. Also enforces a
  daily time/task budget by pushing lowest-priority tasks to tomorrow.
- **Study screen** (`lib/features/study/`): the topic editor matches the
  workflow — title, description, estimated time, priority, first-study
  date/time, configurable revision intervals with a live date preview,
  "add to daily plan" toggle.
- **Plan screen**: today's tasks grouped by priority, a separate overdue
  section, a progress bar, swipe-to-snooze, and a "how did that revision go"
  prompt that feeds the adaptive engine when enabled.
- **Countdown screen**: intentionally different visual identity (black
  background), presets, ±1/±5 min adjustment, pause/resume, overtime mode,
  count-up mode. Elapsed time is always computed from stored timestamps
  (`DateTime.now().difference(startedAt)`), never from decrementing a
  counter each tick — so backgrounding, phone calls, or the OS freezing the
  timer never desyncs the display.
- **Settings**: sectioned (Study / Plan / Notifications / Appearance / Data),
  backed by a `settings` table so preferences travel with backups.
- **Notifications**: wrapped so permission-denied or OEM alarm restrictions
  fail silently instead of crashing.

## What's scaffolded but not fully built out

Given the scope of the original spec, these are structured but intentionally
left thinner so you can extend them in the direction that matters most to you:

- **Export/import & backup**: `settings` repository and DB structure support
  it, but the actual file-picker/share-sheet wiring isn't implemented.
- **Adaptive/SRS auto-tuning**: the four-outcome adaptive mode exists in
  `revision_repository.dart::completeRevision`, but there's no UI yet to
  switch a schedule from `custom` to `adaptive`.
- **Focus session ↔ topic linking**: the `focus_sessions` table exists in the
  schema; the Countdown screen doesn't yet let you attach a session to a
  specific topic before starting.
- **Streaks and topic mastery %**: `revision_history` has everything needed
  to compute these; the Progress screen currently shows aggregate counts
  only.

## Architecture

```
Settings ─┐
          ▼
Subjects ──▶ Topics ──▶ Revision Engine ──┬──▶ Plan
                                           ├──▶ Countdown
                                           └──▶ Progress
                    all backed by SQLite (single source of truth)
```

Study creates/edits topics. The revision engine decides when a topic should
come back. Plan renders "what's due today." Countdown measures focused work.
Progress reads history. Nothing but the repositories talks to SQLite directly.
