import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote app configuration, read from the public Firestore `config/app` doc.
/// Used to gate the app at launch (maintenance + force/soft update).
class AppRemoteConfig {
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final String minimumVersion; // hard block below this
  final String latestVersion; // soft prompt below this
  final String androidUrl;
  final String iosAppStoreId;
  final String updateMessage;

  const AppRemoteConfig({
    this.maintenanceEnabled = false,
    this.maintenanceMessage =
        "We're doing some maintenance. Please check back shortly.",
    this.minimumVersion = '0.0.0',
    this.latestVersion = '0.0.0',
    this.androidUrl = '',
    this.iosAppStoreId = '',
    this.updateMessage = 'A new version is available with improvements.',
  });

  /// Permissive defaults — used on any fetch failure so users are never locked
  /// out by a transient error (fail-open).
  static const AppRemoteConfig permissive = AppRemoteConfig();

  factory AppRemoteConfig.fromMap(Map<String, dynamic> map) {
    return AppRemoteConfig(
      maintenanceEnabled: map['maintenanceEnabled'] as bool? ?? false,
      maintenanceMessage: map['maintenanceMessage'] as String? ??
          permissive.maintenanceMessage,
      minimumVersion: map['minimumVersion'] as String? ?? '0.0.0',
      latestVersion: map['latestVersion'] as String? ?? '0.0.0',
      androidUrl: map['androidUrl'] as String? ?? '',
      iosAppStoreId: map['iosAppStoreId'] as String? ?? '',
      updateMessage:
          map['updateMessage'] as String? ?? permissive.updateMessage,
    );
  }
}

class RemoteConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration _timeout = Duration(seconds: 4);

  /// Read `config/app`. Fails open: returns [AppRemoteConfig.permissive] on any
  /// error or timeout so launch is never blocked by config problems.
  Future<AppRemoteConfig> fetch() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('app')
          .get()
          .timeout(_timeout);
      if (!doc.exists) return AppRemoteConfig.permissive;
      return AppRemoteConfig.fromMap(doc.data() ?? const {});
    } catch (_) {
      return AppRemoteConfig.permissive;
    }
  }
}

/// True if [current] is strictly lower than [target] using dotted numeric
/// version comparison (e.g. "1.2.0" < "1.10.0"). Non-numeric/missing segments
/// are treated as 0. Returns false if [target] is empty/blank.
bool isVersionLower(String current, String target) {
  if (target.trim().isEmpty) return false;
  final a = _segments(current);
  final b = _segments(target);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}

List<int> _segments(String version) {
  // Strip any build suffix ("1.2.0+3" -> "1.2.0") and non-numeric noise.
  final core = version.split('+').first.trim();
  return core
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
