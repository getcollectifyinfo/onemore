import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

export 'package:google_mobile_ads/google_mobile_ads.dart' show AdError;

class AdManager {
  static final AdManager instance = AdManager._internal();

  factory AdManager() {
    return instance;
  }

  AdManager._internal();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  // Test Ad Unit IDs
  // Android: ca-app-pub-3940256099942544/5224354917
  // iOS: ca-app-pub-3940256099942544/1712485313
  String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      _loadRewardedAd();
    } catch (e) {
      debugPrint('AdManager initialization failed: $e');
    }
  }

  void _loadRewardedAd() {
    if (_isLoading) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('$ad loaded.');
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _isLoading = false;
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  bool get isAdReady => _rewardedAd != null;

  void showRewardedAd({
    required Function() onUserEarnedReward,
    Function()? onAdDismissed,
    Function(AdError)? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('Warning: Attempted to show rewarded ad before it was ready.');
      _loadRewardedAd(); // Try loading again for next time
      onAdDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) =>
          debugPrint('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Preload the next ad
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Preload the next ad
        onAdFailed?.call(error);
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
        onUserEarnedReward();
      },
    );
  }
}
