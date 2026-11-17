import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive 6-digit individual box PIN input with auto-focus and backspace handling.
class PinInputBoxes extends StatefulWidget {
  const PinInputBoxes({
    required this.controller,
    this.focusNode,
    this.obscureText = true,
    this.onChanged,
    this.onCompleted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<PinInputBoxes> createState() => _PinInputBoxesState();
}

class _PinInputBoxesState extends State<PinInputBoxes> {
  late FocusNode _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    widget.controller.addListener(_handleTextChange);
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant PinInputBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    setState(() {});
    widget.onChanged?.call(widget.controller.text);
    if (widget.controller.text.length == 6) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  void _handleFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentText = widget.controller.text;
    final isFocused = _effectiveFocusNode.hasFocus;

    const brandPrimary = Color(0xFF5CE65C);
    final defaultBorder = isDark ? const Color(0xFF2E323B) : const Color(0xFFE2E8F0);
    final defaultBg = isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC);
    final activeBg = isDark ? const Color(0xFF20232B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic box size ensuring 6 boxes fit on any phone width
        final availableWidth = constraints.maxWidth;
        const boxSpacing = 8.0;
        final totalSpacing = boxSpacing * 5;
        final calculatedWidth = ((availableWidth - totalSpacing) / 6).clamp(38.0, 52.0);
        final boxHeight = (calculatedWidth * 1.15).clamp(46.0, 56.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 6 Visual Digit Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final isCurrentIndex = index == currentText.length;
                final isCellFocused = isFocused && isCurrentIndex;
                final isFilled = index < currentText.length;
                final digit = isFilled ? currentText[index] : '';

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: calculatedWidth,
                  height: boxHeight,
                  decoration: BoxDecoration(
                    color: isCellFocused || isFilled ? activeBg : defaultBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCellFocused
                          ? brandPrimary
                          : isFilled
                              ? brandPrimary.withValues(alpha: 0.6)
                              : defaultBorder,
                      width: isCellFocused ? 2.0 : 1.2,
                    ),
                    boxShadow: isCellFocused
                        ? [
                            BoxShadow(
                              color: brandPrimary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isFilled
                        ? (widget.obscureText
                            ? Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: textColor,
                                ),
                              )
                            : Text(
                                digit,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ))
                        : (isCellFocused
                            ? Container(
                                width: 2,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: brandPrimary,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              )
                            : const SizedBox.shrink()),
                  ),
                );
              }),
            ),

            // Invisible full-width overlay TextField capturing keystrokes
            Positioned.fill(
              child: Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _effectiveFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  cursorColor: Colors.transparent,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
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

