import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_remote_config.dart';

/// The platform app-store listing URL, from remote config (with fallbacks).
String storeUrl(AppRemoteConfig config) {
  if (Platform.isIOS) {
    return config.iosAppStoreId.isNotEmpty
        ? 'https://apps.apple.com/app/id${config.iosAppStoreId}'
        : 'https://apps.apple.com/';
  }
  return config.androidUrl.isNotEmpty
      ? config.androidUrl
      : 'https://play.google.com/store/apps/details?id=com.goldsignal.goldsignal';
}

/// Open the platform app store listing for this app.
Future<void> openAppStore(AppRemoteConfig config) async {
  await launchUrl(Uri.parse(storeUrl(config)), mode: LaunchMode.externalApplication);
}
