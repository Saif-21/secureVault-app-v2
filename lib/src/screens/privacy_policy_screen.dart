import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

/// Dedicated screen presenting the comprehensive Privacy & Security Policy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1012) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF23262E) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Top App Bar matching the app's smooth header styling
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
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
                          FLucideIcons.arrowLeft,
                          size: 17,
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy & Security Policy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: theme.colors.foreground,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FLucideIcons.shieldCheck, size: 12, color: theme.colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'AES-256',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Policy Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Hero Guarantee Banner Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colors.primary.withValues(alpha: 0.16),
                          theme.colors.primary.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FLucideIcons.lockKeyhole,
                            size: 20,
                            color: theme.colors.primaryForeground,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zero-Knowledge Privacy',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your financial records and vault credentials belong strictly to you. Neither our servers nor third parties can view your encrypted records.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Policy Section 1: Zero-Knowledge Encryption
                  _PolicySectionCard(
                    icon: FLucideIcons.keyRound,
                    title: '1. Client-Side Zero-Knowledge Encryption',
                    content:
                        'All confidential vault items, passwords, and sensitive notes are encrypted on your device using industry-standard AES-256-GCM before storage.\n\n'
                        'The encryption keys are derived from your 6-digit security PIN using a unique salt. Because decryption occurs exclusively on your physical phone, no server or intermediary ever has access to your unencrypted data.',
                  ),
                  const SizedBox(height: 10),

                  // Policy Section 2: Local-First Storage Architecture
                  _PolicySectionCard(
                    icon: FLucideIcons.database,
                    title: '2. Local-First Storage Architecture',
                    content:
                        'Your daily expenses, categories, budget allocations, and pending todo tasks are stored locally on your device storage.\n\n'
                        'The application functions fully without requiring an active internet connection. When you choose to sync with our backend, data transmissions are protected via Transport Layer Security (TLS 1.3).',
                  ),
                  const SizedBox(height: 10),

                  // Policy Section 3: No Third-Party Tracking or Ads
                  _PolicySectionCard(
                    icon: FLucideIcons.shieldAlert,
                    title: '3. Zero Third-Party Tracking & Advertising',
                    content:
                        'SecureVault does not contain advertising SDKs, behavioral analytics scripts, or commercial tracking pixels.\n\n'
                        'We do not monetize your financial entries, sell personal profiles to data brokers, or share your contact info with advertisers.',
                  ),
                  const SizedBox(height: 10),

                  // Policy Section 4: Device & Biometric Security
                  _PolicySectionCard(
                    icon: FLucideIcons.fingerprint,
                    title: '4. Biometric Protection & Hardware Keystore',
                    content:
                        'You can enable biometric authentication (Fingerprint or Face ID) for instant, secure access.\n\n'
                        'Biometric verification utilizes your device’s hardware-backed Secure Enclave (iOS) or Android Keystore. Your raw biometric data remains in hardware and is never accessed or stored by the app.',
                  ),
                  const SizedBox(height: 10),

                  // Policy Section 5: Data Ownership & Portability
                  _PolicySectionCard(
                    icon: FLucideIcons.fileSpreadsheet,
                    title: '5. Absolute Data Ownership & Portability',
                    content:
                        'You maintain full ownership of all information recorded in the application.\n\n'
                        'You may export your transaction logs and backup files in standard, portable formats (CSV / JSON) at any time through the Profile settings. You also have the right to erase all stored account records at will.',
                  ),
                  const SizedBox(height: 10),

                  // Policy Section 6: Security Updates & Inquiries
                  _PolicySectionCard(
                    icon: FLucideIcons.circleCheck,
                    title: '6. Security Inquiries & Contact',
                    content:
                        'We routinely review our cryptographic implementations and update security standards.\n\n'
                        'For questions regarding your privacy, responsible vulnerability disclosures, or data requests, contact our security team at privacy@securevault.app.',
                  ),
                  const SizedBox(height: 14),

                  // Footer info container
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        'Version 2.4.0 • Last Revised: November 2026',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: theme.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: theme.colors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: theme.colors.foreground.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

