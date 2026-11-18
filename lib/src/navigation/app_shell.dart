import 'dart:math';

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

/// Tactile micro-interaction wrapper providing subtle scale bounce feedback on press.
class AnimatedPressable extends StatefulWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
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
                    child: const Text('Secure Vault'),
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

void showAppSnackBar(BuildContext context, String message) {
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
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          if (title.isNotEmpty && amount > 0) {
                            setDialogState(() => isSubmitting = true);
                            HapticFeedback.mediumImpact();
                            await Future.delayed(const Duration(milliseconds: 220));
                            OfflineStore.instance.addExpense(
                              title: title,
                              category: selectedCategory,
                              amount: amount,
                              type: selectedType,
                            );
                          }
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                        },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isSubmitting
                        ? SizedBox(
                            key: const ValueKey('expense_spinner'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.colors.primaryForeground,
                            ),
                          )
                        : const Text(
                            'Add Transaction',
                            key: ValueKey('expense_text'),
                          ),
                  ),
                ),
              ],
            );
          },
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
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final dueDate = dueDateController.text.trim();
                          final amount = double.tryParse(amountController.text.trim());
                          if (title.isNotEmpty) {
                            setDialogState(() => isSubmitting = true);
                            HapticFeedback.mediumImpact();
                            await Future.delayed(const Duration(milliseconds: 220));
                            OfflineStore.instance.addTodo(
                              title: title,
                              dueDate: dueDate.isNotEmpty ? dueDate : 'Upcoming',
                              amount: amount,
                            );
                          }
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                        },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isSubmitting
                        ? SizedBox(
                            key: const ValueKey('todo_spinner'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.colors.primaryForeground,
                            ),
                          )
                        : const Text(
                            'Save Todo',
                            key: ValueKey('todo_text'),
                          ),
                  ),
                ),
              ],
            );
          },
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
// BALANCED VAULT VIEW (SecureVault with Themed Categories & Credentials)
// =============================================================================
/// Maps category names and icon keys to clean, professional Lucide icons.
IconData getVaultCategoryIcon(String? categoryName, [String? iconKey]) {
  final cleanKey = (iconKey ?? '').toLowerCase().trim();
  switch (cleanKey) {
    case 'briefcase':
    case 'work':
      return FLucideIcons.briefcase;
    case 'credit-card':
    case 'finance':
    case 'financial':
      return FLucideIcons.creditCard;
    case 'user':
    case 'individual':
    case 'personal':
      return FLucideIcons.user;
    case 'mail':
    case 'email':
      return FLucideIcons.mail;
    case 'share-2':
    case 'social':
      return FLucideIcons.share2;
    case 'shopping-bag':
    case 'shopping':
      return FLucideIcons.shoppingBag;
    case 'tv':
    case 'media':
    case 'streaming':
      return FLucideIcons.tv;
    case 'gamepad-2':
    case 'gaming':
      return FLucideIcons.gamepad2;
    case 'shield-check':
    case 'security':
      return FLucideIcons.shieldCheck;
    case 'globe':
    case 'web':
    case 'website':
      return FLucideIcons.globe;
    case 'key-round':
    case 'keys':
      return FLucideIcons.keyRound;
    case 'smartphone':
    case 'apps':
      return FLucideIcons.smartphone;
    case 'code':
    case 'dev':
      return FLucideIcons.code;
    case 'folder':
      return FLucideIcons.folder;
  }

  final name = (categoryName ?? '').toLowerCase().trim();
  if (name.contains('all')) return FLucideIcons.layoutGrid;
  if (name.contains('work') || name.contains('office') || name.contains('job')) {
    return FLucideIcons.briefcase;
  }
  if (name.contains('finan') ||
      name.contains('bank') ||
      name.contains('card') ||
      name.contains('money') ||
      name.contains('pay') ||
      name.contains('invest')) {
    return FLucideIcons.creditCard;
  }
  if (name.contains('indiv') ||
      name.contains('person') ||
      name.contains('user') ||
      name.contains('profile')) {
    return FLucideIcons.user;
  }
  if (name.contains('mail') || name.contains('email') || name.contains('gmail')) {
    return FLucideIcons.mail;
  }
  if (name.contains('social') ||
      name.contains('media') ||
      name.contains('chat') ||
      name.contains('network')) {
    return FLucideIcons.share2;
  }
  if (name.contains('stream') ||
      name.contains('movie') ||
      name.contains('tv') ||
      name.contains('video') ||
      name.contains('netflix')) {
    return FLucideIcons.tv;
  }
  if (name.contains('game') || name.contains('gaming') || name.contains('play')) {
    return FLucideIcons.gamepad2;
  }
  if (name.contains('shop') || name.contains('store') || name.contains('buy') || name.contains('cart')) {
    return FLucideIcons.shoppingBag;
  }
  if (name.contains('secur') || name.contains('pass') || name.contains('protect') || name.contains('safe')) {
    return FLucideIcons.shieldCheck;
  }
  if (name.contains('code') || name.contains('dev') || name.contains('git') || name.contains('tech')) {
    return FLucideIcons.code;
  }
  if (name.contains('web') || name.contains('site') || name.contains('online')) {
    return FLucideIcons.globe;
  }
  return FLucideIcons.folder;
}

class VaultView extends StatefulWidget {
  const VaultView({super.key});

  @override
  State<VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends State<VaultView> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OfflineStore.instance.syncVaultWithLiveDb(silent: true);
    });
  }

  String _generateStrongPassword() {
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%&*';
    final rnd = Random.secure();
    return List.generate(14, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _showAddCategoryDialog(BuildContext context) {
    final parentContext = context;
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    String selectedIconKey = 'folder';
    String? localError;
    bool isSubmitting = false;

    const availableIcons = <Map<String, dynamic>>[
      {'key': 'folder', 'icon': FLucideIcons.folder, 'name': 'Folder'},
      {'key': 'briefcase', 'icon': FLucideIcons.briefcase, 'name': 'Work'},
      {'key': 'user', 'icon': FLucideIcons.user, 'name': 'Personal'},
      {'key': 'credit-card', 'icon': FLucideIcons.creditCard, 'name': 'Finance'},
      {'key': 'mail', 'icon': FLucideIcons.mail, 'name': 'Mail'},
      {'key': 'share-2', 'icon': FLucideIcons.share2, 'name': 'Social'},
      {'key': 'shopping-bag', 'icon': FLucideIcons.shoppingBag, 'name': 'Shopping'},
      {'key': 'tv', 'icon': FLucideIcons.tv, 'name': 'Media'},
      {'key': 'gamepad-2', 'icon': FLucideIcons.gamepad2, 'name': 'Gaming'},
      {'key': 'shield-check', 'icon': FLucideIcons.shieldCheck, 'name': 'Security'},
      {'key': 'globe', 'icon': FLucideIcons.globe, 'name': 'Web'},
      {'key': 'key-round', 'icon': FLucideIcons.keyRound, 'name': 'Keys'},
      {'key': 'smartphone', 'icon': FLucideIcons.smartphone, 'name': 'Mobile'},
      {'key': 'code', 'icon': FLucideIcons.code, 'name': 'Dev'},
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            final fieldBg = isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC);
            final cardBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);

            return Container(
              decoration: BoxDecoration(
                color: theme.colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: cardBorder,
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

                        // Header with Folder Emblem
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colors.primary.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  getVaultCategoryIcon(null, selectedIconKey),
                                  size: 22,
                                  color: theme.colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add New Category',
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: theme.colors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Create a custom folder for your passwords',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                icon: Icon(FLucideIcons.x, size: 17, color: theme.colors.mutedForeground),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Error banner
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

                        // Category Name Input
                        Text(
                          'Category Name',
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
                              prefixIcon: Icon(FLucideIcons.folder, size: 16, color: theme.colors.mutedForeground),
                              hintText: 'e.g., Gaming, Streaming, Work',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Choose Category Icon Picker
                        Text(
                          'Choose Category Icon',
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
                          children: availableIcons.map((item) {
                            final key = item['key'] as String;
                            final icon = item['icon'] as IconData;
                            final isChosen = selectedIconKey == key;
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedIconKey = key),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isChosen
                                      ? theme.colors.primary.withValues(alpha: 0.18)
                                      : theme.colors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isChosen ? theme.colors.primary : cardBorder,
                                    width: isChosen ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: isChosen ? theme.colors.primary : theme.colors.foreground,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cardBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                onPressed: isSubmitting ? null : () => Navigator.of(sheetCtx).pop(),
                                child: Text('Cancel', style: TextStyle(color: theme.colors.foreground)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colors.primary,
                                  foregroundColor: theme.colors.primaryForeground,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 0,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final name = nameController.text.trim();
                                        if (name.isEmpty) {
                                          setModalState(() => localError = 'Please enter a category name');
                                          return;
                                        }
                                        setModalState(() {
                                          localError = null;
                                          isSubmitting = true;
                                        });
                                        HapticFeedback.mediumImpact();
                                        await Future.delayed(const Duration(milliseconds: 260));
                                        OfflineStore.instance.addVaultCategory(name: name, emoji: selectedIconKey);
                                        if (sheetCtx.mounted) {
                                          Navigator.of(sheetCtx).pop();
                                        }
                                        if (parentContext.mounted) {
                                          showAppSnackBar(parentContext, 'Category "$name" created!');
                                        }
                                      },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: isSubmitting
                                      ? SizedBox(
                                          key: const ValueKey('category_spinner'),
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: theme.colors.primaryForeground,
                                          ),
                                        )
                                      : const Row(
                                          key: ValueKey('category_content'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(FLucideIcons.plus, size: 15),
                                            SizedBox(width: 6),
                                            Text(
                                              'Create Category',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  void _showAddPasswordDrawer(BuildContext context) {
    final parentContext = context;
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = OfflineStore.instance;

    final titleController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final websiteController = TextEditingController();
    final notesController = TextEditingController();

    String selectedCategory = _selectedCategory != 'All'
        ? _selectedCategory
        : (store.vaultCategories.isNotEmpty ? store.vaultCategories.first.name : 'Work');

    bool obscurePassword = true;
    String? localError;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            final fieldBg = isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC);
            final cardBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);

            return Container(
              decoration: BoxDecoration(
                color: theme.colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: cardBorder,
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
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.colors.mutedForeground.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add New Password',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: theme.colors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Secure your digital life',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                padding: EdgeInsets.zero,
                                icon: Icon(FLucideIcons.x, size: 18, color: theme.colors.mutedForeground),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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

                        // Title Input
                        Row(
                          children: [
                            Icon(FLucideIcons.tag, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Title',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: titleController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g., Facebook, Gmail, Netflix',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Username / Email Input
                        Row(
                          children: [
                            Icon(FLucideIcons.user, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Username / Email',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: usernameController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'your.email@example.com',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Input with Generator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(FLucideIcons.lock, size: 14, color: theme.colors.mutedForeground),
                                const SizedBox(width: 6),
                                Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colors.foreground,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                final gen = _generateStrongPassword();
                                setModalState(() {
                                  passwordController.text = gen;
                                  obscurePassword = false;
                                });
                                HapticFeedback.lightImpact();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(FLucideIcons.sparkles, size: 12, color: theme.colors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Generate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: passwordController,
                                  obscureText: obscurePassword,
                                  style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Enter your password',
                                    hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  obscurePassword ? FLucideIcons.eyeOff : FLucideIcons.eye,
                                  size: 16,
                                  color: theme.colors.mutedForeground,
                                ),
                                onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Select Category
                        Row(
                          children: [
                            Icon(FLucideIcons.folder, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Select Category',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: store.vaultCategories.any((c) => c.name == selectedCategory)
                                  ? selectedCategory
                                  : (store.vaultCategories.isNotEmpty ? store.vaultCategories.first.name : null),
                              isExpanded: true,
                              icon: Icon(FLucideIcons.chevronDown, size: 16, color: theme.colors.mutedForeground),
                              dropdownColor: theme.colors.card,
                              items: store.vaultCategories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.name,
                                  child: Row(
                                    children: [
                                      Icon(getVaultCategoryIcon(c.name, c.emoji), size: 15, color: theme.colors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.name,
                                        style: TextStyle(
                                          color: theme.colors.foreground,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedCategory = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Website (optional)
                        Row(
                          children: [
                            Icon(FLucideIcons.globe, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Website (optional)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: websiteController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'https://example.com',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes (optional)
                        Row(
                          children: [
                            Icon(FLucideIcons.notepadText, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Notes (optional)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: notesController,
                            maxLines: 3,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 13.5),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Any additional notes...',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Action Buttons (Cancel & Save Password)
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cardBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                child: Text('Cancel', style: TextStyle(color: theme.colors.foreground)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colors.primary,
                                  foregroundColor: theme.colors.primaryForeground,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 0,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final title = titleController.text.trim();
                                        final username = usernameController.text.trim();
                                        final password = passwordController.text.trim();
                                        final website = websiteController.text.trim();
                                        final notes = notesController.text.trim();

                                        if (title.isEmpty) {
                                          setModalState(() => localError = 'Please enter a title (e.g. Facebook)');
                                          return;
                                        }
                                        if (username.isEmpty) {
                                          setModalState(() => localError = 'Please enter username or email');
                                          return;
                                        }
                                        if (password.isEmpty) {
                                          setModalState(() => localError = 'Please enter a password');
                                          return;
                                        }

                                        final cat = store.vaultCategories.firstWhere(
                                          (c) => c.name.toLowerCase() == selectedCategory.toLowerCase(),
                                          orElse: () => const VaultCategory(id: 'work', name: 'Work', emoji: 'folder'),
                                        );

                                        setModalState(() {
                                          localError = null;
                                          isSubmitting = true;
                                        });
                                        HapticFeedback.mediumImpact();
                                        await Future.delayed(const Duration(milliseconds: 260));

                                        store.addVaultItem(
                                          title: title,
                                          username: username,
                                          password: password,
                                          group: cat.name,
                                          website: website.isNotEmpty ? website : null,
                                          notes: notes.isNotEmpty ? notes : null,
                                          iconEmoji: cat.emoji,
                                        );

                                        if (sheetCtx.mounted) {
                                          Navigator.of(sheetCtx).pop();
                                        }
                                        if (parentContext.mounted) {
                                          showAppSnackBar(parentContext, 'Password for "$title" saved to vault!');
                                        }
                                      },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: isSubmitting
                                      ? SizedBox(
                                          key: const ValueKey('add_pw_spinner'),
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: theme.colors.primaryForeground,
                                          ),
                                        )
                                      : Row(
                                          key: const ValueKey('add_pw_content'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(FLucideIcons.check, size: 16, color: theme.colors.primaryForeground),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Save Password',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: theme.colors.primaryForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
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

  void _showEditPasswordDrawer(BuildContext context, VaultItem item) {
    final parentContext = context;
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = OfflineStore.instance;

    final titleController = TextEditingController(text: item.title);
    final usernameController = TextEditingController(text: item.username);
    final passwordController = TextEditingController(text: item.password);
    final websiteController = TextEditingController(text: item.website ?? '');
    final notesController = TextEditingController(text: item.notes ?? '');

    String selectedCategory = item.group;
    bool obscurePassword = true;
    String? localError;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            final fieldBg = isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC);
            final cardBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);

            return Container(
              decoration: BoxDecoration(
                color: theme.colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: cardBorder,
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
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.colors.mutedForeground.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Password',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: theme.colors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Update credential details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                padding: EdgeInsets.zero,
                                icon: Icon(FLucideIcons.x, size: 18, color: theme.colors.mutedForeground),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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

                        // Title Input
                        Row(
                          children: [
                            Icon(FLucideIcons.tag, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Title',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: titleController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g., Facebook, Gmail, Netflix',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Username / Email Input
                        Row(
                          children: [
                            Icon(FLucideIcons.user, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Username / Email',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: usernameController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'your.email@example.com',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Input with Generator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(FLucideIcons.lock, size: 14, color: theme.colors.mutedForeground),
                                const SizedBox(width: 6),
                                Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colors.foreground,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                final gen = _generateStrongPassword();
                                setModalState(() {
                                  passwordController.text = gen;
                                  obscurePassword = false;
                                });
                                HapticFeedback.lightImpact();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(FLucideIcons.sparkles, size: 12, color: theme.colors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Generate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: passwordController,
                                  obscureText: obscurePassword,
                                  style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Enter your password',
                                    hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  obscurePassword ? FLucideIcons.eyeOff : FLucideIcons.eye,
                                  size: 16,
                                  color: theme.colors.mutedForeground,
                                ),
                                onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Select Category
                        Row(
                          children: [
                            Icon(FLucideIcons.folder, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Select Category',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: store.vaultCategories.any((c) => c.name.toLowerCase() == selectedCategory.toLowerCase())
                                  ? store.vaultCategories.firstWhere((c) => c.name.toLowerCase() == selectedCategory.toLowerCase()).name
                                  : (store.vaultCategories.isNotEmpty ? store.vaultCategories.first.name : null),
                              isExpanded: true,
                              icon: Icon(FLucideIcons.chevronDown, size: 16, color: theme.colors.mutedForeground),
                              dropdownColor: theme.colors.card,
                              items: store.vaultCategories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.name,
                                  child: Row(
                                    children: [
                                      Icon(getVaultCategoryIcon(c.name, c.emoji), size: 15, color: theme.colors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.name,
                                        style: TextStyle(
                                          color: theme.colors.foreground,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedCategory = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Website (optional)
                        Row(
                          children: [
                            Icon(FLucideIcons.globe, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Website (optional)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: websiteController,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'https://example.com',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes (optional)
                        Row(
                          children: [
                            Icon(FLucideIcons.notepadText, size: 14, color: theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Text(
                              'Notes (optional)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: notesController,
                            maxLines: 3,
                            style: TextStyle(color: theme.colors.foreground, fontSize: 13.5),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Any additional notes...',
                              hintStyle: TextStyle(color: theme.colors.mutedForeground.withValues(alpha: 0.7), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Action Buttons (Cancel & Save Changes)
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cardBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                child: Text('Cancel', style: TextStyle(color: theme.colors.foreground)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colors.primary,
                                  foregroundColor: theme.colors.primaryForeground,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 0,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final title = titleController.text.trim();
                                        final username = usernameController.text.trim();
                                        final password = passwordController.text.trim();
                                        final website = websiteController.text.trim();
                                        final notes = notesController.text.trim();

                                        if (title.isEmpty) {
                                          setModalState(() => localError = 'Please enter a title (e.g. Facebook)');
                                          return;
                                        }
                                        if (username.isEmpty) {
                                          setModalState(() => localError = 'Please enter username or email');
                                          return;
                                        }
                                        if (password.isEmpty) {
                                          setModalState(() => localError = 'Please enter a password');
                                          return;
                                        }

                                        final cat = store.vaultCategories.firstWhere(
                                          (c) => c.name.toLowerCase() == selectedCategory.toLowerCase(),
                                          orElse: () => const VaultCategory(id: 'work', name: 'Work', emoji: 'folder'),
                                        );

                                        setModalState(() {
                                          localError = null;
                                          isSubmitting = true;
                                        });
                                        HapticFeedback.mediumImpact();
                                        await Future.delayed(const Duration(milliseconds: 260));

                                        store.updateVaultItem(
                                          id: item.id,
                                          title: title,
                                          username: username,
                                          password: password,
                                          group: cat.name,
                                          website: website.isNotEmpty ? website : null,
                                          notes: notes.isNotEmpty ? notes : null,
                                          iconEmoji: cat.emoji,
                                        );

                                        if (sheetCtx.mounted) {
                                          Navigator.of(sheetCtx).pop();
                                        }
                                        if (parentContext.mounted) {
                                          showAppSnackBar(parentContext, 'Password for "$title" updated!');
                                        }
                                      },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: isSubmitting
                                      ? SizedBox(
                                          key: const ValueKey('edit_pw_spinner'),
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: theme.colors.primaryForeground,
                                          ),
                                        )
                                      : Row(
                                          key: const ValueKey('edit_pw_content'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(FLucideIcons.check, size: 15, color: theme.colors.primaryForeground),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: theme.colors.primaryForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
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

  void _showItemDetailsSheet(BuildContext context, VaultItem item) {
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);
    final fieldBg = isDark ? const Color(0xFF14161B) : const Color(0xFFF8FAFC);
    bool isPasswordRevealed = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setDetailsState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;

            return Container(
              decoration: BoxDecoration(
                color: theme.colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: cardBorder,
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
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.colors.mutedForeground.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Header with App Icon, Title, Category Badge, and Close Button
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colors.primary.withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  getVaultCategoryIcon(item.displayGroup),
                                  size: 22,
                                  color: theme.colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                            color: theme.colors.foreground,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.displayGroup,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Stored securely on device',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                icon: Icon(FLucideIcons.x, size: 17, color: theme.colors.mutedForeground),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Username Detail Box
                        _DetailRowBox(
                          theme: theme,
                          fieldBg: fieldBg,
                          cardBorder: cardBorder,
                          icon: FLucideIcons.user,
                          label: 'Username / Email',
                          value: item.username,
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: item.username));
                            HapticFeedback.lightImpact();
                            showAppSnackBar(context, 'Username copied to clipboard!');
                          },
                        ),
                        const SizedBox(height: 10),

                        // Password Detail Box
                        _DetailRowBox(
                          theme: theme,
                          fieldBg: fieldBg,
                          cardBorder: cardBorder,
                          icon: FLucideIcons.lock,
                          label: 'Password',
                          value: isPasswordRevealed ? item.password : '••••••••••••',
                          trailingAction: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            icon: Icon(
                              isPasswordRevealed ? FLucideIcons.eyeOff : FLucideIcons.eye,
                              size: 16,
                              color: theme.colors.mutedForeground,
                            ),
                            onPressed: () => setDetailsState(() => isPasswordRevealed = !isPasswordRevealed),
                          ),
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: item.password));
                            HapticFeedback.lightImpact();
                            showAppSnackBar(context, 'Password copied to clipboard!');
                          },
                        ),
                        const SizedBox(height: 10),

                        // Website Detail Box (if present)
                        if (item.website != null && item.website!.trim().isNotEmpty) ...[
                          _DetailRowBox(
                            theme: theme,
                            fieldBg: fieldBg,
                            cardBorder: cardBorder,
                            icon: FLucideIcons.globe,
                            label: 'Website URL',
                            value: item.website!,
                            valueColor: theme.colors.primary,
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: item.website!));
                              HapticFeedback.lightImpact();
                              showAppSnackBar(context, 'Website URL copied to clipboard!');
                            },
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Notes Detail Box (if present)
                        if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                          _DetailRowBox(
                            theme: theme,
                            fieldBg: fieldBg,
                            cardBorder: cardBorder,
                            icon: FLucideIcons.notepadText,
                            label: 'Notes & Sensitive Records',
                            value: item.notes!,
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: item.notes!));
                              HapticFeedback.lightImpact();
                              showAppSnackBar(context, 'Notes copied to clipboard!');
                            },
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Security status metadata
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colors.secondary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(FLucideIcons.shieldCheck, size: 16, color: theme.colors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Protected securely on device • ${item.timeAgoText}',
                                  style: TextStyle(fontSize: 11, color: theme.colors.mutedForeground),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons: Edit and Done
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cardBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: Icon(FLucideIcons.penLine, size: 14, color: theme.colors.foreground),
                                label: Text(
                                  'Edit Password',
                                  style: TextStyle(
                                    color: theme.colors.foreground,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetCtx).pop();
                                  _showEditPasswordDrawer(context, item);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colors.primary,
                                  foregroundColor: theme.colors.primaryForeground,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
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

  void _confirmDelete(BuildContext context, VaultItem item) {
    final theme = context.theme;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: theme.colors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(FLucideIcons.alertTriangle, size: 20, color: theme.colors.destructive),
              const SizedBox(width: 10),
              const Text('Delete Credential', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${item.title}"? This cannot be undone.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colors.destructive,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                OfflineStore.instance.deleteVaultItem(item.id);
                HapticFeedback.lightImpact();
                showAppSnackBar(context, 'Credential deleted');
              },
              child: const Text('Delete'),
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

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final allItems = store.vaultItems;
        final filteredItems = _selectedCategory == 'All'
            ? allItems
            : allItems
                .where((i) => i.group.toLowerCase() == _selectedCategory.toLowerCase())
                .toList();

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await store.syncVaultWithLiveDb(silent: true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 88),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // 1. Themed Category Filter Pills Bar (with inline + Category action)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 'All' Filter Pill
                        _CategoryPill(
                          icon: FLucideIcons.layoutGrid,
                          label: 'All',
                          isSelected: _selectedCategory == 'All',
                          onTap: () => setState(() => _selectedCategory = 'All'),
                        ),
                        // Dynamic Category Filter Pills
                        for (final cat in store.vaultCategories) ...[
                          const SizedBox(width: 6),
                          _CategoryPill(
                            icon: getVaultCategoryIcon(cat.name, cat.emoji),
                            label: cat.name,
                            isSelected: _selectedCategory.toLowerCase() == cat.name.toLowerCase(),
                            onTap: () => setState(() => _selectedCategory = cat.name),
                          ),
                        ],
                      const SizedBox(width: 6),
                      // Add Category Action Button in strip
                      AnimatedPressable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showAddCategoryDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: theme.colors.secondary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colors.border,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FLucideIcons.folderPlus, size: 13, color: theme.colors.primary),
                              const SizedBox(width: 5),
                              Text(
                                'Add Category',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                const SizedBox(height: 14),

                // 3. Credential Items List
                if (filteredItems.isEmpty) ...[
                  FCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(FLucideIcons.shieldAlert, size: 24, color: theme.colors.mutedForeground),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No passwords in $_selectedCategory',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the Add Password button to create credentials in this folder.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: theme.colors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  for (var i = 0; i < filteredItems.length; i++) ...[
                    TweenAnimationBuilder<double>(
                      key: ValueKey(filteredItems[i].id),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 220 + (i * 40).clamp(0, 300)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1.0 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _VaultCredentialCard(
                        item: filteredItems[i],
                        onEdit: () => _showEditPasswordDrawer(context, filteredItems[i]),
                        onDelete: () => _confirmDelete(context, filteredItems[i]),
                        onShowDetails: () => _showItemDetailsSheet(context, filteredItems[i]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),

          // 4. Floating Action Button (Single Primary FAB) with tactile press bounce
          Positioned(
            bottom: 12,
            right: 12,
            child: AnimatedPressable(
              onTap: () {
                HapticFeedback.lightImpact();
                _showAddPasswordDrawer(context);
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colors.primary.withValues(alpha: 0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(FLucideIcons.plus, size: 26, color: theme.colors.primaryForeground),
                ),
              ),
            ),
          ),
          ],
        );
      },
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colors.primary.withValues(alpha: 0.15)
              : theme.colors.secondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.colors.primary : theme.colors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? theme.colors.primary : theme.colors.mutedForeground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.colors.primary : theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRowBox extends StatelessWidget {
  const _DetailRowBox({
    required this.theme,
    required this.fieldBg,
    required this.cardBorder,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailingAction,
    this.onCopy,
  });

  final dynamic theme;
  final Color fieldBg;
  final Color cardBorder;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailingAction;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colors.mutedForeground,
                ),
              ),
              const Spacer(),
              ?trailingAction,
              if (onCopy != null)
                GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colors.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FLucideIcons.copy, size: 11, color: theme.colors.primary),
                        const SizedBox(width: 3),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultCredentialCard extends StatefulWidget {
  const _VaultCredentialCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onShowDetails,
  });

  final VaultItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShowDetails;

  @override
  State<_VaultCredentialCard> createState() => _VaultCredentialCardState();
}

class _VaultCredentialCardState extends State<_VaultCredentialCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF14161B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: App Icon Emblem, Title, Website Button, Show Details, Edit, Delete
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colors.primary.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      getVaultCategoryIcon(widget.item.displayGroup),
                      size: 19,
                      color: theme.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: theme.colors.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.displayGroup,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),

                // Button to Show Details
                AnimatedPressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onShowDetails();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: theme.colors.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FLucideIcons.info, size: 11, color: theme.colors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                IconButton(
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  icon: Icon(FLucideIcons.trash2, size: 15, color: theme.colors.destructive),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Credential Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  // Username
                  Row(
                    children: [
                      Icon(FLucideIcons.user, size: 14, color: theme.colors.mutedForeground),
                      const SizedBox(width: 6),
                      Text(
                        'Username: ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colors.foreground,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.item.username,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colors.foreground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.item.username));
                          HapticFeedback.lightImpact();
                          showAppSnackBar(context, 'Username copied to clipboard!');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(FLucideIcons.copy, size: 14, color: theme.colors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 14,
                    thickness: 0.8,
                    color: isDark ? const Color(0xFF262930) : const Color(0xFFE2E8F0),
                  ),

                  // Password
                  Row(
                    children: [
                      Icon(FLucideIcons.lock, size: 14, color: theme.colors.mutedForeground),
                      const SizedBox(width: 6),
                      Text(
                        'Password: ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colors.foreground,
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _revealed ? widget.item.password : '••••••••••••',
                            key: ValueKey(_revealed),
                            style: TextStyle(
                              fontSize: _revealed ? 12.5 : 12,
                              letterSpacing: _revealed ? 0 : 1.5,
                              color: theme.colors.foreground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _revealed = !_revealed),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(
                            _revealed ? FLucideIcons.eyeOff : FLucideIcons.eye,
                            size: 15,
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.item.password));
                          HapticFeedback.lightImpact();
                          showAppSnackBar(context, 'Password copied to clipboard!');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(FLucideIcons.copy, size: 14, color: theme.colors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Prominent Notes Section directly on the card
            if (widget.item.notes != null && widget.item.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colors.secondary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(FLucideIcons.notepadText, size: 13, color: theme.colors.mutedForeground),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colors.foreground,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: widget.item.notes!));
                                  HapticFeedback.lightImpact();
                                  showAppSnackBar(context, 'Notes copied to clipboard!');
                                },
                                child: Icon(FLucideIcons.copy, size: 12, color: theme.colors.mutedForeground),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.notes!,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: theme.colors.foreground.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Bottom Row: Timestamp on Left, Edit Action on Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FLucideIcons.clock, size: 12, color: theme.colors.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      widget.item.timeAgoText,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                AnimatedPressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onEdit();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: theme.colors.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FLucideIcons.penLine, size: 11, color: theme.colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
    showAppSnackBar(context, message);
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
    bool isSubmitting = false;

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
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      setModalState(() => localError = 'Please enter your full name');
                                      return;
                                    }

                                    // Preserve existing email and phone credentials (read-only)
                                    final userEmail = user?.email ?? emailController.text.trim();
                                    final userMobile = user?.mobile ?? '+91${mobileController.text.trim()}';

                                    setModalState(() {
                                      localError = null;
                                      isSubmitting = true;
                                    });

                                    try {
                                      await AuthService.instance.updateProfile(
                                        name: name,
                                        email: userEmail,
                                        mobile: userMobile,
                                        gender: selectedGender,
                                      );
                                      HapticFeedback.lightImpact();
                                    } catch (e) {
                                      setModalState(() {
                                        localError = e.toString().replaceFirst('Exception: ', '');
                                        isSubmitting = false;
                                      });
                                      return;
                                    }

                                    if (sheetCtx.mounted) {
                                      Navigator.of(sheetCtx).pop();
                                    }
                                    if (parentContext.mounted) {
                                      _showFeedbackSnackBar(parentContext, 'Profile updated successfully!');
                                    }
                                  },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: isSubmitting
                                  ? SizedBox(
                                      key: const ValueKey('profile_spinner'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: theme.colors.primaryForeground,
                                      ),
                                    )
                                  : const Row(
                                      key: ValueKey('profile_content'),
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
    bool isSubmitting = false;

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
                            onPressed: isSubmitting
                                ? null
                                : () async {
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

                                    setModalState(() {
                                      localError = null;
                                      isSubmitting = true;
                                    });

                                    try {
                                      await AuthService.instance.updatePin(oldPin: oldPin, newPin: newPin);
                                      HapticFeedback.lightImpact();
                                    } catch (e) {
                                      setModalState(() {
                                        localError = e.toString().replaceFirst('Exception: ', '');
                                        isSubmitting = false;
                                      });
                                      return;
                                    }

                                    if (sheetCtx.mounted) {
                                      Navigator.of(sheetCtx).pop();
                                    }
                                    if (parentContext.mounted) {
                                      _showFeedbackSnackBar(parentContext, 'Security PIN successfully updated!');
                                    }
                                  },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: isSubmitting
                                  ? SizedBox(
                                      key: const ValueKey('pin_spinner'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: theme.colors.primaryForeground,
                                      ),
                                    )
                                  : const Row(
                                      key: ValueKey('pin_content'),
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
