/// Represents a financial todo or reminder item in the offline-first store.
class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    required this.dueDate,
    this.tag = 'General',
    this.amount,
    this.isCompleted = false,
    this.isSynced = false,
  });

  final String id;
  final String title;
  final String dueDate;
  final String tag;
  final double? amount;
  final bool isCompleted;
  final bool isSynced;

  TodoItem copyWith({
    String? id,
    String? title,
    String? dueDate,
    String? tag,
    double? amount,
    bool? isCompleted,
    bool? isSynced,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      tag: tag ?? this.tag,
      amount: amount ?? this.amount,
      isCompleted: isCompleted ?? this.isCompleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

