import 'package:flutter/material.dart';
import '../../../../shared/design/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/chat_conversation.dart';
import '../../../../shared/providers/chat_history_provider.dart';
import '../../../../shared/widgets/ad_list_builder.dart';
import '../../../../shared/widgets/empty_state_with_ad.dart';
import '../../../../shared/widgets/native_ad_widget.dart';
import 'package:easy_localization/easy_localization.dart';

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatHistoryProvider);
    final notifier = ref.read(chatHistoryProvider.notifier);
    final conversations = state.conversations;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('chat_history.title')),
        actions: [
          if (conversations.isNotEmpty)
            IconButton(
              tooltip: context.tr('chat_history.clear_all'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          notifier.startNewChat();
          Navigator.pop(context);
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(context.tr('chatbot.new_chat')),
      ),
      body: conversations.isEmpty
          ? _buildEmpty(context)
          : _buildList(conversations),
    );
  }

  Widget _buildList(List<ChatConversation> conversations) {
    final itemCount = adListItemCount(conversations.length);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (adListIndexIsAd(index, conversations.length)) {
          return const NativeAdWidget.list();
        }
        return _ConversationTile(
          conversation: conversations[adListContentIndex(index, conversations.length)],
        );
      },
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('chat_history.clear_all_title')),
        content: Text(context.tr('chat_history.clear_all_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('chat_history.clear_all')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(chatHistoryProvider.notifier).clearAll();
    }
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWithAd(
      icon: Icons.forum_outlined,
      title: context.tr('chat_history.empty_title'),
      message: context.tr('chat_history.empty_message'),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ChatConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatHistoryProvider.notifier);

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => notifier.deleteConversation(conversation.id),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: VaultColors.gold,
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          title: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${conversation.preview}\n${_relativeTime(context, conversation.updatedAt)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          onTap: () {
            notifier.setActive(conversation.id);
            Navigator.pop(context);
          },
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                _renameDialog(context, ref);
              } else if (value == 'delete') {
                notifier.deleteConversation(conversation.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(context.tr('chat_history.rename'))),
              PopupMenuItem(value: 'delete', child: Text(context.tr('common.delete'))),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('chat_history.delete_title')),
        content: Text(context.tr('chat_history.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('chat_history.rename_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: context.tr('chat_history.rename_hint')),
          onSubmitted: (v) =>
              v.trim().isEmpty ? null : Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('common.cancel')),
          ),
          // Rebuilds as the user types so Save is disabled while empty.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, controller.text),
              child: Text(context.tr('common.save')),
            ),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await ref
          .read(chatHistoryProvider.notifier)
          .rename(conversation.id, newTitle);
    }
  }

  String _relativeTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return context.tr('chat_history.just_now');
    if (diff.inMinutes < 60) {
      return context.plural('chat_history.minutes_ago', diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.plural('chat_history.hours_ago', diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.plural('chat_history.days_ago', diff.inDays);
    }
    return DateFormat('MMM d, yyyy').format(time);
  }
}
