import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/location_service.dart';

/// Callback when a location is selected.
typedef OnLocationSelected = void Function(
  double latitude,
  double longitude,
  String placeName,
  String? timezone,
);

/// A mystical-themed location search field with autocomplete suggestions.
///
/// Uses OpenMeteo Geocoding API to fetch location suggestions as the user types.
/// Returns latitude, longitude, and formatted place name when a location is selected.
class MysticLocationSearchField extends StatefulWidget {
  /// Callback when a location is selected from suggestions
  final OnLocationSelected onLocationSelected;

  /// Initial value to display (e.g., "Istanbul, Turkey")
  final String? initialValue;

  /// Initial latitude (for pre-filling)
  final double? initialLatitude;

  /// Initial longitude (for pre-filling)
  final double? initialLongitude;

  /// Label text above the field
  final String label;

  /// Placeholder text when empty
  final String placeholder;

  /// Whether the field is enabled
  final bool enabled;

  const MysticLocationSearchField({
    super.key,
    required this.onLocationSelected,
    this.initialValue,
    this.initialLatitude,
    this.initialLongitude,
    this.label = 'Birth Place',
    this.placeholder = 'Search city...',
    this.enabled = true,
  });

  @override
  State<MysticLocationSearchField> createState() => _MysticLocationSearchFieldState();
}

class _MysticLocationSearchFieldState extends State<MysticLocationSearchField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final LocationService _locationService = LocationService();

  List<LocationSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;
  LocationSuggestion? _selectedLocation;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    // Register for keyboard/metrics changes
    WidgetsBinding.instance.addObserver(this);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Set initial value if provided
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }

    // Listen to focus changes
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    _glowController.dispose();
    _locationService.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Called when keyboard appears/disappears
    // Rebuild overlay to reposition suggestions
    if (_showSuggestions && _overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay hiding to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideSuggestions();
        }
      });
    }
    setState(() {});
  }

  void _onSearchChanged(String query) {
    if (query.trim().length < 2) {
      _hideSuggestions();
      return;
    }

    setState(() => _isLoading = true);

    _locationService.searchWithDebounce(
      query,
      debounceMs: 400,
      onResults: (results) {
        if (mounted) {
          setState(() {
            _suggestions = results;
            _isLoading = false;
          });
          if (results.isNotEmpty) {
            _showSuggestionsOverlay();
          } else {
            _hideSuggestions();
          }
        }
      },
    );
  }

  void _onSuggestionSelected(LocationSuggestion suggestion) {
    HapticFeedback.selectionClick();

    setState(() {
      _selectedLocation = suggestion;
      _controller.text = suggestion.shortName;
    });

    _hideSuggestions();
    _focusNode.unfocus();

    // Trigger callback
    widget.onLocationSelected(
      suggestion.latitude,
      suggestion.longitude,
      suggestion.shortName,
      suggestion.timezone,
    );
  }

  void _showSuggestionsOverlay() {
    if (_showSuggestions) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showSuggestions = true);
  }

  void _hideSuggestions() {
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        // Calculate position inside builder so it updates with keyboard changes
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.attached) {
          return const SizedBox.shrink();
        }

        final size = renderBox.size;
        final position = renderBox.localToGlobal(Offset.zero);

        // Get screen height and keyboard height from the main context
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final availableSpaceBelow = screenHeight - position.dy - size.height - keyboardHeight - 20;

        // If not enough space below (keyboard open), show above the text field
        const suggestionsHeight = 250.0;
        final showAbove = availableSpaceBelow < suggestionsHeight && keyboardHeight > 50;

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // If showing above, offset by negative (suggestions height + gap)
            // If showing below, offset by field height + gap
            offset: showAbove
                ? Offset(0, -(suggestionsHeight + 4))
                : Offset(0, size.height + 4),
            child: Material(
              color: Colors.transparent,
              child: _buildSuggestionsList(showAbove: showAbove),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionsList({bool showAbove = false}) {
    if (_suggestions.isEmpty && !_isLoading) {
      return const SizedBox.shrink();
    }

    final content = Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Reverse order when showing above so newest items are at bottom (closer to input)
          verticalDirection: showAbove ? VerticalDirection.up : VerticalDirection.down,
          children: [
            // Loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMedium),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Searching...',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Suggestions list
            if (!_isLoading && _suggestions.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  reverse: showAbove, // Reverse scroll when showing above
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return _buildSuggestionTile(suggestion, index);
                  },
                ),
              ),
          ],
        ),
      ),
    );

    // When showing above, align to bottom of the available space
    if (showAbove) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [content],
      );
    }

    return content;
  }

  Widget _buildSuggestionTile(LocationSuggestion suggestion, int index) {
    return InkWell(
      onTap: () => _onSuggestionSelected(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMedium,
          vertical: AppConstants.spacingSmall + 4,
        ),
        decoration: BoxDecoration(
          border: index < _suggestions.length - 1
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.glassBorder.withOpacity(0.5),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // Location icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: Icon(
                Icons.location_on,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Location details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    suggestion.admin1 != null
                        ? '${suggestion.admin1}, ${suggestion.country}'
                        : suggestion.country,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Coordinates hint
            Text(
              '${suggestion.latitude.toStringAsFixed(2)}°',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update overlay when suggestions change
    if (_showSuggestions && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }

    final hasValue = _selectedLocation != null || _controller.text.isNotEmpty;
    final isFocused = _focusNode.hasFocus;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),

          // Text field
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowOpacity = hasValue ? 0.1 + _glowController.value * 0.1 : 0.0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  border: Border.all(
                    color: isFocused
                        ? AppColors.primary.withOpacity(0.7)
                        : hasValue
                            ? AppColors.primary.withOpacity(0.4)
                            : AppColors.glassBorder,
                    width: isFocused || hasValue ? 1.5 : 1,
                  ),
                  boxShadow: hasValue || isFocused
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(glowOpacity),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: _onSearchChanged,
                  // Push the field higher when keyboard opens to leave room for suggestions
                  scrollPadding: const EdgeInsets.only(bottom: 280),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textTertiary.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: hasValue || isFocused
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 22,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _selectedLocation = null);
                              _hideSuggestions();
                            },
                          )
                        : _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.primary.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMedium,
                      vertical: AppConstants.spacingMedium,
                    ),
                  ),
                  onSubmitted: (_) {
                    _focusNode.unfocus();
                    _hideSuggestions();
                  },
                ),
              );
            },
          ),

          // Selected coordinates hint
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
