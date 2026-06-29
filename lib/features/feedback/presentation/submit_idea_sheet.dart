import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/app_info_provider.dart';
import '../idea_service.dart';
import 'package:easy_localization/easy_localization.dart';

class SubmitIdeaSheet extends ConsumerStatefulWidget {
  const SubmitIdeaSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SubmitIdeaSheet(),
    );
  }

  @override
  ConsumerState<SubmitIdeaSheet> createState() => _SubmitIdeaSheetState();
}

class _SubmitIdeaSheetState extends ConsumerState<SubmitIdeaSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final idea = _controller.text.trim();
    if (idea.isEmpty || _submitting) return;

    final messenger = ScaffoldMessenger.of(context);
    if (FirebaseAuth.instance.currentUser == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('feedback.sign_in_required'))),
      );
      return;
    }
    setState(() => _submitting = true);
    // Resolve before the async gap to avoid using context across an await.
    final thanksMsg = context.tr('feedback.thanks');
    final failedMsg = context.tr('feedback.submit_failed');

    final appVersion = ref.read(packageInfoProvider).version;
    try {
      await IdeaService().submit(idea: idea, appVersion: appVersion);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(thanksMsg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(failedMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('feedback.title'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.tr('feedback.description'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 2000,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.tr('feedback.hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_submitting || !_canSubmit) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('feedback.submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
