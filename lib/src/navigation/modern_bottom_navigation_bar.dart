import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

/// Callback when a tab item in the bottom bar is tapped.
typedef OnTabSelected = void Function(int index);

/// A modern, floating, frosted-glass bottom navigation bar built with Forui components and tokens.
class ModernBottomNavigationBar extends StatelessWidget {
  const ModernBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    super.key,
  });

  final int currentIndex;
  final OnTabSelected onTap;
  final List<ModernBottomBarItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colors.card.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? theme.colors.border.withValues(alpha: 0.6)
                    : theme.colors.border.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FBottomNavigationBar(
              safeAreaBottom: true,
              style: FBottomNavigationBarStyle(
                decoration: const BoxDecoration(color: Colors.transparent),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                itemStyle: theme.bottomNavigationBarStyle.itemStyle,
              ),
              index: currentIndex,
              onChange: (index) {
                HapticFeedback.lightImpact();
                onTap(index);
              },
              children: [
                for (var i = 0; i < items.length; i++)
                  FBottomNavigationBarItem(
                    icon: _ModernTabIcon(
                      icon: items[i].icon,
                      isSelected: currentIndex == i,
                      badgeText: items[i].badgeText,
                    ),
                    label: _ModernTabLabel(
                      label: items[i].label,
                      isSelected: currentIndex == i,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Metadata configuration for each item in the modern bottom navigation bar.
class ModernBottomBarItemData {
  const ModernBottomBarItemData({
    required this.label,
    required this.icon,
    this.badgeText,
  });

  final String label;
  final IconData icon;
  final String? badgeText;
}

class _ModernTabIcon extends StatelessWidget {
  const _ModernTabIcon({
    required this.icon,
    required this.isSelected,
    this.badgeText,
  });

  final IconData icon;
  final bool isSelected;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isSelected ? 1.08 : 1.0,
            child: Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colors.primary
                  : theme.colors.mutedForeground,
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: -6,
              right: -10,
              child: FBadge(
                variant: FBadgeVariant.primary,
                style: .delta(
                  padding: .value(
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  ),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModernTabLabel extends StatelessWidget {
  const _ModernTabLabel({
    required this.label,
    required this.isSelected,
  });

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? theme.colors.primary
                : theme.colors.mutedForeground,
          ),
          child: Text(label),
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: isSelected ? 4 : 0,
          height: 4,
          decoration: BoxDecoration(
            color: isSelected ? theme.colors.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
