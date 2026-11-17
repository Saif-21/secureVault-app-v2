import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'package:app/src/screens/auth/components/pin_input_boxes.dart';
import 'package:app/src/screens/auth/register_screen.dart';
import 'package:app/src/services/api_service.dart';
import 'package:app/src/services/auth_service.dart';

/// Attractive, user-friendly Login Screen matching the SecureVault reference design.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();

  bool _useEmail = false; // Default to Mobile matching the reference screenshot
  bool _obscurePin = true;
  String? _errorMessage;

  // Primary brand colors matching bottom navigation dock
  static const Color brandPrimary = Color(0xFF5CE65C);
  static const Color brandForeground = Color(0xFF0F1012);

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    final pin = _pinController.text.trim();

    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _errorMessage = 'Security PIN must be exactly 6 digits');
      return;
    }

    if (_useEmail) {
      final email = _emailController.text.trim();
      if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        setState(() => _errorMessage = 'Please enter a valid email address');
        return;
      }
    } else {
      final mobile = _mobileController.text.trim();
      if (mobile.length != 10 || !RegExp(r'^\d{10}$').hasMatch(mobile)) {
        setState(() => _errorMessage = 'Mobile number must be exactly 10 digits');
        return;
      }
    }

    HapticFeedback.lightImpact();

    try {
      await AuthService.instance.login(
        email: _useEmail ? _emailController.text.trim() : null,
        mobile: !_useEmail ? _mobileController.text.trim() : null,
        pin: pin,
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: ${e.toString()}');
    }
  }

  void _showForgotPinDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2026) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(FLucideIcons.keyRound, color: brandPrimary, size: 22),
              SizedBox(width: 10),
              Text('Reset Security PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'To reset your 6-digit security PIN, please verify via your registered mobile number or email address on the next update.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: brandPrimary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

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
                    'Welcome Back!',
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
                    _useEmail ? 'Sign in with your email and PIN' : 'Sign in with your mobile and PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: hintColor,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Segmented Switcher Pill: [ Email | Mobile ]
                  Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1C23) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Stack(
                      children: [
                        // Single sliding active pill - ensures only ONE tab is highlighted at any time
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOutCubic,
                          alignment: _useEmail ? Alignment.centerLeft : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            heightFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: brandPrimary,
                                borderRadius: BorderRadius.circular(19),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandPrimary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Interactive Tab Labels
                        Row(
                          children: [
                            // Email Tab
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!_useEmail) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _useEmail = true;
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: _useEmail ? FontWeight.w700 : FontWeight.w500,
                                      color: _useEmail
                                          ? brandForeground
                                          : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B)),
                                    ),
                                    child: const Text('Email'),
                                  ),
                                ),
                              ),
                            ),

                            // Mobile Tab
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_useEmail) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _useEmail = false;
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: !_useEmail ? FontWeight.w700 : FontWeight.w500,
                                      color: !_useEmail
                                          ? brandForeground
                                          : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B)),
                                    ),
                                    child: const Text('Mobile'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Error Alert Banner
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

                  // Field Label: Mobile Number / Email Address
                  Text(
                    _useEmail ? 'Email Address' : 'Mobile Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Input Box
                  if (_useEmail)
                    TextField(
                      key: const ValueKey('login_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    )
                  else
                    TextField(
                      key: const ValueKey('login_mobile_field'),
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
                  const SizedBox(height: 18),

                  // 6-Digit PIN Label & Obscure Toggle
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
                  const SizedBox(height: 10),

                  // 6 Individual PIN Digit Boxes matching screenshot
                  PinInputBoxes(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    onCompleted: (val) {
                      if (!_useEmail && _mobileController.text.length == 10) {
                        _handleLogin();
                      } else if (_useEmail && _emailController.text.isNotEmpty) {
                        _handleLogin();
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot PIN link aligned right
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _showForgotPinDialog(context),
                      child: Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? brandPrimary : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Big Action Button: Sign In →
                  ListenableBuilder(
                    listenable: auth,
                    builder: (context, _) {
                      return SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleLogin,
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
                                      'Sign In',
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
                  const SizedBox(height: 24),

                  // Switch to Registration: "Don't have an account? Sign up here"
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: TextStyle(fontSize: 12.5, color: hintColor),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'Sign up here',
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
                      'Protected by advanced encryption and security measures.',
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
