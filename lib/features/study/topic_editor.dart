import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/revision_engine.dart';
import '../../data/models/daily_task.dart';
import '../../data/models/revision_schedule.dart';
import '../../data/models/subject.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/topic_repository.dart';

class TopicEditor extends StatefulWidget {
  final Subject subject;
  final Topic? existing;
  const TopicEditor({super.key, required this.subject, this.existing});

  @override
  State<TopicEditor> createState() => _TopicEditorState();
}

class _TopicEditorState extends State<TopicEditor> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController(text: '30');
  final _stagesCtrl = TextEditingController(text: '1,3,7,14,30');

  TopicPriority _priority = TopicPriority.medium;
  DateTime _firstStudyDate = DateTime.now();
  TimeOfDay _firstStudyTime = TimeOfDay.now();
  bool _addToPlan = true;
  bool _saving = false;

  RevisionSchedule? _existingSchedule;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description ?? '';
      _minutesCtrl.text = t.estimatedMinutes.toString();
      _priority = t.priority;
      _loadSchedule(t.id);
    }
  }

  Future<void> _loadSchedule(String topicId) async {
    final schedules = await context.read<RevisionRepository>().getByTopic(topicId);
    if (schedules.isNotEmpty && mounted) {
      setState(() {
        _existingSchedule = schedules.first;
        _stagesCtrl.text = schedules.first.intervalStages.join(',');
        if (schedules.first.nextRevisionAt != null) {
          _firstStudyDate = schedules.first.nextRevisionAt!;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _minutesCtrl.dispose();
    _stagesCtrl.dispose();
    super.dispose();
  }

  List<int> get _parsedStages {
    final parts = _stagesCtrl.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((v) => v > 0)
        .toList();
    return parts.isEmpty ? [1, 3, 7, 14, 30] : parts;
  }

  List<DateTime> get _previewDates {
    final start = DateTime(_firstStudyDate.year, _firstStudyDate.month, _firstStudyDate.day);
    final dates = <DateTime>[start];
    var cursor = start;
    final stages = _parsedStages;
    for (var i = 0; i < stages.length && i < 4; i++) {
      cursor = cursor.add(Duration(days: stages[i]));
      dates.add(cursor);
    }
    return dates;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstStudyDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _firstStudyDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _firstStudyTime);
    if (picked != null) setState(() => _firstStudyTime = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Topic title can\'t be empty')),
      );
      return;
    }
    final minutes = int.tryParse(_minutesCtrl.text.trim());
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimated time must be a positive number')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final topicRepo = context.read<TopicRepository>();
      final revisionEngine = context.read<RevisionEngine>();
      final revisionRepo = context.read<RevisionRepository>();
      final taskRepo = context.read<TaskRepository>();

      final firstStudyDateTime = DateTime(
        _firstStudyDate.year, _firstStudyDate.month, _firstStudyDate.day,
        _firstStudyTime.hour, _firstStudyTime.minute,
      );

      Topic topic;
      if (_isEditing) {
        topic = widget.existing!.copyWith(
          title: title,
          description: _descCtrl.text.trim(),
          priority: _priority,
          estimatedMinutes: minutes,
          updatedAt: DateTime.now(),
        );
        await topicRepo.update(topic);
      } else {
        topic = Topic(
          id: topicRepo.newId(),
          subjectId: widget.subject.id,
          title: title,
          description: _descCtrl.text.trim(),
          priority: _priority,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          estimatedMinutes: minutes,
        );
        await topicRepo.create(topic);
      }

      // Revision schedule: create new, or update stages on existing.
      if (_existingSchedule != null) {
        await revisionRepo.update(_existingSchedule!.copyWith(
          intervalStages: _parsedStages,
        ));
      } else {
        await revisionEngine.createSchedule(
          topicId: topic.id,
          firstRevisionDate: firstStudyDateTime,
          intervalStages: _parsedStages,
        );
      }

      if (_addToPlan) {
        final dateKey = dayKeyFormat.format(firstStudyDateTime);
        final exists = await taskRepo.existsForTopicAndDate(
          topicId: topic.id, date: dateKey, taskType: 'study',
        );
        if (!exists) {
          await taskRepo.create(DailyTask(
            id: taskRepo.newId(),
            topicId: topic.id,
            date: dateKey,
            taskType: TaskType.study,
            priority: _priority.value,
            estimatedMinutes: minutes,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final topic = widget.existing!;
    final history = await context.read<RevisionRepository>().getHistoryForTopic(topic.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete topic?'),
        content: Text(
          history.isEmpty
              ? 'This removes "${topic.title}" permanently.'
              : 'This removes "${topic.title}" and its ${history.length} '
                'revision history ${history.length == 1 ? 'entry' : 'entries'} permanently.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<TopicRepository>().deleteCascade(topic.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final previewFmt = DateFormat('d MMM');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit topic' : 'New topic'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text('Subject', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Chip(
            avatar: CircleAvatar(backgroundColor: Color(widget.subject.color), radius: 6),
            label: Text(widget.subject.name),
          ),
          const SizedBox(height: 20),

          Text('Topic', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'e.g. Constitutional Amendments')),
          const SizedBox(height: 16),

          Text('Description', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Notes about what to learn...'),
          ),
          const SizedBox(height: 16),

          Text('Estimated study time (minutes)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _minutesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '45'),
          ),
          const SizedBox(height: 16),

          Text('Priority', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: TopicPriority.values.map((p) {
              return ChoiceChip(
                label: Text(p.label),
                selected: _priority == p,
                onSelected: (_) => setState(() => _priority = p),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Text('First study', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(dateFmt.format(_firstStudyDate)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickTime,
                  child: Text(_firstStudyTime.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Revision intervals (days, comma separated)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _stagesCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '1, 3, 7, 14, 30'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _previewDates.length; i++) ...[
                Chip(label: Text(previewFmt.format(_previewDates[i]))),
                if (i != _previewDates.length - 1) const Icon(Icons.arrow_forward, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add to daily plan'),
            value: _addToPlan,
            onChanged: (v) => setState(() => _addToPlan = v),
          ),
          const SizedBox(height: 12),

          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save topic'),
          ),
        ],
      ),
    );
  }
}
