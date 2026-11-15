import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'package:app/main.dart';
import 'package:app/src/data/offline_store.dart';
import 'package:app/src/models/expense_model.dart';
import 'package:app/src/models/todo_model.dart';
import 'package:app/src/models/vault_model.dart';
import 'package:app/src/navigation/minimal_morphing_bottom_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    final activeTab = AppTab.values[_currentIndex];
    final store = OfflineStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return FScaffold(
          scaffoldStyle: .delta(
            footerDecoration: .value(const BoxDecoration()),
          ),
          header: FHeader(
            title: Text(activeTab.label),
            suffixes: [
              if (activeTab == AppTab.expenses)
                FBadge(
                  variant: FBadgeVariant.secondary,
                  child: const Text('INR (₹)'),
                ),
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
            onTap: (index) => setState(() => _currentIndex = index),
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
              child: const Text('Add (Offline)'),
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
      padding: const EdgeInsets.only(top: 8, bottom: 84),
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
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
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
                    '${item.category} • ${item.isSynced ? "Synced" : "Offline"}',
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
      padding: const EdgeInsets.only(top: 8, bottom: 84),
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
                        'Offline checklist for credit card payments and tax deadlines.',
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
      child: InkWell(
        onTap: () => OfflineStore.instance.toggleTodo(todo.id),
        borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.only(top: 8, bottom: 84),
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
// BALANCED PROFILE VIEW
// =============================================================================
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 84),
      children: [
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colors.primary,
                  child: Text(
                    'AM',
                    style: TextStyle(
                      color: theme.colors.primaryForeground,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Alex Morgan', style: theme.cardStyle.titleTextStyle.copyWith(fontSize: 14)),
                          const SizedBox(width: 8),
                          FBadge(variant: FBadgeVariant.primary, child: const Text('PRO')),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('alex.morgan@example.com', style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Currency & Storage Configuration',
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: FLucideIcons.badgeIndianRupee,
          title: 'Primary Currency',
          value: 'Indian Rupee (INR - ₹)',
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: FLucideIcons.database,
          title: 'Architecture Mode',
          value: 'Offline-First (0ms Local SSOT)',
        ),
        const SizedBox(height: 14),
        Text(
          'App Appearance',
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ValueListenableBuilder<ThemeMode>(
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
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Security',
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: FLucideIcons.shieldCheck,
          title: 'Biometric Security',
          value: 'Enabled (Face ID / PIN)',
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colors.mutedForeground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: theme.colors.foreground,
                ),
              ),
            ),
            Text(value, style: theme.cardStyle.subtitleTextStyle.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
