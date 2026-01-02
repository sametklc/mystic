import 'tarot_card_model.dart';

/// Model representing a complete Tarot reading session.
class TarotReadingModel {
  final String id;
  final String question;
  final List<TarotCardModel> cards;
  final String interpretation;
  final DateTime createdAt;
  final String? imageUrl; // AI-generated image URL from Replicate

  const TarotReadingModel({
    required this.id,
    required this.question,
    required this.cards,
    required this.interpretation,
    required this.createdAt,
    this.imageUrl,
  });

  /// Creates a copy with optional field overrides.
  TarotReadingModel copyWith({
    String? id,
    String? question,
    List<TarotCardModel>? cards,
    String? interpretation,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return TarotReadingModel(
      id: id ?? this.id,
      question: question ?? this.question,
      cards: cards ?? this.cards,
      interpretation: interpretation ?? this.interpretation,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Creates a TarotReadingModel from JSON map.
  factory TarotReadingModel.fromJson(Map<String, dynamic> json) {
    // Parse cards list
    final cardsJson = json['cards'] as List<dynamic>? ?? [];
    final cards = cardsJson
        .map((cardJson) => TarotCardModel.fromJson(cardJson as Map<String, dynamic>))
        .toList();

    // Parse created_at with fallback
    DateTime createdAt;
    final createdAtValue = json['created_at'] ?? json['createdAt'];
    if (createdAtValue is String) {
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    } else if (createdAtValue is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
    } else {
      createdAt = DateTime.now();
    }

    return TarotReadingModel(
      id: json['id'] as String? ?? json['reading_id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      cards: cards,
      interpretation: json['interpretation'] as String? ?? json['reading'] as String? ?? '',
      createdAt: createdAt,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
    );
  }

  /// Converts the model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'cards': cards.map((card) => card.toJson()).toList(),
      'interpretation': interpretation,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  /// Returns true if the reading has an AI-generated image.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Returns the primary card (first card in spread).
  TarotCardModel? get primaryCard => cards.isNotEmpty ? cards.first : null;

  /// Returns the number of cards in this reading.
  int get cardCount => cards.length;

  @override
  String toString() {
    return 'TarotReadingModel(id: $id, question: $question, cards: ${cards.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TarotReadingModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
