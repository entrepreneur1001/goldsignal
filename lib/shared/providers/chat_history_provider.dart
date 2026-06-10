import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_chat_history_service.dart';
import '../models/chat_conversation.dart';

final firestoreChatHistoryServiceProvider =
    Provider<FirestoreChatHistoryService>((ref) {
  return FirestoreChatHistoryService();
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

/// Stream-backed: conversations live in Firestore (offline cache included).
/// Mutations write to Firestore; the live subscription updates the list. The
/// active conversation id is ephemeral UI state kept locally.
class ChatHistoryNotifier extends Notifier<ChatHistoryState> {
  StreamSubscription<List<ChatConversation>>? _sub;

  FirestoreChatHistoryService get _cloud =>
      ref.read(firestoreChatHistoryServiceProvider);
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  ChatHistoryState build() {
    ref.onDispose(() => _sub?.cancel());
    _subscribe();
    return const ChatHistoryState();
  }

  void _subscribe() {
    _sub?.cancel();
    final uid = _uid;
    if (uid == null) {
      state = const ChatHistoryState();
      return;
    }
    _sub = _cloud.streamAll(uid).listen((conversations) {
      state = state.copyWith(conversations: conversations);
    });
  }

  Future<void> _save(ChatConversation conversation) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _cloud.saveConversation(uid, conversation);
    } catch (_) {}
  }

  Future<void> _delete(String id) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _cloud.deleteConversation(uid, id);
    } catch (_) {}
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
      // Set active immediately so the UI tracks the new chat; the stream will
      // deliver the persisted conversation (served from cache near-instantly).
      state = state.copyWith(activeId: id);
      await _save(conversation);
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
    await _save(updated);
  }

  Future<void> rename(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final conversation = _byId(id);
    if (conversation == null) return;
    await _save(conversation.copyWith(title: trimmed));
  }

  Future<void> deleteConversation(String id) async {
    await _delete(id);
    if (state.activeId == id) {
      state = state.copyWith(clearActive: true);
    }
  }

  Future<void> clearAll() async {
    final ids = state.conversations.map((c) => c.id).toList();
    for (final id in ids) {
      await _delete(id);
    }
    state = state.copyWith(clearActive: true);
  }

  ChatConversation? _byId(String id) {
    for (final c in state.conversations) {
      if (c.id == id) return c;
    }
    return null;
  }
}
