import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/constants.dart';

/// A mystical, minimal text field with glowing underline and gold cursor.
/// Designed for the ethereal onboarding experience.
class MysticTextField extends StatefulWidget {
  /// Text editing controller
  final TextEditingController? controller;

  /// Hint text shown when empty
  final String? hintText;

  /// Called when the user submits (presses Enter)
  final ValueChanged<String>? onSubmitted;

  /// Called when the text changes
  final ValueChanged<String>? onChanged;

  /// Text alignment
  final TextAlign textAlign;

  /// Auto focus on mount
  final bool autofocus;

  /// Text style override
  final TextStyle? textStyle;

  /// Focus node
  final FocusNode? focusNode;

  const MysticTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onSubmitted,
    this.onChanged,
    this.textAlign = TextAlign.center,
    this.autofocus = false,
    this.textStyle,
    this.focusNode,
  });

  @override
  State<MysticTextField> createState() => _MysticTextFieldState();
}

class _MysticTextFieldState extends State<MysticTextField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _glowController;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _focusNode.removeListener(_onFocusChange);
    _glowController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = 0.3 + (_glowController.value * 0.4);

        return Container(
          decoration: BoxDecoration(
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(glowIntensity * 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The text field
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                textAlign: widget.textAlign,
                style: widget.textStyle ??
                    AppTypography.headlineLarge.copyWith(
                      color: AppColors.textPrimary,
                      letterSpacing: 2,
                    ),
                cursorColor: AppColors.primary,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(1),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.headlineMedium.copyWith(
                    color: AppColors.textTertiary.withOpacity(0.5),
                    letterSpacing: 1,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMedium,
                    vertical: AppConstants.spacingSmall,
                  ),
                ),
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
              ),

              // Glowing underline
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLarge,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    colors: _isFocused
                        ? [
                            Colors.transparent,
                            AppColors.primary.withOpacity(glowIntensity),
                            AppColors.primaryLight.withOpacity(glowIntensity),
                            AppColors.primary.withOpacity(glowIntensity),
                            Colors.transparent,
                          ]
                        : [
                            Colors.transparent,
                            AppColors.textTertiary.withOpacity(0.3),
                            AppColors.textTertiary.withOpacity(0.5),
                            AppColors.textTertiary.withOpacity(0.3),
                            Colors.transparent,
                          ],
                  ),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(glowIntensity * 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A variant with even more minimal styling for rituals
class MysticRitualTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  const MysticRitualTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return MysticTextField(
      controller: controller,
      hintText: hintText,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      autofocus: autofocus,
      focusNode: focusNode,
      textStyle: AppTypography.displaySmall.copyWith(
        color: AppColors.textPrimary,
        letterSpacing: 3,
      ),
    );
  }
}
