import 'dart:async';
import 'dart:js';
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

  bool _isCrazyGamesInitialized = false;

  Future<void> initialize() async {
    try {
      debugPrint('AdManager: Initializing CrazyGames SDK...');
      
      // Access window.CrazyGames.SDK
      if (!context.hasProperty('CrazyGames')) {
        debugPrint('AdManager: CrazyGames object not found on window.');
        return;
      }

      final crazyGames = context['CrazyGames'];
      final sdk = crazyGames['SDK'];
      
      // Call init() which returns a Promise
      final promise = sdk.callMethod('init');
      
      // Handle Promise using Completer
      // dart:js automatically wraps Dart functions passed to JS
      final completer = Completer<void>();
      
      promise.callMethod('then', [
        (_) {
          debugPrint('AdManager: CrazyGames SDK init success callback.');
          if (!completer.isCompleted) completer.complete();
        },
        (error) {
          debugPrint('AdManager: CrazyGames SDK init error callback: $error');
          if (!completer.isCompleted) completer.completeError(error);
        }
      ]);
      
      await completer.future;
      
      _isCrazyGamesInitialized = true;
      debugPrint('AdManager: CrazyGames SDK initialized.');
    } catch (e) {
      debugPrint('AdManager: CrazyGames SDK initialization failed: $e');
      // Fallback: If promise handling fails for some reason, assume initialized after delay
      // This is a safety net
      if (!_isCrazyGamesInitialized) {
         await Future.delayed(const Duration(seconds: 1));
         _isCrazyGamesInitialized = true;
         debugPrint('AdManager: CrazyGames SDK initialized (fallback).');
      }
    }
  }

  bool get isAdReady => _isCrazyGamesInitialized;

  void showRewardedAd({
    required Function() onUserEarnedReward,
    Function()? onAdDismissed,
    Function(AdError)? onAdFailed,
  }) {
    if (!_isCrazyGamesInitialized) {
      debugPrint('AdManager: CrazyGames SDK not initialized.');
      onAdFailed?.call(AdError(0, 'CrazyGames SDK not initialized', 'CrazyGames'));
      return;
    }

    debugPrint('AdManager: Requesting CrazyGames Rewarded Ad...');
    
    try {
      final crazyGames = context['CrazyGames'];
      final sdk = crazyGames['SDK'];
      final adModule = sdk['ad'];
      
      // Create callbacks object
      // We use JsObject.jsify. Dart functions should be auto-wrapped.
      final callbacks = JsObject.jsify({
          'adFinished': () {
              debugPrint('AdManager: CrazyGames ad finished.');
              onUserEarnedReward();
              onAdDismissed?.call();
          },
          'adError': (error, errorData) {
              debugPrint('AdManager: CrazyGames ad error: $error');
              onAdFailed?.call(AdError(0, error.toString(), 'CrazyGames'));
          },
          'adStarted': () {
              debugPrint('AdManager: CrazyGames ad started.');
          },
      });
      
      adModule.callMethod('requestAd', ['rewarded', callbacks]);
    } catch (e) {
       debugPrint('AdManager: Error showing CrazyGames ad: $e');
       onAdFailed?.call(AdError(0, e.toString(), 'CrazyGames'));
    }
  }
}
