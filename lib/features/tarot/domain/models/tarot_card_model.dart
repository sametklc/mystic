/// Model representing a single Tarot card in a reading.
class TarotCardModel {
  final String name;
  final String meaning;
  final String imageUrl;
  final bool isUpright;

  const TarotCardModel({
    required this.name,
    required this.meaning,
    required this.imageUrl,
    required this.isUpright,
  });

  /// Creates a copy with optional field overrides.
  TarotCardModel copyWith({
    String? name,
    String? meaning,
    String? imageUrl,
    bool? isUpright,
  }) {
    return TarotCardModel(
      name: name ?? this.name,
      meaning: meaning ?? this.meaning,
      imageUrl: imageUrl ?? this.imageUrl,
      isUpright: isUpright ?? this.isUpright,
    );
  }

  /// Creates a TarotCardModel from JSON map.
  factory TarotCardModel.fromJson(Map<String, dynamic> json) {
    return TarotCardModel(
      name: json['name'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
      isUpright: json['is_upright'] as bool? ?? json['isUpright'] as bool? ?? true,
    );
  }

  /// Converts the model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'meaning': meaning,
      'image_url': imageUrl,
      'is_upright': isUpright,
    };
  }

  /// Returns the orientation text in Turkish.
  String get orientationText => isUpright ? 'Düz' : 'Ters';

  @override
  String toString() {
    return 'TarotCardModel(name: $name, isUpright: $isUpright)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TarotCardModel &&
        other.name == name &&
        other.meaning == meaning &&
        other.imageUrl == imageUrl &&
        other.isUpright == isUpright;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        meaning.hashCode ^
        imageUrl.hashCode ^
        isUpright.hashCode;
  }
}
