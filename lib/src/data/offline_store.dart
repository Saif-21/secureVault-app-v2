import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/src/models/expense_model.dart';
import 'package:app/src/models/todo_model.dart';
import 'package:app/src/models/vault_model.dart';
import 'package:app/src/services/api_service.dart';
import 'package:app/src/services/auth_service.dart';

/// Offline-first data store acting as the local Single Source of Truth (SSOT).
/// Preloaded with realistic Indian Rupee (₹) dummy datasets.
class OfflineStore extends ChangeNotifier {
  OfflineStore._internal() {
    _loadInitialDummyData();
    loadPersistedVaultData();
  }

  static final OfflineStore instance = OfflineStore._internal();

  final ApiService _apiService = ApiService();

  final List<ExpenseItem> _expenses = [];
  final List<TodoItem> _todos = [];
  final List<VaultItem> _vaultItems = [];
  final List<VaultCategory> _vaultCategories = [
    const VaultCategory(id: 'work', name: 'Work', emoji: 'briefcase'),
    const VaultCategory(id: 'individual', name: 'Individual', emoji: 'user'),
    const VaultCategory(id: 'financial', name: 'Financial', emoji: 'credit-card'),
  ];

  bool _isVaultSyncing = false;
  String? _vaultSyncError;
  DateTime? _lastVaultSyncTime;
  final List<String> _pendingVaultDeletes = [];

  bool get isVaultSyncing => _isVaultSyncing;
  String? get vaultSyncError => _vaultSyncError;
  DateTime? get lastVaultSyncTime => _lastVaultSyncTime;

  static const String _keyVaultItems = 'offline_vault_items';
  static const String _keyVaultCategories = 'offline_vault_categories';
  static const String _keyVaultPendingDeletes = 'offline_vault_pending_deletes';

  List<ExpenseItem> get expenses => List.unmodifiable(_expenses);
  List<TodoItem> get todos => List.unmodifiable(_todos);
  List<VaultItem> get vaultItems => List.unmodifiable(_vaultItems);
  List<VaultCategory> get vaultCategories => List.unmodifiable(_vaultCategories);

  Future<void> _persistVaultData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = jsonEncode(_vaultItems.map((e) => e.toJson()).toList());
      final catsJson = jsonEncode(_vaultCategories.map((e) => e.toJson()).toList());
      final pendingJson = jsonEncode(_pendingVaultDeletes);

      await prefs.setString(_keyVaultItems, itemsJson);
      await prefs.setString(_keyVaultCategories, catsJson);
      await prefs.setString(_keyVaultPendingDeletes, pendingJson);
    } catch (e) {
      debugPrint('[OfflineStore] Failed to persist vault data: $e');
    }
  }

  Future<void> loadPersistedVaultData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsStr = prefs.getString(_keyVaultItems);
      final catsStr = prefs.getString(_keyVaultCategories);
      final pendingStr = prefs.getString(_keyVaultPendingDeletes);

      if (pendingStr != null && pendingStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(pendingStr);
        _pendingVaultDeletes.clear();
        _pendingVaultDeletes.addAll(list.map((e) => e.toString()));
      }

      if (catsStr != null && catsStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(catsStr);
        final loadedCats = list.map((e) => VaultCategory.fromJson(e as Map<String, dynamic>)).toList();
        if (loadedCats.isNotEmpty) {
          _vaultCategories.clear();
          _vaultCategories.addAll(loadedCats);
        }
      }

      if (itemsStr != null && itemsStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(itemsStr);
        final loadedItems = list.map((e) => VaultItem.fromJson(e as Map<String, dynamic>)).toList();
        if (loadedItems.isNotEmpty) {
          _vaultItems.clear();
          for (final item in loadedItems) {
            String cleanGroup = item.group;
            if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(cleanGroup) ||
                cleanGroup.startsWith('local_') ||
                cleanGroup.startsWith('vault_')) {
              final match = _vaultCategories.firstWhere(
                (c) => c.serverId == cleanGroup || c.id == cleanGroup,
                orElse: () => _vaultCategories.isNotEmpty
                    ? _vaultCategories.first
                    : const VaultCategory(id: 'work', name: 'Work', emoji: '📁'),
              );
              cleanGroup = match.name;
            }
            _vaultItems.add(item.copyWith(group: cleanGroup));
          }
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[OfflineStore] Failed to load persisted vault data: $e');
    }
  }

  void addVaultCategory({required String name, required String emoji}) {
    final trimmedName = name.trim();
    final id = trimmedName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (_vaultCategories.any((c) => c.name.toLowerCase() == trimmedName.toLowerCase())) {
      return;
    }
    final newCat = VaultCategory(
      id: id,
      name: trimmedName,
      emoji: emoji,
      isSynced: false,
    );
    _vaultCategories.add(newCat);
    _persistVaultData();
    notifyListeners();

    // Background push to live db if authenticated
    _syncSingleCategoryToLiveDb(newCat);
  }

  Future<void> _syncSingleCategoryToLiveDb(VaultCategory cat) async {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) return;

    try {
      final res = await _apiService.createVaultGroup(
        token: token,
        name: cat.name,
        icon: cat.emoji,
      );
      final serverId = res['_id']?.toString() ?? res['id']?.toString();
      if (serverId != null) {
        final idx = _vaultCategories.indexWhere((c) => c.id == cat.id || c.name.toLowerCase() == cat.name.toLowerCase());
        if (idx != -1) {
          _vaultCategories[idx] = _vaultCategories[idx].copyWith(serverId: serverId, isSynced: true);
          _persistVaultData();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[OfflineStore] Background addVaultCategory sync: $e');
    }
  }

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
    String? notes,
    String? iconEmoji,
  }) {
    final newItem = VaultItem(
      id: 'local_vault_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      username: username,
      password: password,
      group: group,
      website: website,
      notes: notes,
      iconEmoji: iconEmoji,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    _vaultItems.insert(0, newItem);
    _persistVaultData();
    notifyListeners();

    // Background push to live db if authenticated
    _syncSinglePasswordToLiveDb(newItem);
  }

  Future<void> _syncSinglePasswordToLiveDb(VaultItem item) async {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) return;

    try {
      final matchedCat = _vaultCategories.firstWhere(
        (c) => c.name.toLowerCase() == item.group.toLowerCase(),
        orElse: () => const VaultCategory(id: '', name: '', emoji: ''),
      );
      final groupId = matchedCat.serverId;

      final res = await _apiService.addVaultPassword(
        token: token,
        title: item.title,
        username: item.username,
        password: item.password,
        website: item.website,
        notes: item.notes,
        groupId: groupId,
      );
      final serverId = res['_id']?.toString() ?? res['id']?.toString();
      if (serverId != null) {
        final idx = _vaultItems.indexWhere((i) => i.id == item.id);
        if (idx != -1) {
          _vaultItems[idx] = _vaultItems[idx].copyWith(serverId: serverId, isSynced: true);
          _persistVaultData();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[OfflineStore] Background addVaultPassword sync: $e');
    }
  }

  void deleteVaultItem(String id) {
    final index = _vaultItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _vaultItems[index];
      if (item.serverId != null && item.serverId!.isNotEmpty) {
        _pendingVaultDeletes.add(item.serverId!);
      }
      _vaultItems.removeAt(index);
      _persistVaultData();
      notifyListeners();

      if (item.serverId != null) {
        _syncPasswordDeleteToLiveDb(item.serverId!);
      }
    }
  }

  Future<void> _syncPasswordDeleteToLiveDb(String serverId) async {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) return;

    try {
      await _apiService.deleteVaultPassword(token: token, passwordId: serverId);
      _pendingVaultDeletes.remove(serverId);
      _persistVaultData();
    } catch (e) {
      debugPrint('[OfflineStore] Background deleteVaultPassword sync: $e');
    }
  }

  void updateVaultItem({
    required String id,
    required String title,
    required String username,
    required String password,
    required String group,
    String? website,
    String? notes,
    String? iconEmoji,
  }) {
    final index = _vaultItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      final updated = _vaultItems[index].copyWith(
        title: title,
        username: username,
        password: password,
        group: group,
        website: website,
        notes: notes,
        iconEmoji: iconEmoji,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      _vaultItems[index] = updated;
      _persistVaultData();
      notifyListeners();

      // Background patch to live db if authenticated
      _syncPasswordUpdateToLiveDb(updated);
    }
  }

  Future<void> _syncPasswordUpdateToLiveDb(VaultItem item) async {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty || item.serverId == null) return;

    try {
      final matchedCat = _vaultCategories.firstWhere(
        (c) => c.name.toLowerCase() == item.group.toLowerCase(),
        orElse: () => const VaultCategory(id: '', name: '', emoji: ''),
      );

      await _apiService.updateVaultPassword(
        token: token,
        passwordId: item.serverId!,
        data: {
          'title': item.title,
          'username': item.username,
          'password': item.password,
          if (item.website != null) 'website': item.website,
          if (item.notes != null) 'notes': item.notes,
          if (matchedCat.serverId != null) 'groupId': matchedCat.serverId,
        },
      );
      final idx = _vaultItems.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _vaultItems[idx] = _vaultItems[idx].copyWith(isSynced: true);
        _persistVaultData();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OfflineStore] Background updateVaultPassword sync: $e');
    }
  }

  /// Full bi-directional synchronization between local offline vault and live MongoDB database
  Future<void> syncVaultWithLiveDb({bool silent = false}) async {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) {
      return;
    }

    if (_isVaultSyncing) return;

    _isVaultSyncing = true;
    _vaultSyncError = null;
    if (!silent) notifyListeners();

    try {
      // 1. Flush pending local deletions to server
      final deletesCopy = List<String>.from(_pendingVaultDeletes);
      for (final delId in deletesCopy) {
        try {
          await _apiService.deleteVaultPassword(token: token, passwordId: delId);
          _pendingVaultDeletes.remove(delId);
        } catch (_) {}
      }

      // 2. Fetch live groups from server
      final liveGroups = await _apiService.getVaultGroups(token);
      for (final groupMap in liveGroups) {
        final cat = VaultCategory.fromApiJson(groupMap);
        final existingIdx = _vaultCategories.indexWhere(
          (c) => c.serverId == cat.serverId || c.name.toLowerCase() == cat.name.toLowerCase(),
        );
        if (existingIdx != -1) {
          _vaultCategories[existingIdx] = _vaultCategories[existingIdx].copyWith(
            serverId: cat.serverId,
            emoji: cat.emoji,
            isSynced: true,
          );
        } else {
          _vaultCategories.add(cat);
        }
      }

      // 3. Push unsynced categories to server
      for (var i = 0; i < _vaultCategories.length; i++) {
        final c = _vaultCategories[i];
        if (!c.isSynced || c.serverId == null) {
          try {
            final res = await _apiService.createVaultGroup(
              token: token,
              name: c.name,
              icon: c.emoji,
            );
            final sId = res['_id']?.toString() ?? res['id']?.toString();
            if (sId != null) {
              _vaultCategories[i] = c.copyWith(serverId: sId, isSynced: true);
            }
          } catch (_) {}
        }
      }

      // 4. Push unsynced passwords to server
      for (var i = 0; i < _vaultItems.length; i++) {
        final item = _vaultItems[i];
        if (!item.isSynced || item.serverId == null) {
          try {
            final matchedCat = _vaultCategories.firstWhere(
              (c) => c.name.toLowerCase() == item.group.toLowerCase(),
              orElse: () => const VaultCategory(id: '', name: '', emoji: ''),
            );
            final res = await _apiService.addVaultPassword(
              token: token,
              title: item.title,
              username: item.username,
              password: item.password,
              website: item.website,
              notes: item.notes,
              groupId: matchedCat.serverId,
            );
            final sId = res['_id']?.toString() ?? res['id']?.toString();
            if (sId != null) {
              _vaultItems[i] = item.copyWith(serverId: sId, isSynced: true);
            }
          } catch (_) {}
        }
      }

      // 5. Fetch live passwords from server
      final livePasswords = await _apiService.getVaultPasswords(token: token);
      for (final passMap in livePasswords) {
        final rawGroupId = passMap['group'] is Map
            ? passMap['group']['_id']?.toString() ?? passMap['group']['id']?.toString()
            : passMap['group']?.toString();

        final cat = _vaultCategories.firstWhere(
          (c) =>
              (rawGroupId != null && (c.serverId == rawGroupId || c.id == rawGroupId)) ||
              c.name.toLowerCase() == (passMap['group']?.toString() ?? '').toLowerCase(),
          orElse: () => _vaultCategories.isNotEmpty
              ? _vaultCategories.first
              : const VaultCategory(id: 'work', name: 'Work', emoji: '📁'),
        );

        final serverItem = VaultItem.fromApiJson(
          passMap,
          categories: _vaultCategories,
          defaultGroup: cat.name,
        );

        final resolvedGroup = cat.name;

        final existingIdx = _vaultItems.indexWhere(
          (item) => (item.serverId != null && item.serverId == serverItem.serverId) ||
              (item.title.toLowerCase() == serverItem.title.toLowerCase() &&
               item.username.toLowerCase() == serverItem.username.toLowerCase()),
        );
        if (existingIdx != -1) {
          _vaultItems[existingIdx] = serverItem.copyWith(
            id: _vaultItems[existingIdx].id,
            group: resolvedGroup,
            iconEmoji: cat.emoji,
          );
        } else {
          _vaultItems.add(serverItem.copyWith(
            group: resolvedGroup,
            iconEmoji: cat.emoji,
          ));
        }
      }

      _lastVaultSyncTime = DateTime.now();
      await _persistVaultData();
    } on ApiException catch (e) {
      _vaultSyncError = e.message;
      debugPrint('[OfflineStore] Vault sync API error (offline fallback preserved): $e');
    } catch (e) {
      _vaultSyncError = e.toString();
      debugPrint('[OfflineStore] Vault sync general error (offline fallback preserved): $e');
    } finally {
      _isVaultSyncing = false;
      notifyListeners();
    }
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
        title: 'Facebook',
        username: 'facebook.com',
        password: 'Password@2026',
        group: 'Work',
        website: 'https://facebook.com',
        notes: 'Corporate marketing account',
        iconEmoji: 'briefcase',
        updatedAt: DateTime.now().subtract(const Duration(hours: 20)),
        isSynced: true,
      ),
      VaultItem(
        id: 'vault_2',
        title: 'HDFC NetBanking',
        username: 'hdfc_cust_9281',
        password: 'SecureBank#789',
        group: 'Financial',
        website: 'https://netbanking.hdfcbank.com',
        notes: 'Primary salary account',
        iconEmoji: 'credit-card',
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        isSynced: true,
      ),
      VaultItem(
        id: 'vault_3',
        title: 'Netflix Premium',
        username: 'alex.morgan@gmail.com',
        password: 'FamilyWatch!55',
        group: 'Individual',
        website: 'https://netflix.com',
        notes: '4K UltraHD subscription',
        iconEmoji: 'tv',
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        isSynced: true,
      ),
      VaultItem(
        id: 'vault_4',
        title: 'Zerodha Kite Trading',
        username: 'alex_kite_in',
        password: 'KiteEquity#99',
        group: 'Financial',
        website: 'https://kite.zerodha.com',
        iconEmoji: 'credit-card',
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        isSynced: true,
      ),
    ]);
  }
}

