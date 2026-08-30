import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const SettingsScreen({
    super.key,
    required this.onAccentChanged,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, String>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SettingsRepository>().getAll();
  }

  void _reload() => setState(() {
        _future = context.read<SettingsRepository>().getAll();
      });

  Future<void> _set(String key, String value) async {
    await context.read<SettingsRepository>().set(key, value);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<Map<String, String>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!;
          return ListView(
            children: [
              _sectionLabel('Study'),
              ListTile(
                title: const Text('Default study duration'),
                subtitle: Text('${s[SettingsRepository.keyDefaultStudyMinutes]} minutes'),
                onTap: () => _editNumber(
                  context,
                  title: 'Default study duration (minutes)',
                  key: SettingsRepository.keyDefaultStudyMinutes,
                  current: s[SettingsRepository.keyDefaultStudyMinutes]!,
                ),
              ),
              SwitchListTile(
                title: const Text('Automatic task generation'),
                subtitle: const Text('Create daily tasks from due revisions automatically'),
                value: s[SettingsRepository.keyAutoGenerateTasks] == 'true',
                onChanged: (v) => _set(SettingsRepository.keyAutoGenerateTasks, v.toString()),
              ),
              const Divider(),

              _sectionLabel('Plan'),
              ListTile(
                title: const Text('Maximum daily study time'),
                subtitle: Text('${s[SettingsRepository.keyMaxDailyMinutes]} minutes'),
                onTap: () => _editNumber(
                  context,
                  title: 'Maximum daily minutes',
                  key: SettingsRepository.keyMaxDailyMinutes,
                  current: s[SettingsRepository.keyMaxDailyMinutes]!,
                ),
              ),
              ListTile(
                title: const Text('Maximum number of tasks per day'),
                subtitle: Text(s[SettingsRepository.keyMaxDailyTasks]!),
                onTap: () => _editNumber(
                  context,
                  title: 'Max tasks per day',
                  key: SettingsRepository.keyMaxDailyTasks,
                  current: s[SettingsRepository.keyMaxDailyTasks]!,
                ),
              ),
              const Divider(),

              _sectionLabel('Notifications'),
              SwitchListTile(
                title: const Text('Revision reminders'),
                value: s[SettingsRepository.keyRevisionRemindersOn] == 'true',
                onChanged: (v) => _set(SettingsRepository.keyRevisionRemindersOn, v.toString()),
              ),
              SwitchListTile(
                title: const Text('Daily plan reminder'),
                value: s[SettingsRepository.keyDailyPlanReminderOn] == 'true',
                onChanged: (v) => _set(SettingsRepository.keyDailyPlanReminderOn, v.toString()),
              ),
              ListTile(
                title: const Text('Notification permission'),
                subtitle: Text(NotificationService.instance.permissionGranted ? 'Granted' : 'Not granted'),
                trailing: TextButton(
                  onPressed: () async {
                    await NotificationService.instance.requestPermission();
                    _reload();
                  },
                  child: const Text('Request'),
                ),
              ),
              const Divider(),

              _sectionLabel('Appearance'),
              ListTile(
                title: const Text('Theme'),
                subtitle: Text(s[SettingsRepository.keyThemeMode]!),
                trailing: DropdownButton<String>(
                  value: s[SettingsRepository.keyThemeMode],
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('System')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _set(SettingsRepository.keyThemeMode, v);
                    widget.onThemeModeChanged(switch (v) {
                      'light' => ThemeMode.light,
                      'dark' => ThemeMode.dark,
                      _ => ThemeMode.system,
                    });
                  },
                ),
              ),
              const Divider(),

              _sectionLabel('Data'),
              ListTile(
                title: const Text('Reset settings to defaults'),
                leading: const Icon(Icons.restore),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset settings?'),
                      content: const Text('This resets preferences only — your subjects, topics, and history are untouched.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await context.read<SettingsRepository>().resetAll();
                    _reload();
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      );

  Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required String key,
    required String current,
  }) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && int.tryParse(result) != null) {
      await _set(key, result);
    }
  }
}
