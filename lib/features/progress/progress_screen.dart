import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<_Stats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Stats> _load() async {
    final subjects = await context.read<SubjectRepository>().getAll();
    final topics = await context.read<TopicRepository>().getAll();
    final historyCount = await context.read<RevisionRepository>().countHistory();

    int completedTopics = 0;
    int totalMinutes = 0;
    for (final t in topics) {
      if (t.status.name == 'mastered' || t.status.name == 'learned') completedTopics++;
      totalMinutes += t.estimatedMinutes;
    }

    return _Stats(
      subjects: subjects.length,
      topics: topics.length,
      completed: completedTopics,
      revisions: historyCount,
      totalMinutes: totalMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: FutureBuilder<_Stats>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!;
          final hours = s.totalMinutes ~/ 60;
          final mins = s.totalMinutes % 60;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(label: 'Subjects', value: '${s.subjects}'),
                  _StatCard(label: 'Topics', value: '${s.topics}'),
                  _StatCard(label: 'Completed', value: '${s.completed}'),
                  _StatCard(label: 'Revisions', value: '${s.revisions}'),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(label: 'Planned study time', value: '${hours}h ${mins}m', wide: true),
            ],
          );
        },
      ),
    );
  }
}

class _Stats {
  final int subjects, topics, completed, revisions, totalMinutes;
  _Stats({
    required this.subjects,
    required this.topics,
    required this.completed,
    required this.revisions,
    required this.totalMinutes,
  });
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool wide;
  const _StatCard({required this.label, required this.value, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
