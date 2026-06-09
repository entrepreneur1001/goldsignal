import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_remote_config.dart';

/// Open the platform app store listing for this app, using the URLs/ids from
/// remote config (with sensible fallbacks).
Future<void> openAppStore(AppRemoteConfig config) async {
  final String url;
  if (Platform.isIOS) {
    url = config.iosAppStoreId.isNotEmpty
        ? 'https://apps.apple.com/app/id${config.iosAppStoreId}'
        : 'https://apps.apple.com/';
  } else {
    url = config.androidUrl.isNotEmpty
        ? config.androidUrl
        : 'https://play.google.com/store/apps/details?id=com.goldsignal.goldsignal';
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
