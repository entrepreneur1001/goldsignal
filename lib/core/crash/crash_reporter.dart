import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Records a non-fatal error to Crashlytics.
///
/// Use this inside `catch` blocks that intentionally swallow an error so the
/// failure stays non-fatal for the user but is still observable in production.
/// Prefer this over a bare `catch (_) {}` for best-effort work (widget updates,
/// background syncs, cloud saves) where a silent failure would otherwise be
/// invisible.
void reportNonFatal(
  Object error,
  StackTrace stack, {
  String? reason,
}) {
  // Crashlytics is not supported on web; avoid the UnimplementedError.
  if (kIsWeb) return;
  try {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: false,
    );
  } catch (_) {
    // Never let error reporting itself throw.
  }
}
