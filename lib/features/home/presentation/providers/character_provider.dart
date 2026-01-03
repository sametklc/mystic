import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/character_data.dart';
import '../../domain/models/character_model.dart';

/// SharedPreferences key for selected guide
const String _selectedGuideKey = 'selected_guide_id';

/// Default character ID if none is saved
const String _defaultCharacterId = 'madame_luna';

/// Provider for the list of all available characters.
final charactersProvider = Provider<List<CharacterModel>>((ref) {
  return CharacterData.characters;
});

/// Notifier for managing selected character with persistence.
class SelectedCharacterNotifier extends StateNotifier<int> {
  final List<CharacterModel> _characters;
  bool _initialized = false;

  SelectedCharacterNotifier(this._characters) : super(0) {
    _loadSavedCharacter();
  }

  /// Load saved character ID from SharedPreferences
  Future<void> _loadSavedCharacter() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_selectedGuideKey);

      if (savedId != null) {
        // Find index of saved character
        final index = _characters.indexWhere((c) => c.id == savedId);
        if (index >= 0) {
          state = index;
          print('Guide: Loaded saved guide "$savedId" at index $index');
        } else {
          // Saved character not found, use default
          print('Guide: Saved guide "$savedId" not found, using default');
          await _setDefaultCharacter(prefs);
        }
      } else {
        // No saved character, use default
        print('Guide: No saved guide, using default "$_defaultCharacterId"');
        await _setDefaultCharacter(prefs);
      }
    } catch (e) {
      print('Error loading saved guide: $e');
    }

    _initialized = true;
  }

  /// Set default character
  Future<void> _setDefaultCharacter(SharedPreferences prefs) async {
    final defaultIndex = _characters.indexWhere((c) => c.id == _defaultCharacterId);
    if (defaultIndex >= 0) {
      state = defaultIndex;
      await prefs.setString(_selectedGuideKey, _defaultCharacterId);
    }
  }

  /// Select a character by index and persist the choice
  Future<void> selectCharacter(int index) async {
    if (index < 0 || index >= _characters.length) return;

    state = index;

    try {
      final prefs = await SharedPreferences.getInstance();
      final characterId = _characters[index].id;
      await prefs.setString(_selectedGuideKey, characterId);
      print('Guide: Saved selected guide "$characterId"');
    } catch (e) {
      print('Error saving selected guide: $e');
    }
  }

  /// Select a character by ID and persist the choice
  Future<void> selectCharacterById(String id) async {
    final index = _characters.indexWhere((c) => c.id == id);
    if (index >= 0) {
      await selectCharacter(index);
    }
  }

  /// Get the currently selected character
  CharacterModel get selectedCharacter => _characters[state];

  /// Get the current character ID
  String get selectedCharacterId => _characters[state].id;
}

/// Provider for tracking the currently selected character index with persistence.
final selectedCharacterIndexProvider =
    StateNotifierProvider<SelectedCharacterNotifier, int>((ref) {
  final characters = ref.watch(charactersProvider);
  return SelectedCharacterNotifier(characters);
});

/// Provider that returns the currently selected character.
final selectedCharacterProvider = Provider<CharacterModel>((ref) {
  final characters = ref.watch(charactersProvider);
  final index = ref.watch(selectedCharacterIndexProvider);
  return characters[index];
});

/// Provider for just the selected character ID (useful for API calls)
final selectedCharacterIdProvider = Provider<String>((ref) {
  final character = ref.watch(selectedCharacterProvider);
  return character.id;
});
