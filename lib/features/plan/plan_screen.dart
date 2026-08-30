import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/daily_plan_service.dart';
import '../../core/services/revision_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/daily_task.dart';
import '../../data/models/revision_history.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/topic_repository.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late Future<_PlanData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _loadPlan();
  }

  Future<_PlanData> _loadPlan() async {
    final planService = context.read<DailyPlanService>();
    final topicRepo = context.read<TopicRepository>();

    final today = await planService.getToday();
    final overdue = await planService.getOverdue();

    final topicIds = {...today.map((t) => t.topicId), ...overdue.map((t) => t.topicId)};
    final topics = <String, Topic>{};
    for (final id in topicIds) {
      final t = await topicRepo.getById(id);
      if (t != null) topics[id] = t;
    }
    return _PlanData(today: today, overdue: overdue, topics: topics);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _completeTask(DailyTask task, Topic? topic) async {
    final taskRepo = context.read<TaskRepository>();
    if (task.taskType == TaskType.revision) {
      final schedules = await context.read<RevisionRepository>().getByTopic(task.topicId);
      if (schedules.isNotEmpty) {
        final result = await _askResult();
        if (result == null) return; // cancelled
        await context.read<RevisionEngine>().completeRevision(
              schedule: schedules.first,
              topicId: task.topicId,
              taskId: task.id,
              result: result,
            );
      } else {
        await taskRepo.updateStatus(task.id, TaskStatus.completed);
      }
    } else {
      await taskRepo.updateStatus(task.id, TaskStatus.completed);
    }
    await _refresh();
  }

  Future<RevisionResult?> _askResult() async {
    return showModalBottomSheet<RevisionResult>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How did that revision go?', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final r in RevisionResult.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_resultLabel(r)),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _resultLabel(RevisionResult r) => switch (r) {
        RevisionResult.easy => 'Easy — push the next revision further out',
        RevisionResult.good => 'Good — keep the normal pace',
        RevisionResult.difficult => 'Difficult — revise again at the same interval',
        RevisionResult.forgotten => 'Forgotten — start the schedule over',
      };

  Future<void> _snooze(DailyTask task) async {
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Later today'), onTap: () => Navigator.pop(ctx, Duration.zero)),
            ListTile(title: const Text('Tomorrow'), onTap: () => Navigator.pop(ctx, const Duration(days: 1))),
            ListTile(title: const Text('+3 days'), onTap: () => Navigator.pop(ctx, const Duration(days: 3))),
          ],
        ),
      ),
    );
    if (choice != null) {
      await context.read<DailyPlanService>().snooze(task.id, choice);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s plan')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_PlanData>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final data = snap.data!;
            final pending = data.today.where((t) => t.status == TaskStatus.pending).toList();
            final completed = data.today.where((t) => t.status == TaskStatus.completed).toList();
            final total = data.today.length;
            final progress = total == 0 ? 0.0 : completed.length / total;

            final grouped = <int, List<DailyTask>>{};
            for (final t in pending) {
              grouped.putIfAbsent(t.priority, () => []).add(t);
            }
            final priorityOrder = [3, 2, 1, 0];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                if (data.overdue.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Overdue (${data.overdue.length})',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  ...data.overdue.map((t) => _TaskTile(
                        task: t,
                        topic: data.topics[t.topicId],
                        onComplete: () => _completeTask(t, data.topics[t.topicId]),
                        onSnooze: () => _snooze(t),
                      )),
                  const SizedBox(height: 20),
                ],
                if (total > 0) ...[
                  Row(
                    children: [
                      Text('Progress', style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      Text('${completed.length} / $total completed'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: progress, minHeight: 10),
                  ),
                  const SizedBox(height: 20),
                ],
                if (pending.isEmpty && data.overdue.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('Nothing planned for today. Enjoy the breathing room.')),
                  ),
                for (final p in priorityOrder)
                  if (grouped[p]?.isNotEmpty ?? false) ...[
                    _SectionHeader(
                      title: TopicPriorityX.fromValue(p).label.toUpperCase(),
                      color: AppTheme.priorityColors[p]!,
                    ),
                    const SizedBox(height: 8),
                    ...grouped[p]!.map((t) => _TaskTile(
                          task: t,
                          topic: data.topics[t.topicId],
                          onComplete: () => _completeTask(t, data.topics[t.topicId]),
                          onSnooze: () => _snooze(t),
                        )),
                    const SizedBox(height: 16),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanData {
  final List<DailyTask> today;
  final List<DailyTask> overdue;
  final Map<String, Topic> topics;
  _PlanData({required this.today, required this.overdue, required this.topics});
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final DailyTask task;
  final Topic? topic;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;

  const _TaskTile({
    required this.task,
    required this.topic,
    required this.onComplete,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.schedule),
      ),
      confirmDismiss: (_) async {
        onSnooze();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: task.status == TaskStatus.completed,
          onChanged: task.status == TaskStatus.completed ? null : (_) => onComplete(),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(topic?.title ?? '(deleted topic)', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${task.taskType == TaskType.study ? 'Study' : 'Revision'} · ${task.estimatedMinutes} min'),
        ),
      ),
    );
  }
}
