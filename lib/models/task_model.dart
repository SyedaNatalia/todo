class Task {
  final String id;
  final String task;
  final String assignedTo;
  final String assignedBy;
  final String pair;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final bool isDone;
  final String status;

  Task({
    required this.id,
    required this.task,
    required this.assignedTo,
    required this.assignedBy,
    required this.pair,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    required this.isDone,
    required this.status,
  });

  factory Task.fromFirestore(Map<String, dynamic> data, String id) {
    return Task(
      id: id,
      task: data['task'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      pair: data['pair'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as dynamic)?.toDate(),
      isDone: data['isDone'] ?? false,
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'task': task,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'pair': pair,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dueDate': dueDate,
      'isDone': isDone,
      'status': status,
    };
  }

  Task copyWith({
    String? task,
    String? assignedTo,
    String? assignedBy,
    String? pair,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    bool? isDone,
    String? status,
  }) {
    return Task(
      id: this.id,
      task: task ?? this.task,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      pair: pair ?? this.pair,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      status: status ?? this.status,
    );
  }
}

