import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/app_info_provider.dart';
import '../idea_service.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final idea = _controller.text.trim();
    if (idea.isEmpty || _submitting) return;
    setState(() => _submitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final appVersion = ref.read(packageInfoProvider).version;
    try {
      await IdeaService().submit(idea: idea, appVersion: appVersion);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks! Your idea was submitted.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not submit. Please try again.')),
      );
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
            Text('Share your idea', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Have a feature in mind? Tell us what would make GoldSignal better.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 2000,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Describe your idea…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit idea'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
