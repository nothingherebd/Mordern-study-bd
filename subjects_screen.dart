import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/subject.dart';
import '../../data/repositories/subject_repository.dart';
import '../study/study_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});
  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  late Future<List<Subject>> _future;

  static const _palette = [
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<SubjectRepository>().getAll();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _createSubject() async {
    final controller = TextEditingController();
    Color chosen = _palette.first;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(builder: (ctx, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New subject', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Subject name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: _palette.map((c) {
                  final selected = c == chosen;
                  return GestureDetector(
                    onTap: () => setSheetState(() => chosen = c),
                    child: CircleAvatar(
                      backgroundColor: c,
                      radius: selected ? 18 : 14,
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await context.read<SubjectRepository>().create(
                            name: name,
                            color: chosen.value,
                          );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ),
            ],
          );
        }),
      ),
    );
    if (result == true) await _refresh();
  }

  Future<void> _confirmDelete(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
          'This permanently deletes "${subject.name}" and every topic, '
          'revision schedule, and history entry inside it. This can\'t be undone.',
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
      await context.read<SubjectRepository>().deleteCascade(subject.id);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSubject,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Subject>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final subjects = snap.data!;
            if (subjects.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No subjects yet. Tap + to add one.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = subjects[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(backgroundColor: Color(s.color)),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: s.description == null || s.description!.isEmpty
                        ? null
                        : Text(s.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete(s);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StudyScreen(subject: s)),
                    ).then((_) => _refresh()),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
