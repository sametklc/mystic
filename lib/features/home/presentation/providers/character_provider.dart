import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_data.dart';
import '../../domain/models/character_model.dart';

/// Provider for the list of all available characters.
final charactersProvider = Provider<List<CharacterModel>>((ref) {
  return CharacterData.characters;
});

/// Provider for tracking the currently selected character index.
final selectedCharacterIndexProvider = StateProvider<int>((ref) => 0);

/// Provider that returns the currently selected character.
final selectedCharacterProvider = Provider<CharacterModel>((ref) {
  final characters = ref.watch(charactersProvider);
  final index = ref.watch(selectedCharacterIndexProvider);
  return characters[index];
});
