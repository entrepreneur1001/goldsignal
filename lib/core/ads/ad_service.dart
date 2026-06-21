import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
  }

  // ── Ad unit IDs ───────────────────────────────────────────────────

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9518678425811612/1830089004';
    } else {
      return 'ca-app-pub-9518678425811612/2756199424';
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9518678425811612/5801123606';
    } else {
      return 'ca-app-pub-9518678425811612/1103035549';
    }
  }

  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9518678425811612/9770258393';
    } else {
      return 'ca-app-pub-9518678425811612/4980966141';
    }
  }

  // ── Interstitial management ───────────────────────────────────────

  void _loadInterstitial() {
    if (_isLoadingInterstitial || _interstitialAd != null) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  Future<void> showInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );

    ad.show();
    _interstitialAd = null;
  }
}
