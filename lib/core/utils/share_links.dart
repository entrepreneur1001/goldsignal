import 'dart:io';

import '../config/app_remote_config.dart';
import '../../features/system/store_launcher.dart' show storeUrl;

/// App-store listing URL with UTM params for share attribution.
String shareStoreUrl(AppRemoteConfig config, {required String campaign}) {
  final base = storeUrl(config);
  final uri = Uri.parse(base);
  final params = Map<String, String>.from(uri.queryParameters)
    ..['utm_source'] = 'share'
    ..['utm_medium'] = Platform.isIOS ? 'ios' : 'android'
    ..['utm_campaign'] = campaign;
  return uri.replace(queryParameters: params).toString();
}

String shareMessageFooter(AppRemoteConfig config, {required String campaign}) {
  return 'Track live gold & silver prices — GoldSignal\n${shareStoreUrl(config, campaign: campaign)}';
}
