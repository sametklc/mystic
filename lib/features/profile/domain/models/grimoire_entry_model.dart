/// Model representing a single entry in the user's Grimoire (reading history).
class GrimoireEntryModel {
  final String id;
  final DateTime date;
  final String question;
  final String cardName;
  final bool isUpright;
  final String interpretation;
  final String? imageUrl;
  final String? moonPhase;
  final String characterId;

  const GrimoireEntryModel({
    required this.id,
    required this.date,
    required this.question,
    required this.cardName,
    required this.isUpright,
    required this.interpretation,
    this.imageUrl,
    this.moonPhase,
    this.characterId = 'madame_luna',
  });

  factory GrimoireEntryModel.fromJson(Map<String, dynamic> json) {
    return GrimoireEntryModel(
      id: json['id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      question: json['question'] as String? ?? '',
      cardName: json['card_name'] as String? ?? json['cardName'] as String? ?? '',
      isUpright: json['is_upright'] as bool? ?? json['isUpright'] as bool? ?? true,
      interpretation: json['interpretation'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      moonPhase: json['moon_phase'] as String? ?? json['moonPhase'] as String?,
      characterId: json['character_id'] as String? ?? 'madame_luna',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'question': question,
      'card_name': cardName,
      'is_upright': isUpright,
      'interpretation': interpretation,
      'image_url': imageUrl,
      'moon_phase': moonPhase,
      'character_id': characterId,
    };
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String get questionPreview {
    if (question.length <= 40) return question;
    return '${question.substring(0, 40)}...';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GrimoireEntryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Model for gallery art items.
class GalleryArtModel {
  final String id;
  final String imageUrl;
  final String cardName;
  final DateTime createdAt;
  final String? prompt;

  const GalleryArtModel({
    required this.id,
    required this.imageUrl,
    required this.cardName,
    required this.createdAt,
    this.prompt,
  });

  factory GalleryArtModel.fromGrimoireEntry(GrimoireEntryModel entry) {
    return GalleryArtModel(
      id: entry.id,
      imageUrl: entry.imageUrl!,
      cardName: entry.cardName,
      createdAt: entry.date,
    );
  }
}
