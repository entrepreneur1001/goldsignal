import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/design/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_remote_config.dart';
import '../../../shared/providers/app_config_provider.dart';
import '../../../shared/providers/app_info_provider.dart';
import '../../system/store_launcher.dart';
import '../rating_service.dart';

class RateAppSheet extends ConsumerStatefulWidget {
  const RateAppSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RateAppSheet(),
    );
  }

  @override
  ConsumerState<RateAppSheet> createState() => _RateAppSheetState();
}

class _RateAppSheetState extends ConsumerState<RateAppSheet> {
  final RatingService _service = RatingService();
  final _feedbackController = TextEditingController();

  int _stars = 0;
  bool _loading = true;
  bool _hasExisting = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final existing = await _service.loadMyRating();
    if (!mounted) return;
    if (existing != null) {
      _stars = (existing['stars'] as num?)?.toInt() ?? 0;
      _feedbackController.text = (existing['feedback'] as String?) ?? '';
      _hasExisting = _stars > 0;
    }
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_stars == 0 || _submitting) return;

    final messenger = ScaffoldMessenger.of(context);
    if (FirebaseAuth.instance.currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to rate the app.')),
      );
      return;
    }
    setState(() => _submitting = true);

    final appVersion = ref.read(packageInfoProvider).version;
    final iosAppStoreId = ref.read(appRemoteConfigProvider)?.iosAppStoreId ?? '';
    final stars = _stars;

    try {
      await _service.submit(
        stars: stars,
        feedback: _feedbackController.text.trim(),
        appVersion: appVersion,
        iosAppStoreId: iosAppStoreId,
      );
    } catch (_) {
      // Keep the flow friendly even if the write fails.
    }

    if (!mounted) return;
    Navigator.pop(context);
    if (stars < 5) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
    }
  }

  void _rateOnStore() {
    final config = ref.read(appRemoteConfigProvider) ?? const AppRemoteConfig();
    openAppStore(config);
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
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _hasExisting ? 'Your rating' : 'Enjoying GoldSignal?',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasExisting
                        ? 'You can update your rating any time.'
                        : 'Tap a star to rate your experience.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < _stars;
                      return IconButton(
                        iconSize: 40,
                        onPressed: () => setState(() => _stars = i + 1),
                        icon: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: VaultColors.gold,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Feedback (optional)',
                      hintText: 'Tell us how we can improve…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _stars == 0 || _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_hasExisting ? 'Update rating' : 'Submit'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _rateOnStore,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Rate on the store'),
                  ),
                ],
              ),
      ),
    );
  }
}
