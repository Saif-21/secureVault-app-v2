import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/main.dart';
import 'package:app/src/models/user_model.dart';
import 'package:app/src/navigation/app_shell.dart';
import 'package:app/src/navigation/minimal_morphing_bottom_bar.dart';
import 'package:app/src/screens/auth/components/pin_input_boxes.dart';
import 'package:app/src/screens/auth/login_screen.dart';
import 'package:app/src/screens/auth/register_screen.dart';
import 'package:app/src/screens/privacy_policy_screen.dart';
import 'package:app/src/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance.setMockUser(null);
  });

  testWidgets('App renders LoginScreen when unauthenticated and opens RegisterScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify LoginScreen is shown
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign up here'), findsOneWidget);

    // Scroll to and tap "Sign up here"
    await tester.ensureVisible(find.text('Sign up here'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up here'));
    await tester.pumpAndSettle();

    // Verify RegisterScreen is pushed
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Log in here'), findsOneWidget);
  });

  testWidgets('Minimalist morphing bottom navigation renders all 4 tabs and switches views when authenticated', (
    WidgetTester tester,
  ) async {
    // Authenticate a mock user
    AuthService.instance.setMockUser(
      const UserModel(
        id: 'test_user_1',
        name: 'Alex Morgan',
        email: 'alex.morgan@example.com',
        mobile: '9876543210',
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify presence of MinimalMorphingBottomBar and AppShell
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(MinimalMorphingBottomBar), findsOneWidget);

    // Verify top right navigation icon on Home screen (Expenses)
    expect(find.byIcon(FLucideIcons.compass), findsOneWidget);

    // Tap top right navigation icon to open Quick Navigation sheet
    await tester.tap(find.byIcon(FLucideIcons.compass));
    await tester.pumpAndSettle();
    expect(find.text('Quick Navigation'), findsOneWidget);

    // Tap 'Todos' in the Quick Navigation sheet to navigate
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();
    expect(find.byType(TodosView), findsOneWidget);

    // Switch back to Expenses tab
    await tester.tap(find.byIcon(AppTab.expenses.icon).first);
    await tester.pumpAndSettle();

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

      // Active tab label is shown in the morphing bottom bar and the view is mounted
      expect(
        find.descendant(
          of: find.byType(MinimalMorphingBottomBar),
          matching: find.text(tab.label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Profile screen displays invite friend, update pin, data & privacy, and back arrow returns to Expenses', (
    WidgetTester tester,
  ) async {
    AuthService.instance.setMockUser(
      const UserModel(
        id: 'test_user_1',
        name: 'Alex Morgan',
        email: 'alex.morgan@example.com',
        mobile: '9876543210',
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Tap Profile tab
    final profileTabFinder = find.descendant(
      of: find.byType(MinimalMorphingBottomBar),
      matching: find.byIcon(AppTab.profile.icon),
    );
    await tester.tap(profileTabFinder);
    await tester.pumpAndSettle();

    // Verify Profile view elements
    expect(find.byType(ProfileView), findsOneWidget);
    expect(find.text('Invite Friends & Family'), findsOneWidget);
    expect(find.text('Invitations only • No referral tracking active'), findsOneWidget);
    expect(find.text('Edit Profile Information'), findsOneWidget);
    expect(find.text('Update Security PIN'), findsOneWidget);
    expect(find.text('Data Storage'), findsNothing); // Removed as requested
    expect(find.text('PRO'), findsNothing); // Removed as requested

    // Test Edit Profile Drawer
    await tester.tap(find.text('Edit Profile Information'));
    await tester.pumpAndSettle();

    // Verify Edit Profile Drawer is open with all fields
    expect(find.text('Edit Profile Details'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Save Profile Changes'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    // Verify Email and Mobile are marked Read-only
    expect(find.text('Read-only'), findsNWidgets(2));

    // Enter updated name and save
    await tester.enterText(find.widgetWithText(TextField, 'Alex Morgan'), 'Saif Khan');
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(ProfileView))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // Verify name updated in Profile header card
    expect(find.text('Saif Khan'), findsOneWidget);

    // Verify Notifications & Alerts section
    await tester.scrollUntilVisible(find.text('Notifications & Alerts'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Notifications & Alerts'), findsOneWidget);
    expect(find.text('Daily Expense Reminder'), findsOneWidget);
    expect(find.text('Budget & Spending Alerts'), findsOneWidget);

    // Scroll to and verify Privacy & Security Policy
    await tester.scrollUntilVisible(find.text('Privacy & Security Policy'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Privacy & Security Policy'), findsOneWidget);

    // Tap to open dedicated Privacy & Security Policy Screen
    await tester.tap(find.text('Privacy & Security Policy'));
    await tester.pumpAndSettle();

    // Verify PrivacyPolicyScreen elements
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('Zero-Knowledge Privacy'), findsOneWidget);
    expect(find.text('1. Client-Side Zero-Knowledge Encryption'), findsOneWidget);
    expect(find.text('AES-256'), findsOneWidget);

    // Tap back button on PrivacyPolicyScreen to return to Profile
    await tester.tap(find.byIcon(FLucideIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileView), findsOneWidget);

    // Scroll back up and tap "Update Security PIN" to open bottom drawer
    await tester.scrollUntilVisible(find.text('Update Security PIN'), -200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Security PIN'));
    await tester.pumpAndSettle();

    // Verify drawer opens with Save New PIN and PinInputBoxes
    expect(find.text('Save New PIN'), findsOneWidget);
    expect(find.byType(PinInputBoxes), findsWidgets);

    // Dismiss bottom sheet by tapping barrier
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // Verify back arrow in header
    final backArrowFinder = find.byIcon(FLucideIcons.arrowLeft);
    expect(backArrowFinder, findsOneWidget);

    // Tap back arrow to return to Expenses tab
    await tester.tap(backArrowFinder);
    await tester.pumpAndSettle();

    // Verify Expenses tab is now active (no back arrow, logo shown)
    expect(find.byType(ExpensesView), findsOneWidget);
    expect(find.byIcon(FLucideIcons.arrowLeft), findsNothing);
    expect(
      find.descendant(
        of: find.byType(MinimalMorphingBottomBar),
        matching: find.text('Expenses'),
      ),
      findsOneWidget,
    );

    // Verify Todos screen header also displays the smooth back arrow
    final todosTabFinder = find.descendant(
      of: find.byType(MinimalMorphingBottomBar),
      matching: find.byIcon(AppTab.todos.icon),
    );
    await tester.tap(todosTabFinder);
    await tester.pumpAndSettle();
    expect(find.byIcon(FLucideIcons.arrowLeft), findsOneWidget);
    await tester.tap(find.byIcon(FLucideIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(find.byType(ExpensesView), findsOneWidget);
  });

  testWidgets('Back history walks back through tabs and shows Exit dialog with Don\'t ask again checkbox on root', (
    WidgetTester tester,
  ) async {
    AuthService.instance.setMockUser(
      const UserModel(
        id: 'test_user_1',
        name: 'Alex Morgan',
        email: 'alex.morgan@example.com',
        mobile: '9876543210',
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 1. Navigate: Expenses -> Todos -> Vault
    await tester.tap(
      find.descendant(
        of: find.byType(MinimalMorphingBottomBar),
        matching: find.byIcon(AppTab.todos.icon),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TodosView), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(MinimalMorphingBottomBar),
        matching: find.byIcon(AppTab.vault.icon),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VaultView), findsOneWidget);

    // 2. Tap back arrow on Vault -> should step back to Todos
    await tester.tap(find.byIcon(FLucideIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(find.byType(TodosView), findsOneWidget);

    // 3. Tap back arrow on Todos -> should step back to Expenses
    await tester.tap(find.byIcon(FLucideIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(find.byType(ExpensesView), findsOneWidget);

    // 4. Trigger pop on root (Expenses) -> prompts exit confirmation
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Verify Exit dialog is displayed
    expect(find.text('Exit App?'), findsOneWidget);
    expect(find.text('Are you sure you want to close SecureVault?'), findsOneWidget);
    expect(find.text("Don't ask again"), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    // Toggle "Don't ask again"
    await tester.tap(find.text("Don't ask again"));
    await tester.pumpAndSettle();

    // Tap Cancel -> dialog closes, user remains in app
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Exit App?'), findsNothing);
    expect(find.byType(ExpensesView), findsOneWidget);
  });

  testWidgets('VaultView displays categories, filters credentials, toggles password visibility, and creates new category and password', (
    WidgetTester tester,
  ) async {
    AuthService.instance.setMockUser(
      const UserModel(
        id: 'test_user_vault',
        name: 'Saif Khan',
        email: 'saif@example.com',
        mobile: '9988776655',
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Navigate to Vault tab
    await tester.tap(
      find.descendant(
        of: find.byType(MinimalMorphingBottomBar),
        matching: find.byIcon(AppTab.vault.icon),
      ),
    );
    await tester.pumpAndSettle();

    // Verify presence of VaultView & section elements
    expect(find.byType(VaultView), findsOneWidget);
    expect(find.text('Credentials & Passwords'), findsNothing); // Removed as requested
    expect(find.text('Secure Vault'), findsOneWidget);

    // Verify presence of reference credential "Facebook"
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('facebook.com'), findsOneWidget);
    expect(find.text('••••••••••••'), findsWidgets);

    // Toggle password visibility on first credential card
    await tester.tap(find.byIcon(FLucideIcons.eye).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(FLucideIcons.eyeOff), findsWidgets);

    // Filter by 'Financial' category
    await tester.tap(find.text('Financial').first);
    await tester.pumpAndSettle();
    expect(find.text('HDFC NetBanking'), findsOneWidget);
    expect(find.text('Facebook'), findsNothing);

    // Filter back to 'All'
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Facebook'), findsOneWidget);

    // Tap Add Category button in the filter strip
    await tester.tap(find.byIcon(FLucideIcons.folderPlus));
    await tester.pumpAndSettle();
    expect(find.text('Add New Category'), findsOneWidget);

    // Enter new category name and save
    await tester.enterText(find.widgetWithText(TextField, 'e.g., Gaming, Streaming, Work'), 'Gaming');
    await tester.tap(find.byIcon(FLucideIcons.gamepad2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Category'));
    await tester.pumpAndSettle();

    // Verify "Gaming" category appears in filter pills
    expect(find.text('Gaming'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(VaultView))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // Tap Add Password button
    await tester.tap(find.byIcon(FLucideIcons.plus).first);
    await tester.pumpAndSettle();
    expect(find.text('Add New Password'), findsOneWidget);
    expect(find.text('Secure your digital life'), findsOneWidget);

    // Fill in new password details
    await tester.enterText(find.widgetWithText(TextField, 'e.g., Facebook, Gmail, Netflix'), 'Steam Vault');
    await tester.enterText(find.widgetWithText(TextField, 'your.email@example.com'), 'gamer@steam.com');
    await tester.enterText(find.widgetWithText(TextField, 'Enter your password'), 'GamerPass#99');

    // Tap "Save Password"
    await tester.ensureVisible(find.text('Save Password'));
    await tester.tap(find.text('Save Password'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(VaultView))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // Verify newly added credential appears in the list
    expect(find.text('Steam Vault'), findsOneWidget);
    expect(find.text('gamer@steam.com'), findsOneWidget);

    // Verify presence of "Details" button and "Edit" button
    expect(find.text('Details'), findsWidgets);
    expect(find.text('Edit'), findsWidgets);

    // Verify notes are shown on credential cards
    expect(find.text('Notes'), findsWidgets);

    // Tap "Details" button on a credential card to open details sheet
    await tester.tap(find.text('Details').at(1));
    await tester.pumpAndSettle();

    // Verify Details sheet opens with website URL and secure storage status (No AES-256)
    expect(find.text('Website URL'), findsOneWidget);
    expect(find.text('Stored securely on device'), findsOneWidget);
    expect(find.text('Edit Password'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Close details sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Tap "Edit" button on a credential card to open edit drawer
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Password'), findsOneWidget);
    expect(find.text('Update credential details'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Close edit drawer
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
