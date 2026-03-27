enum TodoStatus { pending, inProgress, done }

class TodoTask {
  final String id;
  final String title;
  final String? description;
  final int priority; // 1-5
  final TodoStatus status;
  final String? dueDate;
  final String createdAt;
  final String? meetingEventId;

  TodoTask({
    required this.id,
    required this.title,
    this.description,
    this.priority = 3,
    this.status = TodoStatus.pending,
    this.dueDate,
    required this.createdAt,
    this.meetingEventId,
  });

  /// Auto-escalation: after 2 days, priority increases by 1/day, capped at 5
  int get effectivePriority {
    final created = DateTime.parse(createdAt);
    final daysSince = DateTime.now().difference(created).inDays;
    if (daysSince <= 2 || status == TodoStatus.done) return priority;
    final escalation = daysSince - 2;
    return (priority + escalation).clamp(1, 5);
  }

  bool get isEscalated => effectivePriority > priority;

  TodoTask copyWith({
    String? title, String? description, int? priority,
    TodoStatus? status, String? dueDate,
  }) => TodoTask(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    dueDate: dueDate ?? this.dueDate,
    createdAt: createdAt,
    meetingEventId: meetingEventId,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'priority': priority, 'status': status.name,
    'dueDate': dueDate, 'createdAt': createdAt,
    'meetingEventId': meetingEventId,
  };

  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    priority: json['priority'] as int? ?? 3,
    status: TodoStatus.values.byName(json['status'] as String? ?? 'pending'),
    dueDate: json['dueDate'] as String?,
    createdAt: json['createdAt'] as String,
    meetingEventId: json['meetingEventId'] as String?,
  );

  static const priorityLabels = {1: 'Low', 2: 'Medium-Low', 3: 'Medium', 4: 'High', 5: 'Critical'};
}
