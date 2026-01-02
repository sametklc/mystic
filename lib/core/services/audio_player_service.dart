import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'tts_service.dart';

/// Audio player states.
enum AudioPlayerStatus {
  /// Initial state, no audio loaded.
  initial,

  /// Loading audio from network or file.
  loading,

  /// Audio is playing.
  playing,

  /// Audio is paused.
  paused,

  /// Audio playback completed.
  completed,

  /// Error occurred.
  error,
}

/// State for the audio player.
class AudioPlayerState {
  final AudioPlayerStatus status;
  final String? currentText;
  final String? characterId;
  final double progress;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  const AudioPlayerState({
    this.status = AudioPlayerStatus.initial,
    this.currentText,
    this.characterId,
    this.progress = 0.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  factory AudioPlayerState.initial() => const AudioPlayerState();

  factory AudioPlayerState.loading({String? text, String? characterId}) =>
      AudioPlayerState(
        status: AudioPlayerStatus.loading,
        currentText: text,
        characterId: characterId,
      );

  factory AudioPlayerState.playing({
    required Duration position,
    required Duration duration,
    String? text,
    String? characterId,
  }) =>
      AudioPlayerState(
        status: AudioPlayerStatus.playing,
        currentText: text,
        characterId: characterId,
        position: position,
        duration: duration,
        progress: duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0,
      );

  factory AudioPlayerState.paused({
    required Duration position,
    required Duration duration,
    String? text,
    String? characterId,
  }) =>
      AudioPlayerState(
        status: AudioPlayerStatus.paused,
        currentText: text,
        characterId: characterId,
        position: position,
        duration: duration,
        progress: duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0,
      );

  factory AudioPlayerState.completed({String? text, String? characterId}) =>
      AudioPlayerState(
        status: AudioPlayerStatus.completed,
        currentText: text,
        characterId: characterId,
        progress: 1.0,
      );

  factory AudioPlayerState.error(String message) => AudioPlayerState(
        status: AudioPlayerStatus.error,
        errorMessage: message,
      );

  bool get isPlaying => status == AudioPlayerStatus.playing;
  bool get isPaused => status == AudioPlayerStatus.paused;
  bool get isLoading => status == AudioPlayerStatus.loading;
  bool get hasError => status == AudioPlayerStatus.error;
  bool get isCompleted => status == AudioPlayerStatus.completed;
  bool get canPlay =>
      status == AudioPlayerStatus.paused ||
      status == AudioPlayerStatus.completed;

  AudioPlayerState copyWith({
    AudioPlayerStatus? status,
    String? currentText,
    String? characterId,
    double? progress,
    Duration? position,
    Duration? duration,
    String? errorMessage,
  }) {
    return AudioPlayerState(
      status: status ?? this.status,
      currentText: currentText ?? this.currentText,
      characterId: characterId ?? this.characterId,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for managing audio player state.
class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final TTSService _ttsService;
  final AudioPlayer _player;

  AudioPlayerNotifier(this._ttsService)
      : _player = AudioPlayer(),
        super(AudioPlayerState.initial()) {
    _initPlayerListeners();
  }

  void _initPlayerListeners() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = AudioPlayerState.completed(
          text: state.currentText,
          characterId: state.characterId,
        );
      }
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      if (state.isPlaying) {
        final duration = _player.duration ?? Duration.zero;
        state = AudioPlayerState.playing(
          position: position,
          duration: duration,
          text: state.currentText,
          characterId: state.characterId,
        );
      }
    });

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      if (duration != null && state.isPlaying) {
        state = state.copyWith(duration: duration);
      }
    });
  }

  /// Speak the given text using TTS.
  Future<void> speak({
    required String text,
    String characterId = 'madame_luna',
  }) async {
    // If currently playing, stop first
    if (state.isPlaying) {
      await stop();
    }

    state = AudioPlayerState.loading(
      text: text,
      characterId: characterId,
    );

    try {
      // Synthesize speech and get file path
      final audioPath = await _ttsService.synthesizeSpeech(
        text: text,
        characterId: characterId,
      );

      if (audioPath == null) {
        throw TTSException('Failed to generate audio');
      }

      // Load and play
      await _player.setFilePath(audioPath);
      await _player.play();

      final duration = _player.duration ?? Duration.zero;
      state = AudioPlayerState.playing(
        position: Duration.zero,
        duration: duration,
        text: text,
        characterId: characterId,
      );
    } catch (e) {
      print('Audio playback error: $e');
      state = AudioPlayerState.error(
        e is TTSException ? e.message : 'Failed to play audio',
      );
    }
  }

  /// Play audio from a URL.
  Future<void> playFromUrl(String url, {String? text, String? characterId}) async {
    if (state.isPlaying) {
      await stop();
    }

    state = AudioPlayerState.loading(text: text, characterId: characterId);

    try {
      await _player.setUrl(url);
      await _player.play();

      final duration = _player.duration ?? Duration.zero;
      state = AudioPlayerState.playing(
        position: Duration.zero,
        duration: duration,
        text: text,
        characterId: characterId,
      );
    } catch (e) {
      print('Audio URL playback error: $e');
      state = AudioPlayerState.error('Failed to play audio from URL');
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    if (!state.isPlaying) return;

    await _player.pause();
    state = AudioPlayerState.paused(
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      text: state.currentText,
      characterId: state.characterId,
    );
  }

  /// Resume playback.
  Future<void> resume() async {
    if (!state.isPaused && !state.isCompleted) return;

    await _player.play();

    final duration = _player.duration ?? Duration.zero;
    state = AudioPlayerState.playing(
      position: _player.position,
      duration: duration,
      text: state.currentText,
      characterId: state.characterId,
    );
  }

  /// Stop playback and reset.
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    state = AudioPlayerState.initial();
  }

  /// Seek to a specific position.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Toggle play/pause.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else if (state.isPaused || state.isCompleted) {
      if (state.isCompleted) {
        await _player.seek(Duration.zero);
      }
      await resume();
    }
  }

  /// Clear error state.
  void clearError() {
    if (state.hasError) {
      state = AudioPlayerState.initial();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// Provider for the audio player state.
final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  final ttsService = ref.watch(ttsServiceProvider);
  return AudioPlayerNotifier(ttsService);
});

/// Provider for checking if audio is currently playing.
final isAudioPlayingProvider = Provider<bool>((ref) {
  return ref.watch(audioPlayerProvider).isPlaying;
});

/// Provider for audio progress (0.0 to 1.0).
final audioProgressProvider = Provider<double>((ref) {
  return ref.watch(audioPlayerProvider).progress;
});
