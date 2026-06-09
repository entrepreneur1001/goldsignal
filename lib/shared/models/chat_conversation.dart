// Models for persisted AI chat history.
//
// Stored as plain JSON maps in the existing `chatHistory` Hive box (mirrors the
// `PriceAlert` / `userAlerts` pattern — no TypeAdapters or codegen).

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  /// Short preview of the last message, for the history list.
  String get preview {
    if (messages.isEmpty) return '';
    final last = messages.last.text.replaceAll('\n', ' ').trim();
    return last.length > 80 ? '${last.substring(0, 80)}…' : last;
  }

  /// Derive a title from the first user message (fallback to "New chat").
  static String titleFromMessages(List<ChatMessage> messages) {
    final firstUser = messages.where((m) => m.isUser).cast<ChatMessage?>().firstWhere(
          (m) => m != null && m.text.trim().isNotEmpty,
          orElse: () => null,
        );
    final raw = firstUser?.text.replaceAll('\n', ' ').trim();
    if (raw == null || raw.isEmpty) return 'New chat';
    return raw.length > 40 ? '${raw.substring(0, 40)}…' : raw;
  }

  ChatConversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List?) ?? const [];
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New chat',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
