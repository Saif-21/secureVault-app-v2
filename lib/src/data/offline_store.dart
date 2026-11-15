import 'package:flutter/foundation.dart';
import 'package:app/src/models/expense_model.dart';
import 'package:app/src/models/todo_model.dart';
import 'package:app/src/models/vault_model.dart';

/// Offline-first data store acting as the local Single Source of Truth (SSOT).
/// Preloaded with realistic Indian Rupee (₹) dummy datasets.
class OfflineStore extends ChangeNotifier {
  OfflineStore._internal() {
    _loadInitialDummyData();
  }

  static final OfflineStore instance = OfflineStore._internal();

  final List<ExpenseItem> _expenses = [];
  final List<TodoItem> _todos = [];
  final List<VaultItem> _vaultItems = [];

  List<ExpenseItem> get expenses => List.unmodifiable(_expenses);
  List<TodoItem> get todos => List.unmodifiable(_todos);
  List<VaultItem> get vaultItems => List.unmodifiable(_vaultItems);

  // Currency Formatter for Indian Rupees (₹)
  static String formatRupees(double amount, {bool showSign = true}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    // Format according to Indian numbering system (e.g. 1,00,000.00)
    String formattedInt = '';
    if (integerPart.length <= 3) {
      formattedInt = integerPart;
    } else {
      final lastThree = integerPart.substring(integerPart.length - 3);
      final remaining = integerPart.substring(0, integerPart.length - 3);
      final buffer = StringBuffer();
      for (var i = 0; i < remaining.length; i++) {
        if (i > 0 && (remaining.length - i) % 2 == 0) {
          buffer.write(',');
        }
        buffer.write(remaining[i]);
      }
      formattedInt = '${buffer.toString()},$lastThree';
    }

    if (showSign && isNegative) {
      return '-₹$formattedInt.$decimalPart';
    } else if (showSign && !isNegative && amount > 0) {
      return '₹$formattedInt.$decimalPart';
    }
    return '₹$formattedInt.$decimalPart';
  }

  // Expense Aggregated Statistics
  double get totalIncome => _expenses
      .where((e) => e.isIncome)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpenses => _expenses
      .where((e) => e.isExpense)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalBorrowed => _expenses
      .where((e) => e.isBorrowed)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get netBalance => totalIncome - totalExpenses - totalBorrowed;

  int get pendingTodosCount => _todos.where((t) => !t.isCompleted).length;

  // CRUD Operations (Instant Offline Mutations)
  void addExpense({
    required String title,
    required String category,
    required double amount,
    required String type,
    String? notes,
  }) {
    final newItem = ExpenseItem(
      id: 'local_exp_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      amount: amount,
      date: DateTime.now(),
      type: type,
      notes: notes,
      isSynced: false,
    );
    _expenses.insert(0, newItem);
    notifyListeners();
  }

  void deleteExpense(String id) {
    _expenses.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void toggleTodo(String id) {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _todos[index];
      _todos[index] = current.copyWith(
        isCompleted: !current.isCompleted,
        isSynced: false,
      );
      notifyListeners();
    }
  }

  void addTodo({
    required String title,
    required String dueDate,
    String tag = 'General',
    double? amount,
  }) {
    final newTodo = TodoItem(
      id: 'local_todo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      dueDate: dueDate,
      tag: tag,
      amount: amount,
      isCompleted: false,
      isSynced: false,
    );
    _todos.insert(0, newTodo);
    notifyListeners();
  }

  void addVaultItem({
    required String title,
    required String username,
    required String password,
    required String group,
    String? website,
  }) {
    final newItem = VaultItem(
      id: 'local_vault_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      username: username,
      password: password,
      group: group,
      website: website,
      isSynced: false,
    );
    _vaultItems.insert(0, newItem);
    notifyListeners();
  }

  void deleteVaultItem(String id) {
    _vaultItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Pre-load realistic Indian Rupee dummy data
  void _loadInitialDummyData() {
    _expenses.addAll([
      ExpenseItem(
        id: 'exp_1',
        title: 'Freelance Software Retainer',
        category: 'Client Work',
        amount: 45000.0,
        date: DateTime.now().subtract(const Duration(hours: 4)),
        type: 'Income',
        notes: 'Monthly milestone payment for SaaS dashboard design.',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_2',
        title: 'Primary Salary Credit',
        category: 'Salary',
        amount: 40000.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
        type: 'Income',
        notes: 'Direct deposit into HDFC account.',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_3',
        title: 'Zepto Daily Groceries & Fruits',
        category: 'Groceries',
        amount: 1850.0,
        date: DateTime.now().subtract(const Duration(hours: 12)),
        type: 'Expense',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_4',
        title: 'Artisan Pour-over Coffee & Pastry',
        category: 'Food & Drinks',
        amount: 340.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        type: 'Expense',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_5',
        title: 'Tata Power Electricity & Fiber Net',
        category: 'Utilities',
        amount: 3200.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: 'Expense',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_6',
        title: 'Apartment Maintenance & Piped Gas',
        category: 'Housing',
        amount: 4500.0,
        date: DateTime.now().subtract(const Duration(days: 5)),
        type: 'Expense',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_7',
        title: 'Swiggy Gourmet Dinner Split',
        category: 'Food & Drinks',
        amount: 680.0,
        date: DateTime.now().subtract(const Duration(days: 6)),
        type: 'Expense',
        isSynced: true,
      ),
      ExpenseItem(
        id: 'exp_8',
        title: 'Lunch Repayment - Amit',
        category: 'Personal Loan',
        amount: 750.0,
        date: DateTime.now().subtract(const Duration(days: 7)),
        type: 'Borrowed',
        notes: 'Settled via UPI.',
        isSynced: true,
      ),
    ]);

    _todos.addAll([
      TodoItem(
        id: 'todo_1',
        title: 'Pay HDFC Regalia Credit Card Bill',
        dueDate: 'Due Tomorrow',
        tag: 'High Priority',
        amount: 14200.0,
        isCompleted: false,
        isSynced: true,
      ),
      TodoItem(
        id: 'todo_2',
        title: 'Review Monthly SIP Mutual Fund Deductions',
        dueDate: 'Due Friday',
        tag: 'Investments',
        amount: 10000.0,
        isCompleted: false,
        isSynced: true,
      ),
      TodoItem(
        id: 'todo_3',
        title: 'File Quarterly GST / ITR Expense Invoices',
        dueDate: 'Due Nov 20',
        tag: 'Taxes',
        isCompleted: false,
        isSynced: true,
      ),
      TodoItem(
        id: 'todo_4',
        title: 'Airtel Postpaid & Broadband Recharge',
        dueDate: 'Due in 4 days',
        tag: 'Bills',
        amount: 999.0,
        isCompleted: false,
        isSynced: true,
      ),
      TodoItem(
        id: 'todo_5',
        title: 'Back up Star Health Insurance Receipts to Vault',
        dueDate: 'Completed',
        tag: 'Health',
        isCompleted: true,
        isSynced: true,
      ),
    ]);

    _vaultItems.addAll([
      VaultItem(
        id: 'vault_1',
        title: 'HDFC NetBanking',
        username: 'hdfc_cust_9281',
        password: '••••••••••••',
        group: 'Banking',
        website: 'https://netbanking.hdfcbank.com',
        isSynced: true,
      ),
      VaultItem(
        id: 'vault_2',
        title: 'Zerodha Kite Trading',
        username: 'alex_kite_in',
        password: '••••••••••••',
        group: 'Investments',
        website: 'https://kite.zerodha.com',
        isSynced: true,
      ),
      VaultItem(
        id: 'vault_3',
        title: 'DigiLocker & Aadhaar PIN',
        username: '982348123490',
        password: '••••••••',
        group: 'Identity',
        website: 'https://digilocker.gov.in',
        isSynced: true,
      ),
      VaultItem(
        id: 'vault_4',
        title: 'AWS & Cloudflare Production',
        username: 'dev.ops@morgan.io',
        password: '••••••••••••••••',
        group: 'Infrastructure',
        website: 'https://aws.amazon.com',
        isSynced: true,
      ),
    ]);
  }
}

