import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';

/// A PIN / OTP field backed by a **single** [TextField].
///
/// The previous implementation used one `TextField` per digit and hopped focus
/// with `FocusScope.requestFocus` / `unfocus` on every keystroke. On iOS that
/// makes the software keyboard flicker and "bounce", and backspace on an empty
/// box does nothing (no change event fires). A single hidden field avoids all
/// of that: one focus, one keyboard, natural backspace, and reliable paste of
/// an SMS code.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String>? onChanged;

  /// Fired once, when the last digit is entered.
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length && !_completed) {
      _completed = true;
      _focusNode.unfocus();
      widget.onCompleted?.call(value);
    } else if (value.length < widget.length) {
      _completed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;

    // Size the boxes to the available width so any digit count (4, 6, …) fits
    // on a phone screen without overflowing. Boxes never grow past 64pt, so a
    // short code still looks the same as before.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0; // horizontal margin on each side of a box
        const maxBoxWidth = 64.0;
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxBoxWidth * widget.length + gap * 2 * widget.length;
        final rawWidth =
            (available - gap * 2 * widget.length) / widget.length;
        final boxWidth = rawWidth.clamp(36.0, maxBoxWidth);
        final boxHeight = boxWidth * 1.125; // keep the original 64:72 ratio

        return GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: boxHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The real input — kept off-screen sized but fully functional.
                // It holds all digits, so there is nothing to hop focus between.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      showCursor: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(widget.length),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: _handleChanged,
                    ),
                  ),
                ),
                // The visual boxes. Ignore pointer so every tap reaches the field.
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.length, (i) {
                      final filled = i < text.length;
                      final isCurrent =
                          i == text.length && _focusNode.hasFocus;
                      final active = isCurrent || filled;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: gap),
                        width: boxWidth,
                        height: boxHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filled ? text[i] : '',
                          style: AppTypography.heading3.copyWith(
                            color: AppColors.semanticGrayNeutralFgHigh,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
