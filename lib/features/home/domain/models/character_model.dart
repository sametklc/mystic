import 'package:flutter/material.dart';

/// Represents a tarot reader character that users can select.
/// Designed to be Firestore-compatible with JSON serialization.
@immutable
class CharacterModel {
  /// Unique identifier for the character.
  final String id;

  /// Display name of the character.
  final String name;

  /// Title/archetype (e.g., "The Mystic", "The Ancient Sage").
  final String title;

  /// Brief description of the character's personality and focus.
  final String description;

  /// Path to the character's image asset.
  final String imagePath;

  /// Whether this character requires unlocking (purchase/premium).
  final bool isLocked;

  /// Theme color stored as hex string for Firestore compatibility.
  final String themeColorHex;

  const CharacterModel({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.isLocked,
    required this.themeColorHex,
  });

  /// Converts hex color string to Flutter Color object.
  Color get themeColor {
    final hex = themeColorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Creates a CharacterModel from Firestore document data.
  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String,
      isLocked: json['isLocked'] as bool,
      themeColorHex: json['themeColorHex'] as String,
    );
  }

  /// Converts the model to a Map for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'isLocked': isLocked,
      'themeColorHex': themeColorHex,
    };
  }

  /// Creates a copy with optional overrides.
  CharacterModel copyWith({
    String? id,
    String? name,
    String? title,
    String? description,
    String? imagePath,
    bool? isLocked,
    String? themeColorHex,
  }) {
    return CharacterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      isLocked: isLocked ?? this.isLocked,
      themeColorHex: themeColorHex ?? this.themeColorHex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharacterModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
