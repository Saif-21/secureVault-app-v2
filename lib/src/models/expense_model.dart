/// Represents an expense or income transaction in the offline-first store.
class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.type,
    this.notes,
    this.isSynced = false,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String type; // 'Expense', 'Income', 'Borrowed'
  final String? notes;
  final bool isSynced;

  bool get isExpense => type == 'Expense';
  bool get isIncome => type == 'Income';
  bool get isBorrowed => type == 'Borrowed';

  ExpenseItem copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? type,
    String? notes,
    bool? isSynced,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

