import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../models/todo_task.dart';
import '../providers/app_providers.dart';

class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key});

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  final _titleController = TextEditingController();
  String _filterStatus = 'all';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _addTodo() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    ref.read(todosProvider.notifier).addTodo(TodoTask(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now().toIso8601String(),
    ));
    _titleController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider);

    final filtered = _filterStatus == 'all'
        ? todos
        : todos.where((t) => t.status.name == _filterStatus).toList();

    // Sort: pending/inProgress first, then by effective priority desc
    filtered.sort((a, b) {
      if (a.status == TodoStatus.done && b.status != TodoStatus.done) return 1;
      if (a.status != TodoStatus.done && b.status == TodoStatus.done) return -1;
      return b.effectivePriority.compareTo(a.effectivePriority);
    });

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('To-Do', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CatppuccinMocha.text)),
          const SizedBox(height: 16),

          // Add task row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: 'Add a new task...', isDense: true),
                  onSubmitted: (_) => _addTodo(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _addTodo, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chips
          Wrap(
            spacing: 8,
            children: [
              for (final filter in ['all', 'pending', 'inProgress', 'done'])
                ChoiceChip(
                  label: Text(filter == 'inProgress' ? 'In Progress' : filter[0].toUpperCase() + filter.substring(1)),
                  selected: _filterStatus == filter,
                  onSelected: (_) => setState(() => _filterStatus = filter),
                  selectedColor: CatppuccinMocha.blue.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _filterStatus == filter ? CatppuccinMocha.blue : CatppuccinMocha.overlay0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Task count
          Text(
            '${filtered.length} task${filtered.length != 1 ? 's' : ''}',
            style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Task list
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No tasks yet.', style: TextStyle(color: CatppuccinMocha.overlay0)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      return _TodoCard(task: task);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TodoCard extends ConsumerWidget {
  final TodoTask task;
  const _TodoCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.status == TodoStatus.done;
    final priorityLabel = TodoTask.priorityLabels[task.effectivePriority] ?? 'Medium';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CatppuccinMocha.surface0,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            width: 4,
            color: isDone
                ? CatppuccinMocha.green
                : task.effectivePriority >= 4
                    ? CatppuccinMocha.red
                    : CatppuccinMocha.blue,
          ),
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: isDone,
            onChanged: (val) {
              ref.read(todosProvider.notifier).updateTodo(task.id, {
                'status': val == true ? 'done' : 'pending',
              });
            },
            activeColor: CatppuccinMocha.green,
          ),
          const SizedBox(width: 8),
          // Title + priority
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: isDone ? CatppuccinMocha.overlay0 : CatppuccinMocha.text,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      priorityLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.effectivePriority >= 4 ? CatppuccinMocha.red : CatppuccinMocha.overlay0,
                      ),
                    ),
                    if (task.isEscalated)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('\u2191 escalated', style: TextStyle(fontSize: 11, color: CatppuccinMocha.peach)),
                      ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.description!,
                          style: const TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: CatppuccinMocha.overlay0),
            onPressed: () => ref.read(todosProvider.notifier).deleteTodo(task.id),
          ),
        ],
      ),
    );
  }
}
