// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:flutter/foundation.dart';

// Mock AdError for Web to match google_mobile_ads signature
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
    // CrazyGames SDK removed.
    // Google Ads setup will be here.
    debugPrint('AdManager: CrazyGames SDK removed. Waiting for Google Ads setup.');
  }

  bool get isAdReady => false;

  void showRewardedAd({
    required Function() onUserEarnedReward,
    Function()? onAdDismissed,
    Function(AdError)? onAdFailed,
  }) {
    debugPrint('AdManager: Show Rewarded Ad called, but SDK is removed.');
    // For now, fail or do nothing.
    onAdFailed?.call(AdError(0, 'Ad SDK removed', 'AdManager'));
  }
}
