import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'package:app/main.dart';
import 'package:app/src/data/offline_store.dart';
import 'package:app/src/models/expense_model.dart';
import 'package:app/src/models/todo_model.dart';
import 'package:app/src/models/vault_model.dart';
import 'package:app/src/navigation/minimal_morphing_bottom_bar.dart';
import 'package:app/src/screens/auth/components/pin_input_boxes.dart';
import 'package:app/src/screens/privacy_policy_screen.dart';
import 'package:app/src/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level app destinations with matching Lucide icons.
enum AppTab {
  expenses(label: 'Expenses', icon: FLucideIcons.wallet),
  todos(label: 'Todos', icon: FLucideIcons.listTodo),
  vault(label: 'Vault', icon: FLucideIcons.vault),
  profile(label: 'Profile', icon: FLucideIcons.circleUser);

  const AppTab({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

/// Root application shell with balanced, comfortable typography and component sizes.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [0];

  static const String _keySkipExitDialog = 'skip_exit_confirmation';
  static bool _sessionSkipExit = false;

  void _onSelectTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _tabHistory.remove(index);
      _tabHistory.add(index);
      _currentIndex = index;
    });
  }

  Future<void> _handleBackAction() async {
    if (_tabHistory.length > 1) {
      HapticFeedback.lightImpact();
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = _tabHistory.last;
      });
      return;
    }

    // At root screen (Expenses) with no previous back history
    final shouldExit = await _showExitConfirmationDialog();
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    if (_sessionSkipExit) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final skip = prefs.getBool(_keySkipExitDialog) ?? false;
      if (skip) return true;
    } catch (_) {}

    if (!mounted) return false;

    bool dontAskAgain = false;
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: theme.colors.destructive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(FLucideIcons.logOut, color: theme.colors.destructive, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Exit App?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you sure you want to close SecureVault?',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setDialogState(() => dontAskAgain = !dontAskAgain),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: dontAskAgain,
                            activeColor: MyApp.primaryGreen,
                            checkColor: MyApp.primaryGreenForeground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) => setDialogState(() => dontAskAgain = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Don't ask again",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colors.primary,
                    foregroundColor: theme.colors.primaryForeground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldExit == true && dontAskAgain) {
      _sessionSkipExit = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keySkipExitDialog, true);
      } catch (_) {}
    }

    return shouldExit ?? false;
  }

  void _showQuickNavigationSheet(BuildContext context) {
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: theme.colors.mutedForeground.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: theme.colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(FLucideIcons.compass, size: 18, color: theme.colors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Quick Navigation',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: theme.colors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < AppTab.values.length; i++) ...[
                    Builder(builder: (context) {
                      final tab = AppTab.values[i];
                      final isSelected = _currentIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _onSelectTab(i);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colors.primary.withValues(alpha: 0.12)
                                  : theme.colors.secondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colors.primary.withValues(alpha: 0.5)
                                    : theme.colors.border.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 18,
                                  color: isSelected ? theme.colors.primary : theme.colors.foreground,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tab.label,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? theme.colors.primary : theme.colors.foreground,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: theme.colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  Icon(
                                    FLucideIcons.chevronRight,
                                    size: 16,
                                    color: theme.colors.mutedForeground,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = AppTab.values[_currentIndex];
    final store = OfflineStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = context.theme;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;
            await _handleBackAction();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: FScaffold(
              scaffoldStyle: .delta(
                footerDecoration: .value(const BoxDecoration()),
              ),
            header: FHeader(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeTab == AppTab.expenses) ...[
                    // First screen header: App Logo Emblem only
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: theme.colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: theme.colors.primary.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            FLucideIcons.shieldCheck,
                            size: 17,
                            color: theme.colors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    // Other screens header: Smooth, well-designed back arrow
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleBackAction,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colors.secondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colors.border.withValues(alpha: 0.7),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            FLucideIcons.arrowLeft,
                            size: 17,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    activeTab.label,
                    style: TextStyle(
                      fontSize: 19.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: theme.colors.foreground,
                    ),
                  ),
                ],
              ),
              suffixes: [
                if (activeTab == AppTab.expenses) ...[
                  FBadge(
                    variant: FBadgeVariant.secondary,
                    child: const Text('INR (₹)'),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showQuickNavigationSheet(context);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colors.secondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colors.border.withValues(alpha: 0.7),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          FLucideIcons.compass,
                          size: 17,
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                ],
                if (activeTab == AppTab.todos)
                  FBadge(
                    variant: FBadgeVariant.primary,
                    child: Text('${store.pendingTodosCount} Pending'),
                  ),
                if (activeTab == AppTab.vault)
                  FBadge(
                    variant: FBadgeVariant.outline,
                    child: const Text('AES-256'),
                  ),
              ],
            ),
            footer: MinimalMorphingBottomBar(
              currentIndex: _currentIndex,
              onTap: _onSelectTab,
              items: [
                for (final tab in AppTab.values)
                  MinimalBarItem(
                    label: tab.label,
                    icon: tab.icon,
                  ),
              ],
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                ExpensesView(),
                TodosView(),
                VaultView(),
                ProfileView(),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}

// =============================================================================
// BALANCED EXPENSES VIEW
// =============================================================================
class ExpensesView extends StatelessWidget {
  const ExpensesView({super.key});

  void _showAddExpenseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Food & Drinks';
    String selectedType = 'Expense';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final theme = dialogCtx.theme;
        return AlertDialog(
          backgroundColor: theme.colors.card,
          title: Text('Add Transaction (₹)', style: theme.cardStyle.titleTextStyle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Description (e.g. Groceries, Coffee)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'Food & Drinks', child: Text('Food & Drinks')),
                    DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                    DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                    DropdownMenuItem(value: 'Salary', child: Text('Salary / Income')),
                    DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                  ],
                  onChanged: (val) => selectedCategory = val ?? selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'Income', child: Text('Income')),
                    DropdownMenuItem(value: 'Borrowed', child: Text('Borrowed')),
                  ],
                  onChanged: (val) => selectedType = val ?? selectedType,
                  decoration: const InputDecoration(labelText: 'Transaction Type'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (title.isNotEmpty && amount > 0) {
                  OfflineStore.instance.addExpense(
                    title: title,
                    category: selectedCategory,
                    amount: amount,
                    type: selectedType,
                  );
                }
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Add Transaction'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final store = OfflineStore.instance;

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        // Main Balance Card
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Balance (Monthly)',
                      style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 12),
                    ),
                    FBadge(
                      variant: FBadgeVariant.secondary,
                      child: const Text('+8.4% vs last month'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  OfflineStore.formatRupees(store.netBalance),
                  style: theme.typography.display.xl.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricSubBlock(
                        label: 'Total Income',
                        value: OfflineStore.formatRupees(store.totalIncome),
                        isPositive: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricSubBlock(
                        label: 'Total Spent',
                        value: OfflineStore.formatRupees(store.totalExpenses),
                        isPositive: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FButton(
                        size: FButtonSizeVariant.sm,
                        onPress: () => _showAddExpenseDialog(context),
                        child: const Text('+ Add Expense'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FButton(
                      variant: FButtonVariant.outline,
                      size: FButtonSizeVariant.sm,
                      onPress: () {},
                      child: const Text('Analytics'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Recent Transactions (₹)',
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in store.expenses) ...[
          _ExpenseTile(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MetricSubBlock extends StatelessWidget {
  const _MetricSubBlock({
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final String label;
  final String value;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colors.secondary,
        borderRadius: theme.style.borderRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: isPositive ? theme.colors.primary : theme.colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.item});

  final ExpenseItem item;

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food & drinks':
        return FLucideIcons.coffee;
      case 'groceries':
        return FLucideIcons.shoppingCart;
      case 'utilities':
        return FLucideIcons.zap;
      case 'housing':
        return FLucideIcons.house;
      case 'salary':
      case 'client work':
        return FLucideIcons.badgeIndianRupee;
      default:
        return FLucideIcons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colors.secondary,
                borderRadius: theme.style.borderRadius.md,
              ),
              child: Icon(
                _iconForCategory(item.category),
                size: 18,
                color: theme.colors.secondaryForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category,
                    style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Text(
              item.isExpense
                  ? '-${OfflineStore.formatRupees(item.amount)}'
                  : item.isIncome
                      ? '+${OfflineStore.formatRupees(item.amount)}'
                      : OfflineStore.formatRupees(item.amount),
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: item.isIncome ? theme.colors.primary : theme.colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BALANCED TODOS VIEW
// =============================================================================
class TodosView extends StatelessWidget {
  const TodosView({super.key});

  void _showAddTodoDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dueDateController = TextEditingController(text: 'Due Tomorrow');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final theme = dialogCtx.theme;
        return AlertDialog(
          backgroundColor: theme.colors.card,
          title: Text('New Todo Reminder', style: theme.cardStyle.titleTextStyle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(labelText: 'Due Date'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (Optional ₹)', prefixText: '₹ '),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final dueDate = dueDateController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                if (title.isNotEmpty) {
                  OfflineStore.instance.addTodo(
                    title: title,
                    dueDate: dueDate.isNotEmpty ? dueDate : 'Upcoming',
                    amount: amount,
                  );
                }
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Save Todo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final store = OfflineStore.instance;

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Financial Tasks & Bills', style: theme.cardStyle.titleTextStyle.copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(
                        'Smart checklist for credit card payments and tax deadlines.',
                        style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                FButton(
                  variant: FButtonVariant.primary,
                  size: FButtonSizeVariant.sm,
                  onPress: () => _showAddTodoDialog(context),
                  child: const Text('+ New Task'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final todo in store.todos) ...[
          _TodoCard(todo: todo),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.todo});

  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => OfflineStore.instance.toggleTodo(todo.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                todo.isCompleted ? FLucideIcons.checkCheck : FLucideIcons.circle,
                size: 18,
                color: todo.isCompleted ? theme.colors.primary : theme.colors.mutedForeground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                        color: todo.isCompleted ? theme.colors.mutedForeground : theme.colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(todo.dueDate, style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5)),
                        if (todo.amount != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${OfflineStore.formatRupees(todo.amount!)}',
                            style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              FBadge(
                variant: todo.isCompleted
                    ? FBadgeVariant.outline
                    : todo.tag == 'High Priority'
                        ? FBadgeVariant.destructive
                        : FBadgeVariant.secondary,
                child: Text(todo.tag),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BALANCED VAULT VIEW
// =============================================================================
class VaultView extends StatelessWidget {
  const VaultView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final store = OfflineStore.instance;

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colors.primary.withValues(alpha: 0.12),
                    borderRadius: theme.style.borderRadius.md,
                  ),
                  child: Icon(
                    FLucideIcons.shieldCheck,
                    size: 24,
                    color: theme.colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Secure Vault Active', style: theme.cardStyle.titleTextStyle.copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(
                        'Client-side AES-256 encrypted credential records.',
                        style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Credentials & Financial Logins',
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in store.vaultItems) ...[
          _VaultItemCard(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _VaultItemCard extends StatefulWidget {
  const _VaultItemCard({required this.item});

  final VaultItem item;

  @override
  State<_VaultItemCard> createState() => _VaultItemCardState();
}

class _VaultItemCardState extends State<_VaultItemCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colors.secondary,
                borderRadius: theme.style.borderRadius.md,
              ),
              child: Icon(FLucideIcons.keyRound, size: 18, color: theme.colors.secondaryForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.item.username} • ${_revealed ? "super_sec#2026" : widget.item.password}',
                    style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _revealed ? FLucideIcons.eyeOff : FLucideIcons.eye,
                size: 18,
                color: theme.colors.mutedForeground,
              ),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ENHANCED PROFILE VIEW
// =============================================================================
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _dailyReminder = true;
  bool _budgetAlerts = true;
  bool _billReminders = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _dailyReminder = prefs.getBool('pref_notif_daily') ?? true;
          _budgetAlerts = prefs.getBool('pref_notif_budget') ?? true;
          _billReminders = prefs.getBool('pref_notif_bills') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveNotificationPref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _showFeedbackSnackBar(BuildContext context, String message) {
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final bottomMargin = 66.0 + (bottomInset > 0 ? bottomInset : 10.0);
        final theme = context.theme;

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(FLucideIcons.checkCheck, size: 16, color: theme.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
            backgroundColor: theme.colors.card,
            elevation: 8,
            duration: const Duration(milliseconds: 2400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: theme.colors.border,
                width: 1.0,
              ),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _showEditProfileDrawer(BuildContext context) {
    final parentContext = context;
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;

    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    String rawMobile = user?.mobile ?? '';
    if (rawMobile.startsWith('+91')) {
      rawMobile = rawMobile.replaceFirst('+91', '').trim();
    }
    final mobileController = TextEditingController(text: rawMobile);
    String selectedGender = user?.gender ?? 'Male';
    String? localError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            final fieldBg = isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC);
            final cardBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);

            return Container(
              decoration: BoxDecoration(
                color: theme.colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Smooth Drag Handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: theme.colors.mutedForeground.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Smooth Edit Profile Emblem
                        Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colors.primary.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              FLucideIcons.userPen,
                              size: 24,
                              color: theme.colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          'Edit Profile Details',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: theme.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update your personal information & contact credentials',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Error Banner
                        if (localError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colors.destructive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colors.destructive.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(FLucideIcons.alertCircle, size: 16, color: theme.colors.destructive),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    localError!,
                                    style: TextStyle(fontSize: 11.5, color: theme.colors.destructive),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Input 1: Full Name
                        Text(
                          'Full Name',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: nameController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: Icon(FLucideIcons.user, size: 16, color: theme.colors.mutedForeground),
                              hintText: 'Enter your name',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Input 2: Email Address (Read-only)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Email Address',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FLucideIcons.lock, size: 11, color: theme.colors.mutedForeground),
                                const SizedBox(width: 3),
                                Text(
                                  'Read-only',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: theme.colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colors.muted.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: emailController,
                            readOnly: true,
                            style: TextStyle(
                              color: theme.colors.foreground.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: Icon(FLucideIcons.mail, size: 16, color: theme.colors.mutedForeground),
                              suffixIcon: Icon(FLucideIcons.lock, size: 14, color: theme.colors.mutedForeground),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Input 3: Mobile Number with non-editable +91 prefix (Read-only)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mobile Number',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FLucideIcons.lock, size: 11, color: theme.colors.mutedForeground),
                                const SizedBox(width: 3),
                                Text(
                                  'Read-only',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: theme.colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colors.muted.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              // Non-editable +91 prefix box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.colors.secondary.withValues(alpha: 0.5),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                  border: Border(
                                    right: BorderSide(color: cardBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🇮🇳', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        color: theme.colors.foreground.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: mobileController,
                                  readOnly: true,
                                  style: TextStyle(
                                    color: theme.colors.foreground.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixIcon: Icon(FLucideIcons.lock, size: 14, color: theme.colors.mutedForeground),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Input 4: Gender Selector
                        Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Male', 'Female', 'Other', 'Prefer not to say'].map((g) {
                            final isSelected = selectedGender.toLowerCase() == g.toLowerCase();
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedGender = g),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colors.primary.withValues(alpha: 0.15)
                                      : theme.colors.secondary,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? theme.colors.primary : cardBorder,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? theme.colors.primary : theme.colors.foreground,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),

                        // Save Button
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colors.primary,
                              foregroundColor: theme.colors.primaryForeground,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                setModalState(() => localError = 'Please enter your full name');
                                return;
                              }

                              // Preserve existing email and phone credentials (read-only)
                              final userEmail = user?.email ?? emailController.text.trim();
                              final userMobile = user?.mobile ?? '+91${mobileController.text.trim()}';

                              try {
                                await AuthService.instance.updateProfile(
                                  name: name,
                                  email: userEmail,
                                  mobile: userMobile,
                                  gender: selectedGender,
                                );
                                HapticFeedback.lightImpact();
                              } catch (e) {
                                setModalState(() => localError = e.toString().replaceFirst('Exception: ', ''));
                                return;
                              }

                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                              if (parentContext.mounted) {
                                _showFeedbackSnackBar(parentContext, 'Profile updated successfully!');
                              }
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FLucideIcons.check, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Save Profile Changes',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInviteFriendDialog(BuildContext context) {
    final theme = context.theme;
    const referralCode = 'VAULT-MINT-77';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: theme.colors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(FLucideIcons.gift, color: theme.colors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Invite Friends & Family', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share your referral code to invite your friends and family to easily track expenses and manage records together.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colors.secondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR REFERRAL CODE', style: TextStyle(fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          referralCode,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(FLucideIcons.copy, size: 18, color: theme.colors.primary),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: referralCode));
                        HapticFeedback.lightImpact();
                        Navigator.of(dialogCtx).pop();
                        _showFeedbackSnackBar(context, 'Referral code copied to clipboard!');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Notice banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colors.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(FLucideIcons.info, size: 15, color: theme.colors.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: This section is currently for app invitations only. Referral tracking and rewards are not active at this time.',
                        style: TextStyle(fontSize: 11, color: theme.colors.mutedForeground, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(FLucideIcons.share2, size: 16),
              label: const Text('Share Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colors.primary,
                foregroundColor: theme.colors.primaryForeground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'Join me on SecureVault with code: $referralCode'));
                HapticFeedback.lightImpact();
                Navigator.of(dialogCtx).pop();
                _showFeedbackSnackBar(context, 'Invite link copied to clipboard!');
              },
            ),
          ],
        );
      },
    );
  }

  void _showUpdatePinDrawer(BuildContext context) {
    final parentContext = context;
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? localError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            return Container(
              decoration: BoxDecoration(
                color: theme.colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Smooth Drag Handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: theme.colors.mutedForeground.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Smooth App Logo Emblem
                        Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: theme.colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colors.primary.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/icons/app_icon.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  FLucideIcons.lock,
                                  size: 22,
                                  color: theme.colors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Drawer Title & Subtitle
                        Text(
                          'Update Security PIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: theme.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter your current PIN and choose a new 6-digit PIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Error Banner
                        if (localError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colors.destructive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colors.destructive.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(FLucideIcons.alertCircle, size: 16, color: theme.colors.destructive),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    localError!,
                                    style: TextStyle(fontSize: 11.5, color: theme.colors.destructive),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Input Box 1: Current 6-Digit PIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current 6-Digit PIN',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() => obscureCurrent = !obscureCurrent),
                              child: Text(
                                obscureCurrent ? 'Show' : 'Hide',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PinInputBoxes(
                          controller: currentPinController,
                          obscureText: obscureCurrent,
                        ),
                        const SizedBox(height: 14),

                        // Input Box 2: New 6-Digit PIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'New 6-Digit PIN',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() => obscureNew = !obscureNew),
                              child: Text(
                                obscureNew ? 'Show' : 'Hide',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PinInputBoxes(
                          controller: newPinController,
                          obscureText: obscureNew,
                        ),
                        const SizedBox(height: 14),

                        // Input Box 3: Confirm New PIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Confirm New PIN',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() => obscureConfirm = !obscureConfirm),
                              child: Text(
                                obscureConfirm ? 'Show' : 'Hide',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PinInputBoxes(
                          controller: confirmPinController,
                          obscureText: obscureConfirm,
                        ),
                        const SizedBox(height: 22),

                        // Action Button
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colors.primary,
                              foregroundColor: theme.colors.primaryForeground,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                            onPressed: () async {
                              final oldPin = currentPinController.text.trim();
                              final newPin = newPinController.text.trim();
                              final confirm = confirmPinController.text.trim();

                              if (oldPin.length != 6) {
                                setModalState(() => localError = 'Current PIN must be 6 digits');
                                return;
                              }
                              if (newPin.length != 6) {
                                setModalState(() => localError = 'New PIN must be exactly 6 digits');
                                return;
                              }
                              if (newPin != confirm) {
                                setModalState(() => localError = 'New PIN and confirmation do not match');
                                return;
                              }

                              try {
                                await AuthService.instance.updatePin(oldPin: oldPin, newPin: newPin);
                                HapticFeedback.lightImpact();
                              } catch (e) {
                                setModalState(() => localError = e.toString().replaceFirst('Exception: ', ''));
                                return;
                              }

                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                              if (parentContext.mounted) {
                                _showFeedbackSnackBar(parentContext, 'Security PIN successfully updated!');
                              }
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Save New PIN',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(FLucideIcons.arrowRight, size: 15),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExportDataDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = ctx.theme;
        return AlertDialog(
          backgroundColor: theme.colors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(FLucideIcons.fileSpreadsheet, size: 20),
              SizedBox(width: 10),
              Text('Export Financial Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Export all transactions, pending todos, and vault logs into a portable JSON/CSV file for Excel or backup.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colors.primary,
                foregroundColor: theme.colors.primaryForeground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                HapticFeedback.lightImpact();
                _showFeedbackSnackBar(context, 'Financial data exported to Downloads folder!');
              },
              child: const Text('Export CSV'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        final displayName = user?.name ?? 'Alex Morgan';
        final displayEmail = user?.email ?? 'alex.morgan@example.com';
        final displayMobile = user?.mobile ?? '+91 9876543210';
        final initials = displayName.trim().isNotEmpty
            ? displayName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
            : 'AM';

        return ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          children: [
            // User Profile Header Card with Quick Edit Action
            FCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colors.primary,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: theme.colors.primaryForeground,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.cardStyle.titleTextStyle.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            displayMobile,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colors.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (user?.gender != null && user!.gender!.isNotEmpty && user.gender != 'Not Specified') ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: theme.colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                user.gender!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showEditProfileDrawer(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: theme.colors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FLucideIcons.userPen, size: 12, color: theme.colors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Highlight Card: Invite Friends Option
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showInviteFriendDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colors.primary.withValues(alpha: 0.18),
                      theme.colors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colors.primary.withValues(alpha: 0.35),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FLucideIcons.gift,
                        size: 16,
                        color: theme.colors.primaryForeground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite Friends & Family',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Share code VAULT-MINT-77 with your friends & family',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(FLucideIcons.info, size: 11, color: theme.colors.mutedForeground),
                              const SizedBox(width: 4),
                              Text(
                                'Invitations only • No referral tracking active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(FLucideIcons.chevronRight, size: 16, color: theme.colors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Section: Personal Profile Details
            Text(
              'Account & Profile',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 5),

            _SettingsRow(
              icon: FLucideIcons.userPen,
              title: 'Edit Profile Information',
              subtitle: 'Update your name, email, mobile & gender',
              onTap: () => _showEditProfileDrawer(context),
            ),
            const SizedBox(height: 12),

            // Section: Security & Credentials
            Text(
              'Security & Credentials',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 5),

            // Update PIN Option
            _SettingsRow(
              icon: FLucideIcons.keyRound,
              title: 'Update Security PIN',
              subtitle: 'Change your 6-digit authentication PIN',
              onTap: () => _showUpdatePinDrawer(context),
            ),
            const SizedBox(height: 5),

            // Biometric Security Option
            _SettingsRow(
              icon: FLucideIcons.shieldCheck,
              title: 'Biometric Security',
              subtitle: 'Face ID & Fingerprint unlock enabled',
              value: 'Active',
            ),
            const SizedBox(height: 12),

            // Section: Notifications & Alerts
            Text(
              'Notifications & Alerts',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 5),

            _NotificationSwitchRow(
              icon: FLucideIcons.calendarClock,
              title: 'Daily Expense Reminder',
              subtitle: 'Reminder at 8:00 PM to log daily expenses',
              value: _dailyReminder,
              onChanged: (val) {
                setState(() => _dailyReminder = val);
                _saveNotificationPref('pref_notif_daily', val);
              },
            ),
            const SizedBox(height: 5),

            _NotificationSwitchRow(
              icon: FLucideIcons.pieChart,
              title: 'Budget & Spending Alerts',
              subtitle: 'Instant alert when category spending reaches 80%',
              value: _budgetAlerts,
              onChanged: (val) {
                setState(() => _budgetAlerts = val);
                _saveNotificationPref('pref_notif_budget', val);
              },
            ),
            const SizedBox(height: 5),

            _NotificationSwitchRow(
              icon: FLucideIcons.bellRing,
              title: 'Bills & Upcoming Deadlines',
              subtitle: 'Alerts for pending recurring bills and vault tasks',
              value: _billReminders,
              onChanged: (val) {
                setState(() => _billReminders = val);
                _saveNotificationPref('pref_notif_bills', val);
              },
            ),
            const SizedBox(height: 12),

            // Section: Data & Privacy Options
            Text(
              'Data & Privacy Options',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 5),

            // Privacy Policy & Data Protection Option
            _SettingsRow(
              icon: FLucideIcons.lockKeyhole,
              title: 'Privacy & Security Policy',
              subtitle: 'Zero-knowledge encryption & local privacy',
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 5),

            // Export Data Option
            _SettingsRow(
              icon: FLucideIcons.fileSpreadsheet,
              title: 'Export Financial Data',
              subtitle: 'Download transactions and vault backup as CSV',
              onTap: () => _showExportDataDialog(context),
            ),
            const SizedBox(height: 12),

            // Section: Appearance & Currency
            Text(
              'Preferences & Appearance',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 5),

            // Currency Configuration
            _SettingsRow(
              icon: FLucideIcons.badgeIndianRupee,
              title: 'Primary Currency',
              subtitle: 'Indian Rupee (INR)',
              value: '₹',
            ),
            const SizedBox(height: 5),

            // Theme Switcher Card
            FCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(FLucideIcons.palette, size: 16, color: theme.colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'App Theme',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: MyApp.themeModeNotifier,
                      builder: (context, currentMode, _) {
                        return Row(
                          children: [
                            Expanded(
                              child: FButton(
                                variant: currentMode == ThemeMode.light
                                    ? FButtonVariant.primary
                                    : FButtonVariant.outline,
                                size: FButtonSizeVariant.sm,
                                onPress: () => MyApp.themeModeNotifier.value = ThemeMode.light,
                                child: const Text('Light'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FButton(
                                variant: currentMode == ThemeMode.dark
                                    ? FButtonVariant.primary
                                    : FButtonVariant.outline,
                                size: FButtonSizeVariant.sm,
                                onPress: () => MyApp.themeModeNotifier.value = ThemeMode.dark,
                                child: const Text('Dark'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FButton(
                                variant: currentMode == ThemeMode.system
                                    ? FButtonVariant.primary
                                    : FButtonVariant.outline,
                                size: FButtonSizeVariant.sm,
                                onPress: () => MyApp.themeModeNotifier.value = ThemeMode.system,
                                child: const Text('System'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Section: Account Session & Sign Out
            Text(
              'Account Session',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 5),
            FCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.isOfflineOnly == true ? 'Local Secure Account' : 'Synced Online Account',
                            style: theme.typography.body.md.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            user?.isOfflineOnly == true
                                ? 'Ready to sync when connected'
                                : 'Connected to backend server',
                            style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AuthService.instance.logout();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colors.destructive,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colors.destructive.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FLucideIcons.logOut, size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationSwitchRow extends StatelessWidget {
  const _NotificationSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: theme.colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Material(
                type: MaterialType.transparency,
                child: Switch.adaptive(
                  value: value,
                  activeThumbColor: theme.colors.primary,
                  activeTrackColor: theme.colors.primary.withValues(alpha: 0.35),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: theme.colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colors.foreground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: theme.cardStyle.subtitleTextStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  FLucideIcons.chevronRight,
                  size: 16,
                  color: theme.colors.mutedForeground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
