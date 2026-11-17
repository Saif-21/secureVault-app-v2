import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'package:app/src/screens/auth/components/pin_input_boxes.dart';
import 'package:app/src/services/api_service.dart';
import 'package:app/src/services/auth_service.dart';

/// Attractive, user-friendly Register Screen matching the SecureVault reference design.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();

  bool _obscurePin = true;
  String? _errorMessage;

  // Primary brand colors matching bottom navigation dock
  static const Color brandPrimary = Color(0xFF5CE65C);
  static const Color brandForeground = Color(0xFF0F1012);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();
    final pin = _pinController.text.trim();

    // 1. Name validation
    if (name.isEmpty || name.length < 3) {
      setState(() => _errorMessage = 'Full Name must be at least 3 characters long');
      return;
    }

    // 2. Email validation
    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    // 3. Mobile validation (10 digits)
    if (mobile.length != 10 || !RegExp(r'^\d{10}$').hasMatch(mobile)) {
      setState(() => _errorMessage = 'Mobile number must be exactly 10 digits');
      return;
    }

    // 4. PIN validation (exactly 6 digits)
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _errorMessage = 'Security PIN must be exactly 6 digits');
      return;
    }

    HapticFeedback.lightImpact();

    try {
      await AuthService.instance.signup(
        name: name,
        email: email,
        mobile: mobile,
        pin: pin,
      );
      if (mounted) {
        Navigator.of(context).pop(); // Authenticated state automatically renders AppShell
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = AuthService.instance;

    final bgColor = isDark ? const Color(0xFF0F1012) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0xFF23262E) : const Color(0xFFE2E8F0);
    final fieldBg = isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC);
    final labelColor = isDark ? const Color(0xFFE4E4E7) : const Color(0xFF1E293B);
    final hintColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            FLucideIcons.arrowLeft,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Emblem & Logo
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: brandPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: brandPrimary.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            FLucideIcons.lock,
                            size: 22,
                            color: brandPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Brand Title
                  Center(
                    child: Text(
                      'SecureVault',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? brandPrimary : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Heading Titles matching reference
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign up with your details below',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: hintColor,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colors.destructive.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colors.destructive.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(FLucideIcons.alertCircle, size: 18, color: theme.colors.destructive),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(fontSize: 12, color: theme.colors.destructive),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Field 1: Full Name
                  Text(
                    'Full Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'John Doe',
                      hintStyle: TextStyle(color: hintColor, fontSize: 14),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: brandPrimary, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 2: Email Address
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'user@domain.com',
                      hintStyle: TextStyle(color: hintColor, fontSize: 14),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: brandPrimary, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 3: Mobile Number
                  Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '98765 43210',
                      hintStyle: TextStyle(color: hintColor, fontSize: 14, letterSpacing: 0.3, fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+91',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 18,
                              color: cardBorder,
                            ),
                          ],
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: brandPrimary, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 4: 6-Digit PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '6-Digit PIN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _obscurePin = !_obscurePin),
                        child: Row(
                          children: [
                            Icon(
                              _obscurePin ? FLucideIcons.eyeOff : FLucideIcons.eye,
                              size: 15,
                              color: hintColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _obscurePin ? 'Show' : 'Hide',
                              style: TextStyle(fontSize: 11.5, color: hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 6 Individual PIN Digit Boxes
                  PinInputBoxes(
                    controller: _pinController,
                    obscureText: _obscurePin,
                  ),
                  const SizedBox(height: 24),

                  // Action Button: Sign Up →
                  ListenableBuilder(
                    listenable: auth,
                    builder: (context, _) {
                      return SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandPrimary,
                            foregroundColor: brandForeground,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            disabledBackgroundColor: brandPrimary.withValues(alpha: 0.5),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: brandForeground,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(FLucideIcons.arrowRight, size: 16),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),

                  // Return to Login: "Already have an account? Log in here"
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(fontSize: 12.5, color: hintColor),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'Log in here',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? brandPrimary : const Color(0xFF16A34A),
                            decoration: TextDecoration.underline,
                            decorationColor: isDark ? brandPrimary : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bottom Security Badge
                  Center(
                    child: Text(
                      'This app is protected by advanced encryption and security measures.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: hintColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
