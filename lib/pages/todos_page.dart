import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final now = DateTime.now();
    ref.read(todosProvider.notifier).addTodo(TodoTask(
      id: const Uuid().v4(),
      title: title,
      createdAt: now.toIso8601String(),
      dueDate: now.add(const Duration(days: 2)).toIso8601String(),
    ));
    _titleController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider);

    final filtered = (_filterStatus == 'all'
            ? todos
            : todos.where((t) => t.status.name == _filterStatus).toList())
        .toList();

    filtered.sort((a, b) {
      int rank(TodoStatus s) => switch (s) {
            TodoStatus.inProgress => 0,
            TodoStatus.pending => 1,
            TodoStatus.onHold => 2,
            TodoStatus.done => 3,
          };
      final r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;
      return b.effectivePriority.compareTo(a.effectivePriority);
    });

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('To-Do',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CatppuccinMocha.text)),
          const SizedBox(height: 16),

          // Add task row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                      hintText: 'Add a new task...', isDense: true),
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
              for (final filter in ['all', 'pending', 'inProgress', 'done', 'onHold'])
                ChoiceChip(
                  label: Text({
                    'all': 'All',
                    'pending': 'Pending',
                    'inProgress': 'In Progress',
                    'done': 'Done',
                    'onHold': 'On Hold',
                  }[filter]!),
                  selected: _filterStatus == filter,
                  onSelected: (_) => setState(() => _filterStatus = filter),
                  selectedColor: CatppuccinMocha.blue.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _filterStatus == filter
                        ? CatppuccinMocha.blue
                        : CatppuccinMocha.overlay0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            '${filtered.length} task${filtered.length != 1 ? 's' : ''}',
            style:
                const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No tasks yet.',
                        style: TextStyle(color: CatppuccinMocha.overlay0)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _TodoCard(task: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Edit dialog ────────────────────────────────────────────────────────────────

class _EditTodoDialog extends ConsumerStatefulWidget {
  final TodoTask task;
  const _EditTodoDialog({required this.task});

  @override
  ConsumerState<_EditTodoDialog> createState() => _EditTodoDialogState();
}

class _EditTodoDialogState extends ConsumerState<_EditTodoDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late int _priority;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description ?? '');
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate != null
        ? DateTime.tryParse(widget.task.dueDate!)?.toLocal()
        : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: CatppuccinMocha.mauve,
            onPrimary: CatppuccinMocha.base,
            surface: CatppuccinMocha.surface0,
            onSurface: CatppuccinMocha.text,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: CatppuccinMocha.base),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    await ref.read(todosProvider.notifier).updateTodo(widget.task.id, {
      'title': title,
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'priority': _priority,
      'dueDate': _dueDate?.toIso8601String(),
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CatppuccinMocha.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Task',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CatppuccinMocha.text)),
              const SizedBox(height: 20),

              // Title
              const Text('Title',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CatppuccinMocha.subtext1)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: const TextStyle(color: CatppuccinMocha.text),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: CatppuccinMocha.surface0,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CatppuccinMocha.surface2)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CatppuccinMocha.surface2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CatppuccinMocha.mauve)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Notes / Description',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CatppuccinMocha.subtext1)),
              const SizedBox(height: 6),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(color: CatppuccinMocha.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Optional notes...',
                  hintStyle: const TextStyle(color: CatppuccinMocha.overlay0),
                  isDense: true,
                  filled: true,
                  fillColor: CatppuccinMocha.surface0,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CatppuccinMocha.surface2)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CatppuccinMocha.surface2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CatppuccinMocha.mauve)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 16),

              // Priority
              const Text('Priority',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CatppuccinMocha.subtext1)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _priority.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: CatppuccinMocha.mauve,
                      onChanged: (v) => setState(() => _priority = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      TodoTask.priorityLabels[_priority] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: _priority >= 4
                            ? CatppuccinMocha.red
                            : CatppuccinMocha.overlay0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Due date
              const Text('Due Date',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CatppuccinMocha.subtext1)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: CatppuccinMocha.surface0,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CatppuccinMocha.surface2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: CatppuccinMocha.mauve),
                            const SizedBox(width: 8),
                            Text(
                              _dueDate != null
                                  ? DateFormat('MMM d, yyyy').format(_dueDate!)
                                  : 'Set due date',
                              style: TextStyle(
                                fontSize: 13,
                                color: _dueDate != null
                                    ? CatppuccinMocha.text
                                    : CatppuccinMocha.overlay0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Clear due date',
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: CatppuccinMocha.overlay0),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: CatppuccinMocha.overlay0),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CatppuccinMocha.mauve,
                      foregroundColor: CatppuccinMocha.base,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Task card ──────────────────────────────────────────────────────────────────

class _TodoCard extends ConsumerWidget {
  final TodoTask task;
  const _TodoCard({required this.task});

  static const _statusConfig = {
    TodoStatus.pending: (
      icon: Icons.radio_button_unchecked,
      color: CatppuccinMocha.overlay0,
      label: 'To Do',
    ),
    TodoStatus.inProgress: (
      icon: Icons.timelapse,
      color: CatppuccinMocha.yellow,
      label: 'In Progress',
    ),
    TodoStatus.done: (
      icon: Icons.check_circle,
      color: CatppuccinMocha.green,
      label: 'Done',
    ),
    TodoStatus.onHold: (
      icon: Icons.pause_circle_outline,
      color: CatppuccinMocha.mauve,
      label: 'On Hold',
    ),
  };

  Color get _borderColor {
    if (task.status == TodoStatus.done) return CatppuccinMocha.green;
    if (task.status == TodoStatus.inProgress) return CatppuccinMocha.yellow;
    if (task.status == TodoStatus.onHold) return CatppuccinMocha.mauve;
    if (task.effectivePriority >= 4) return CatppuccinMocha.red;
    return CatppuccinMocha.blue;
  }

  Future<void> _onStatusSelected(
      BuildContext context, WidgetRef ref, TodoStatus status) async {
    if (status == TodoStatus.onHold) {
      final holdUntil = await showDialog<DateTime>(
        context: context,
        builder: (_) => const _HoldUntilDialog(),
      );
      if (holdUntil == null) return; // cancelled
      await ref.read(todosProvider.notifier).updateTodo(task.id, {
        'status': 'onHold',
        'holdUntil': holdUntil.toIso8601String(),
      });
    } else {
      await ref.read(todosProvider.notifier).updateTodo(task.id, {
        'status': status.name,
        'holdUntil': null,
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = _statusConfig[task.status]!;
    final isDone = task.status == TodoStatus.done;
    final priorityLabel = TodoTask.priorityLabels[task.effectivePriority] ?? 'Medium';

    // Look up meeting name from history if this task came from a meeting
    final history = ref.watch(meetingHistoryProvider);
    final meetingName = task.meetingEventId != null
        ? history
            .where((r) => r.eventId == task.meetingEventId)
            .firstOrNull
            ?.title
        : null;

    final createdAt = DateTime.tryParse(task.createdAt);
    final createdLabel = createdAt != null
        ? DateFormat('MMM d, yyyy').format(createdAt)
        : null;

    final dueDate = task.dueDate != null ? DateTime.tryParse(task.dueDate!)?.toLocal() : null;
    final now = DateTime.now();
    final dueLabel = dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : null;
    final isOverdue = dueDate != null && !isDone &&
        dueDate.isBefore(DateTime(now.year, now.month, now.day));
    final isDueToday = dueDate != null && !isDone &&
        dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
    final dueLabelColor = isOverdue
        ? CatppuccinMocha.red
        : isDueToday
            ? CatppuccinMocha.peach
            : CatppuccinMocha.subtext0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CatppuccinMocha.surface0,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(width: 4, color: _borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon — tap to open status picker
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Tooltip(
              message: 'Change status',
              child: PopupMenuButton<TodoStatus>(
                onSelected: (status) =>
                    _onStatusSelected(context, ref, status),
                itemBuilder: (_) => _statusConfig.entries.map((e) {
                  final selected = e.key == task.status;
                  return PopupMenuItem(
                    value: e.key,
                    child: Row(
                      children: [
                        Icon(e.value.icon, color: e.value.color, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          e.value.label,
                          style: TextStyle(
                            color: selected
                                ? CatppuccinMocha.text
                                : CatppuccinMocha.subtext0,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (selected) ...[
                          const Spacer(),
                          const Icon(Icons.check,
                              size: 14, color: CatppuccinMocha.green),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                padding: EdgeInsets.zero,
                child: Icon(cfg.icon, color: cfg.color, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  task.title,
                  style: TextStyle(
                    color: isDone
                        ? CatppuccinMocha.overlay0
                        : CatppuccinMocha.text,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),

                // Status + priority row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Status badge
                    _Badge(
                      label: cfg.label,
                      color: cfg.color,
                    ),
                    // Priority
                    Text(
                      priorityLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.effectivePriority >= 4
                            ? CatppuccinMocha.red
                            : CatppuccinMocha.overlay0,
                      ),
                    ),
                    if (task.isEscalated)
                      const Text('↑ escalated',
                          style: TextStyle(
                              fontSize: 11, color: CatppuccinMocha.peach)),
                  ],
                ),

                // Description
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: const TextStyle(
                        fontSize: 12, color: CatppuccinMocha.overlay0),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Hold-until row
                if (task.status == TodoStatus.onHold && task.holdUntil != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule,
                          size: 11, color: CatppuccinMocha.mauve),
                      const SizedBox(width: 4),
                      Text(
                        'Resumes ${DateFormat('MMM d, yyyy – h:mm a').format(DateTime.parse(task.holdUntil!).toLocal())}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: CatppuccinMocha.mauve,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],

                // Meeting name + created date + due date
                if (meetingName != null || createdLabel != null || dueLabel != null) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: CatppuccinMocha.surface1),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      if (meetingName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event,
                                size: 11, color: CatppuccinMocha.subtext0),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                meetingName,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: CatppuccinMocha.subtext0),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (createdLabel != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 11, color: CatppuccinMocha.subtext0),
                            const SizedBox(width: 4),
                            Text(
                              createdLabel,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: CatppuccinMocha.subtext0),
                            ),
                          ],
                        ),
                      if (dueLabel != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverdue ? Icons.warning_amber_rounded : Icons.flag_outlined,
                              size: 11,
                              color: dueLabelColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Due $dueLabel',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: dueLabelColor,
                                  fontWeight: isOverdue || isDueToday
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action buttons: edit + delete
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: CatppuccinMocha.overlay0),
                tooltip: 'Edit task',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _EditTodoDialog(task: task),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: CatppuccinMocha.overlay0),
                tooltip: 'Delete task',
                onPressed: () =>
                    ref.read(todosProvider.notifier).deleteTodo(task.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hold Until dialog ──────────────────────────────────────────────────────────

class _HoldUntilDialog extends StatefulWidget {
  const _HoldUntilDialog();

  @override
  State<_HoldUntilDialog> createState() => _HoldUntilDialogState();
}

class _HoldUntilDialogState extends State<_HoldUntilDialog> {
  DateTime _holdUntil = DateTime.now().add(const Duration(days: 1));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _holdUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: CatppuccinMocha.mauve,
            onPrimary: CatppuccinMocha.base,
            surface: CatppuccinMocha.surface0,
            onSurface: CatppuccinMocha.text,
          ),
          dialogTheme:
              const DialogThemeData(backgroundColor: CatppuccinMocha.base),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _holdUntil = DateTime(
            picked.year, picked.month, picked.day,
            _holdUntil.hour, _holdUntil.minute,
          ));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_holdUntil),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: CatppuccinMocha.mauve,
            onPrimary: CatppuccinMocha.base,
            surface: CatppuccinMocha.surface0,
            onSurface: CatppuccinMocha.text,
          ),
          dialogTheme:
              const DialogThemeData(backgroundColor: CatppuccinMocha.base),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _holdUntil = DateTime(
            _holdUntil.year, _holdUntil.month, _holdUntil.day,
            picked.hour, picked.minute,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CatppuccinMocha.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.pause_circle_outline,
                      color: CatppuccinMocha.mauve, size: 20),
                  SizedBox(width: 8),
                  Text('Put on Hold',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: CatppuccinMocha.text)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'The task will automatically resume to Pending at the selected date and time.',
                style: TextStyle(
                    fontSize: 12, color: CatppuccinMocha.overlay0),
              ),
              const SizedBox(height: 20),

              const Text('Resume on',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CatppuccinMocha.subtext1)),
              const SizedBox(height: 8),

              // Date row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: CatppuccinMocha.surface0,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: CatppuccinMocha.surface2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: CatppuccinMocha.mauve),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d, yyyy').format(_holdUntil),
                              style: const TextStyle(
                                  fontSize: 13, color: CatppuccinMocha.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: CatppuccinMocha.surface0,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: CatppuccinMocha.surface2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 14, color: CatppuccinMocha.mauve),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('h:mm a').format(_holdUntil),
                              style: const TextStyle(
                                  fontSize: 13, color: CatppuccinMocha.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: CatppuccinMocha.overlay0),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_holdUntil),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CatppuccinMocha.mauve,
                      foregroundColor: CatppuccinMocha.base,
                    ),
                    child: const Text('Put on Hold'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
