import 'package:flutter/foundation.dart';

// Stub AdError
class AdError {
  final int code;
  final String message;
  final String domain;
  AdError(this.code, this.message, this.domain);
  @override
  String toString() => '$domain($code): $message';
}

class AdManager {
  static final AdManager instance = AdManager._internal();

  factory AdManager() {
    return instance;
  }

  AdManager._internal();

  Future<void> initialize() async {
    debugPrint('AdManager: Stub implementation (no-op).');
  }

  bool get isAdReady => false;

  void showRewardedAd({
    required Function() onUserEarnedReward,
    Function()? onAdDismissed,
    Function(AdError)? onAdFailed,
  }) {
    debugPrint('AdManager: showRewardedAd called on stub.');
    onAdFailed?.call(AdError(0, 'Platform not supported', 'AdManager'));
  }
}
