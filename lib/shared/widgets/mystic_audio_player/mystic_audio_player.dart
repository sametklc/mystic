import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/audio_player_service.dart';

/// A mystical audio player widget with animated waveform visualization.
class MysticAudioPlayer extends ConsumerStatefulWidget {
  /// Text to be spoken.
  final String text;

  /// Character ID for voice selection.
  final String characterId;

  /// Whether to auto-play when widget is built.
  final bool autoPlay;

  /// Callback when playback starts.
  final VoidCallback? onPlayStart;

  /// Callback when playback ends.
  final VoidCallback? onPlayEnd;

  /// Callback when an error occurs.
  final void Function(String error)? onError;

  /// Whether to show in compact mode.
  final bool compact;

  const MysticAudioPlayer({
    super.key,
    required this.text,
    this.characterId = 'madame_luna',
    this.autoPlay = false,
    this.onPlayStart,
    this.onPlayEnd,
    this.onError,
    this.compact = false,
  });

  @override
  ConsumerState<MysticAudioPlayer> createState() => _MysticAudioPlayerState();
}

class _MysticAudioPlayerState extends ConsumerState<MysticAudioPlayer>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _glowController;

  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startPlayback();
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startPlayback() {
    if (_hasStarted) return;
    _hasStarted = true;

    HapticFeedback.lightImpact();
    widget.onPlayStart?.call();

    ref.read(audioPlayerProvider.notifier).speak(
          text: widget.text,
          characterId: widget.characterId,
        );
  }

  void _togglePlayPause() {
    final state = ref.read(audioPlayerProvider);

    if (state.status == AudioPlayerStatus.initial) {
      _startPlayback();
    } else {
      HapticFeedback.selectionClick();
      ref.read(audioPlayerProvider.notifier).togglePlayPause();
    }
  }

  void _stop() {
    HapticFeedback.lightImpact();
    ref.read(audioPlayerProvider.notifier).stop();
    widget.onPlayEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);

    // Update wave animation based on playing state
    if (audioState.isPlaying) {
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      _waveController.stop();
    }

    // Handle completion callback
    if (audioState.isCompleted && _hasStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPlayEnd?.call();
      });
    }

    // Handle error callback
    if (audioState.hasError && audioState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onError?.call(audioState.errorMessage!);
      });
    }

    return widget.compact ? _buildCompactPlayer(audioState) : _buildFullPlayer(audioState);
  }

  Widget _buildFullPlayer(AudioPlayerState state) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = _glowController.value;

        return Container(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.1 + glowIntensity * 0.05),
                AppColors.glassFill,
              ],
            ),
            border: Border.all(
              color: state.isPlaying
                  ? AppColors.primary.withOpacity(0.4 + glowIntensity * 0.2)
                  : AppColors.glassBorder,
            ),
            boxShadow: state.isPlaying
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2 + glowIntensity * 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform visualization
              SizedBox(
                height: 60,
                child: _buildWaveform(state),
              ),

              const SizedBox(height: AppConstants.spacingSmall),

              // Progress bar
              _buildProgressBar(state),

              const SizedBox(height: AppConstants.spacingSmall),

              // Controls
              _buildControls(state),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildCompactPlayer(AudioPlayerState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
        vertical: AppConstants.spacingSmall,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
        color: AppColors.glassFill,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _buildPlayButton(state, size: 36),

          const SizedBox(width: AppConstants.spacingSmall),

          // Mini waveform
          SizedBox(
            width: 80,
            height: 30,
            child: _buildWaveform(state),
          ),

          if (state.isPlaying || state.isPaused) ...[
            const SizedBox(width: AppConstants.spacingSmall),

            // Time
            Text(
              _formatDuration(state.position),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaveform(AudioPlayerState state) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaveformPainter(
            progress: state.progress,
            animationValue: _waveController.value,
            isPlaying: state.isPlaying,
            primaryColor: AppColors.primary,
            secondaryColor: AppColors.secondary,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildProgressBar(AudioPlayerState state) {
    return Column(
      children: [
        // Progress slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withOpacity(0.2),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
          ),
          child: Slider(
            value: state.progress.clamp(0.0, 1.0),
            onChanged: (value) {
              if (state.duration.inMilliseconds > 0) {
                final position = Duration(
                  milliseconds: (value * state.duration.inMilliseconds).toInt(),
                );
                ref.read(audioPlayerProvider.notifier).seek(position);
              }
            },
          ),
        ),

        // Time display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                _formatDuration(state.duration),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(AudioPlayerState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Stop button
        if (state.isPlaying || state.isPaused)
          IconButton(
            onPressed: _stop,
            icon: Icon(
              Icons.stop_rounded,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ),

        const SizedBox(width: AppConstants.spacingMedium),

        // Play/Pause button
        _buildPlayButton(state),

        const SizedBox(width: AppConstants.spacingMedium),

        // Replay button (when completed)
        if (state.isCompleted)
          IconButton(
            onPressed: () {
              _hasStarted = false;
              _startPlayback();
            },
            icon: Icon(
              Icons.replay_rounded,
              color: AppColors.textSecondary,
              size: 28,
            ),
          )
        else
          const SizedBox(width: 48), // Placeholder for balance
      ],
    );
  }

  Widget _buildPlayButton(AudioPlayerState state, {double size = 56}) {
    final isLoading = state.isLoading;
    final isPlaying = state.isPlaying;

    return GestureDetector(
      onTap: isLoading ? null : _togglePlayPause,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: size * 0.5,
                ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Custom painter for the waveform visualization.
class _WaveformPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final bool isPlaying;
  final Color primaryColor;
  final Color secondaryColor;

  _WaveformPainter({
    required this.progress,
    required this.animationValue,
    required this.isPlaying,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 40;
    final barWidth = size.width / barCount - 2;
    final maxHeight = size.height * 0.8;
    final random = math.Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < barCount; i++) {
      // Calculate bar position
      final x = i * (barWidth + 2) + barWidth / 2;
      final barProgress = i / barCount;

      // Base height with some randomness
      double baseHeight = 0.3 + random.nextDouble() * 0.4;

      // Add wave animation when playing
      if (isPlaying) {
        final waveOffset = math.sin(
          (animationValue * 2 * math.pi) + (i * 0.3),
        );
        baseHeight += waveOffset * 0.3;
      }

      final height = maxHeight * baseHeight.clamp(0.1, 1.0);

      // Determine if this bar is in the played portion
      final isPlayed = barProgress <= progress;

      // Create gradient paint
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: isPlayed
              ? [primaryColor, secondaryColor]
              : [
                  primaryColor.withOpacity(0.3),
                  secondaryColor.withOpacity(0.2),
                ],
        ).createShader(
          Rect.fromLTWH(x - barWidth / 2, size.height / 2 - height / 2, barWidth, height),
        )
        ..style = PaintingStyle.fill;

      // Draw bar (centered vertically)
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: barWidth,
          height: height,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);

      // Add glow effect for playing bars
      if (isPlaying && isPlayed) {
        final glowPaint = Paint()
          ..color = primaryColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

/// A simple "Listen" button that triggers TTS playback.
class ListenButton extends ConsumerWidget {
  final String text;
  final String characterId;
  final VoidCallback? onPlayStart;
  final VoidCallback? onPlayEnd;

  const ListenButton({
    super.key,
    required this.text,
    this.characterId = 'madame_luna',
    this.onPlayStart,
    this.onPlayEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final isPlaying = audioState.isPlaying;
    final isLoading = audioState.isLoading;

    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              if (isPlaying) {
                ref.read(audioPlayerProvider.notifier).stop();
                onPlayEnd?.call();
              } else {
                onPlayStart?.call();
                ref.read(audioPlayerProvider.notifier).speak(
                      text: text,
                      characterId: characterId,
                    );
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.2),
              AppColors.secondary.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            else
              Icon(
                isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            const SizedBox(width: 8),
            Text(
              isPlaying ? 'Stop' : 'Listen',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
