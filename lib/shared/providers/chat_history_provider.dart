import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/chat_history_service.dart';
import '../models/chat_conversation.dart';

final chatHistoryServiceProvider = Provider<ChatHistoryService>((ref) {
  return ChatHistoryService();
});

class ChatHistoryState {
  final List<ChatConversation> conversations;

  /// Id of the conversation currently shown in the chat screen.
  /// Null means a fresh chat that hasn't been persisted yet (no messages).
  final String? activeId;

  const ChatHistoryState({
    this.conversations = const [],
    this.activeId,
  });

  ChatConversation? get activeConversation {
    if (activeId == null) return null;
    for (final c in conversations) {
      if (c.id == activeId) return c;
    }
    return null;
  }

  List<ChatMessage> get activeMessages => activeConversation?.messages ?? const [];

  ChatHistoryState copyWith({
    List<ChatConversation>? conversations,
    String? activeId,
    bool clearActive = false,
  }) {
    return ChatHistoryState(
      conversations: conversations ?? this.conversations,
      activeId: clearActive ? null : (activeId ?? this.activeId),
    );
  }
}

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, ChatHistoryState>(() {
  return ChatHistoryNotifier();
});

class ChatHistoryNotifier extends Notifier<ChatHistoryState> {
  ChatHistoryService get _service => ref.read(chatHistoryServiceProvider);

  @override
  ChatHistoryState build() {
    return ChatHistoryState(conversations: _service.getAll());
  }

  void _reload({String? activeId, bool clearActive = false}) {
    state = ChatHistoryState(
      conversations: _service.getAll(),
      activeId: clearActive ? null : (activeId ?? state.activeId),
    );
  }

  /// Start a fresh chat. The conversation is created lazily once the first
  /// message is appended, so prior chats stay untouched in history.
  void startNewChat() {
    state = state.copyWith(clearActive: true);
  }

  void setActive(String id) {
    state = state.copyWith(activeId: id);
  }

  /// Append a message to the active conversation, creating it on first use.
  Future<void> appendMessage(ChatMessage message) async {
    final now = message.timestamp;
    final existing = state.activeConversation;

    if (existing == null) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final messages = [message];
      final conversation = ChatConversation(
        id: id,
        title: ChatConversation.titleFromMessages(messages),
        createdAt: now,
        updatedAt: now,
        messages: messages,
      );
      await _service.save(conversation);
      _reload(activeId: id);
      return;
    }

    final messages = [...existing.messages, message];
    final title = existing.title == 'New chat'
        ? ChatConversation.titleFromMessages(messages)
        : existing.title;
    final updated = existing.copyWith(
      title: title,
      messages: messages,
      updatedAt: now,
    );
    await _service.save(updated);
    _reload();
  }

  Future<void> rename(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final conversation = _service.getById(id);
    if (conversation == null) return;
    await _service.save(conversation.copyWith(title: trimmed));
    _reload();
  }

  Future<void> deleteConversation(String id) async {
    await _service.delete(id);
    if (state.activeId == id) {
      _reload(clearActive: true);
    } else {
      _reload();
    }
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _reload(clearActive: true);
  }
}
