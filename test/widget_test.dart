import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:app/main.dart';
import 'package:app/src/navigation/app_shell.dart';
import 'package:app/src/navigation/minimal_morphing_bottom_bar.dart';

void main() {
  testWidgets('Minimalist morphing bottom navigation renders all 4 tabs and switches views', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // Verify presence of MinimalMorphingBottomBar
    expect(find.byType(MinimalMorphingBottomBar), findsOneWidget);

    // Verify all four tabs exist by icons
    for (final tab in AppTab.values) {
      expect(find.byIcon(tab.icon), findsWidgets);
    }

    // Default active tab is Expenses, its label text is visible
    expect(
      find.descendant(
        of: find.byType(MinimalMorphingBottomBar),
        matching: find.text('Expenses'),
      ),
      findsOneWidget,
    );
    expect(find.byType(ExpensesView), findsOneWidget);

    // Switch through Todos, Vault, Profile, and back to Expenses
    for (final tab in [
      AppTab.todos,
      AppTab.vault,
      AppTab.profile,
      AppTab.expenses,
    ]) {
      await tester.tap(find.byIcon(tab.icon).first);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(FHeader),
          matching: find.text(tab.label),
        ),
        findsOneWidget,
      );
    }
  });
}
