/// Model representing a single chat message in the Oracle conversation.
class ChatMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? characterId;

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.characterId,
  });

  factory ChatMessageModel.user({
    required String text,
    String? id,
  }) {
    return ChatMessageModel(
      id: id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessageModel.oracle({
    required String text,
    required String characterId,
    String? id,
  }) {
    return ChatMessageModel(
      id: id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      characterId: characterId,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? json['message'] as String? ?? '',
      isUser: json['is_user'] as bool? ?? json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      characterId: json['character_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'character_id': characterId,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? characterId,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      characterId: characterId ?? this.characterId,
    );
  }

  @override
  String toString() => 'ChatMessageModel(id: $id, isUser: $isUser, text: ${text.substring(0, text.length > 30 ? 30 : text.length)}...)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatMessageModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
