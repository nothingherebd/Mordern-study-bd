import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/subject.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/topic_repository.dart';
import 'topic_editor.dart';

class StudyScreen extends StatefulWidget {
  final Subject subject;
  const StudyScreen({super.key, required this.subject});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late Future<List<Topic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<TopicRepository>().getBySubject(widget.subject.id);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _openEditor({Topic? topic}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TopicEditor(subject: widget.subject, existing: topic),
      ),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Topic>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final topics = snap.data!;
            if (topics.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No topics yet. Tap + to add one.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: topics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = topics[i];
                final color = AppTheme.priorityColors[t.priority.value]!;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${t.priority.label} · ${t.estimatedMinutes} min · ${_statusLabel(t.status)}'),
                    onTap: () => _openEditor(topic: t),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(TopicStatus s) => switch (s) {
        TopicStatus.notStarted => 'Not started',
        TopicStatus.inProgress => 'In progress',
        TopicStatus.learned => 'Learned',
        TopicStatus.mastered => 'Mastered',
      };
}
