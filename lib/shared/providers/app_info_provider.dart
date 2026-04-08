import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Set in [main] after [PackageInfo.fromPlatform] via [ProviderScope.overrides].
final packageInfoProvider = Provider<PackageInfo>(
  (ref) => throw StateError(
    'packageInfoProvider must be overridden — load PackageInfo in main().',
  ),
);
