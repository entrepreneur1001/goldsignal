import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads/ad_service.dart';
import '../design/app_colors.dart';
import '../providers/purchase_provider.dart';

/// A native ad rendered with AdMob's built-in template — no platform-side
/// `NativeAdFactory` is required (templates ship with google_mobile_ads).
///
/// Blends into surrounding content (lists, feeds). Like [BannerAdWidget] it
/// hides itself for Pro users and collapses to zero height on load failure, so
/// it can be dropped straight into a `ListView`/`Column` without leaving a gap.
class NativeAdWidget extends ConsumerStatefulWidget {
  /// `TemplateType.medium` (~image + headline + body + CTA) or
  /// `TemplateType.small` (compact row). Medium suits standalone slots; small
  /// suits dense lists.
  final TemplateType templateType;

  const NativeAdWidget({super.key, this.templateType = TemplateType.medium});

  @override
  ConsumerState<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends ConsumerState<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  /// Approximate template heights so the ad has bounded constraints inside a
  /// scroll view. The template renders within this height.
  double get _height =>
      widget.templateType == TemplateType.medium ? 320 : 110;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final isDark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C26) : const Color(0xFFFFFFFF);
    final text = isDark ? Colors.white : const Color(0xFF1A1410);
    final secondary = isDark ? Colors.white70 : Colors.black54;

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType,
        mainBackgroundColor: bg,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1A1410),
          backgroundColor: VaultColors.gold,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(textColor: text),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: secondary),
        tertiaryTextStyle: NativeTemplateTextStyle(textColor: secondary),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _nativeAd = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    if (isPro) return const SizedBox.shrink();
    if (!_isLoaded || _nativeAd == null) return const SizedBox.shrink();

    return Container(
      height: _height,
      alignment: Alignment.center,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
