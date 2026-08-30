import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/notifications/notification_service.dart';
import 'core/services/daily_plan_service.dart';
import 'core/services/revision_engine.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/revision_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/subject_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/topic_repository.dart';
import 'features/home/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/// Wires repositories once, provides them down the tree, then hands off to
/// [ExamPrepApp]. Splitting bootstrap from the app widget keeps main.dart
/// readable and makes it trivial to swap implementations in tests.
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final subjectRepo = SubjectRepository();
    final topicRepo = TopicRepository();
    final revisionRepo = RevisionRepository();
    final taskRepo = TaskRepository();
    final settingsRepo = SettingsRepository();
    final revisionEngine = RevisionEngine(revisionRepo);
    final planService = DailyPlanService(
      taskRepo: taskRepo,
      topicRepo: topicRepo,
      revisionRepo: revisionRepo,
      settingsRepo: settingsRepo,
    );

    return MultiProvider(
      providers: [
        Provider<SubjectRepository>.value(value: subjectRepo),
        Provider<TopicRepository>.value(value: topicRepo),
        Provider<RevisionRepository>.value(value: revisionRepo),
        Provider<TaskRepository>.value(value: taskRepo),
        Provider<SettingsRepository>.value(value: settingsRepo),
        Provider<RevisionEngine>.value(value: revisionEngine),
        Provider<DailyPlanService>.value(value: planService),
      ],
      child: const ExamPrepApp(),
    );
  }
}

class ExamPrepApp extends StatefulWidget {
  const ExamPrepApp({super.key});

  @override
  State<ExamPrepApp> createState() => _ExamPrepAppState();
}

class _ExamPrepAppState extends State<ExamPrepApp> with WidgetsBindingObserver {
  Color _accent = const Color(0xFF3B82F6);
  ThemeMode _themeMode = ThemeMode.system;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final settingsRepo = context.read<SettingsRepository>();
    final planService = context.read<DailyPlanService>();

    await NotificationService.instance.init();
    await NotificationService.instance.requestPermission();

    final accentValue = await settingsRepo.get(SettingsRepository.keyAccentColor);
    final themeValue = await settingsRepo.get(SettingsRepository.keyThemeMode);

    // Daily rollover: generate today's tasks / surface overdue work.
    // Safe to call every launch — it's a no-op if already run today.
    await planService.processDailyRollover();

    if (!mounted) return;
    setState(() {
      _accent = Color(int.tryParse(accentValue) ?? 0xFF3B82F6);
      _themeMode = switch (themeValue) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-run rollover whenever the app comes back to the foreground — this
    // is what catches "phone was asleep across midnight" without needing a
    // background task or exact-alarm permissions.
    if (state == AppLifecycleState.resumed && _ready) {
      context.read<DailyPlanService>().processDailyRollover();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void updateAccent(Color color) => setState(() => _accent = color);
  void updateThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Exam Prep',
      themeMode: _themeMode,
      theme: AppTheme.light(_accent),
      darkTheme: AppTheme.light(_accent), // main app keeps one clean palette;
      // Countdown screen opts into AppTheme.dark()/black explicitly.
      home: HomeShell(
        onAccentChanged: updateAccent,
        onThemeModeChanged: updateThemeMode,
      ),
    );
  }
}
