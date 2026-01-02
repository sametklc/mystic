import 'dart:async';
import 'package:flutter/material.dart';

/// A text widget that reveals text character by character like a typewriter.
class TypewriterText extends StatefulWidget {
  /// The full text to display.
  final String text;

  /// Text style to apply.
  final TextStyle? style;

  /// Delay between each character.
  final Duration characterDelay;

  /// Initial delay before starting.
  final Duration initialDelay;

  /// Text alignment.
  final TextAlign textAlign;

  /// Callback when typing is complete.
  final VoidCallback? onComplete;

  /// Whether to start the animation.
  final bool animate;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.characterDelay = const Duration(milliseconds: 30),
    this.initialDelay = Duration.zero,
    this.textAlign = TextAlign.left,
    this.onComplete,
    this.animate = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _startTyping();
    } else {
      _displayedText = widget.text;
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _resetAndStart();
    } else if (widget.animate && !oldWidget.animate) {
      _startTyping();
    }
  }

  void _resetAndStart() {
    _timer?.cancel();
    _currentIndex = 0;
    _displayedText = '';
    _hasStarted = false;
    if (widget.animate) {
      _startTyping();
    }
  }

  void _startTyping() {
    if (_hasStarted) return;
    _hasStarted = true;

    Future.delayed(widget.initialDelay, () {
      if (!mounted) return;
      _typeNextCharacter();
    });
  }

  void _typeNextCharacter() {
    if (!mounted) return;
    if (_currentIndex >= widget.text.length) {
      widget.onComplete?.call();
      return;
    }

    setState(() {
      _displayedText = widget.text.substring(0, _currentIndex + 1);
      _currentIndex++;
    });

    _timer = Timer(widget.characterDelay, _typeNextCharacter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}

/// A rich text widget that reveals text with typewriter effect,
/// supporting different styling for sections.
class TypewriterRichText extends StatefulWidget {
  /// The full text to display.
  final String text;

  /// Base text style.
  final TextStyle? style;

  /// Delay between each character.
  final Duration characterDelay;

  /// Initial delay before starting.
  final Duration initialDelay;

  /// Text alignment.
  final TextAlign textAlign;

  /// Callback when typing is complete.
  final VoidCallback? onComplete;

  /// Whether to start the animation.
  final bool animate;

  /// Cursor character to show at end while typing.
  final String cursor;

  /// Whether to show blinking cursor.
  final bool showCursor;

  const TypewriterRichText({
    super.key,
    required this.text,
    this.style,
    this.characterDelay = const Duration(milliseconds: 30),
    this.initialDelay = Duration.zero,
    this.textAlign = TextAlign.left,
    this.onComplete,
    this.animate = true,
    this.cursor = '▌',
    this.showCursor = true,
  });

  @override
  State<TypewriterRichText> createState() => _TypewriterRichTextState();
}

class _TypewriterRichTextState extends State<TypewriterRichText>
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;
  bool _hasStarted = false;
  bool _isComplete = false;

  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    if (widget.animate) {
      _startTyping();
    } else {
      _displayedText = widget.text;
      _isComplete = true;
    }
  }

  @override
  void didUpdateWidget(TypewriterRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _resetAndStart();
    } else if (widget.animate && !oldWidget.animate) {
      _startTyping();
    }
  }

  void _resetAndStart() {
    _timer?.cancel();
    _currentIndex = 0;
    _displayedText = '';
    _hasStarted = false;
    _isComplete = false;
    if (widget.animate) {
      _startTyping();
    }
  }

  void _startTyping() {
    if (_hasStarted) return;
    _hasStarted = true;

    Future.delayed(widget.initialDelay, () {
      if (!mounted) return;
      _typeNextCharacter();
    });
  }

  void _typeNextCharacter() {
    if (!mounted) return;
    if (_currentIndex >= widget.text.length) {
      setState(() {
        _isComplete = true;
      });
      widget.onComplete?.call();
      return;
    }

    setState(() {
      _displayedText = widget.text.substring(0, _currentIndex + 1);
      _currentIndex++;
    });

    // Variable speed - pause longer on punctuation
    final char = widget.text[_currentIndex - 1];
    final delay = _getDelayForChar(char);

    _timer = Timer(delay, _typeNextCharacter);
  }

  Duration _getDelayForChar(String char) {
    if (char == '.' || char == '!' || char == '?') {
      return widget.characterDelay * 8;
    } else if (char == ',' || char == ';' || char == ':') {
      return widget.characterDelay * 4;
    } else if (char == ' ') {
      return widget.characterDelay * 2;
    }
    return widget.characterDelay;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _displayedText),
          if (widget.showCursor && !_isComplete)
            WidgetSpan(
              child: AnimatedBuilder(
                animation: _cursorController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _cursorController.value,
                    child: Text(
                      widget.cursor,
                      style: widget.style?.copyWith(
                        color: widget.style?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
