import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback when a tab is tapped.
typedef OnTabSelected = void Function(int index);

/// Item configuration for the minimal morphing bottom navigation bar.
class MinimalBarItem {
  const MinimalBarItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

/// Balanced minimalist morphing pill bottom navigation bar matching the reference UI.
class MinimalMorphingBottomBar extends StatelessWidget {
  const MinimalMorphingBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    super.key,
  });

  final int currentIndex;
  final OnTabSelected onTap;
  final List<MinimalBarItem> items;

  // Custom styling tokens matching the reference screenshot
  static const Color barBackground = Color(0xFF1A1B1F);
  static const Color activeGreen = Color(0xFF5CE65C);
  static const Color activeIconBlack = Color(0xFF0F1012);
  static const Color inactiveIconColor = Color(0xFFD4D4D8);
  static const Color buttonBorderColor = Color(0xFF282A30);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          bottomInset > 0 ? bottomInset + 6 : 12,
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _MorphingTabButton(
                  item: items[i],
                  isSelected: currentIndex == i,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(i);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MorphingTabButton extends StatelessWidget {
  const _MorphingTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final MinimalBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: 46,
        padding: isSelected
            ? const EdgeInsets.only(left: 4, right: 14)
            : const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: MinimalMorphingBottomBar.barBackground,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: MinimalMorphingBottomBar.buttonBorderColor,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? MinimalMorphingBottomBar.activeGreen
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  item.icon,
                  size: 19,
                  color: isSelected
                      ? MinimalMorphingBottomBar.activeIconBlack
                      : MinimalMorphingBottomBar.inactiveIconColor,
                ),
              ),
            ),

            // Tab label text
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: isSelected
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
