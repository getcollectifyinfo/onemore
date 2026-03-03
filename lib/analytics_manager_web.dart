// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:js';
import 'package:flutter/foundation.dart';

class AnalyticsManager {
  static void logScore({
    required int score,
    required int bestScore,
    required int hits,
  }) {
    // Deprecated: score is now part of game_over event
  }

  static void logGameStart() {
    if (!kIsWeb) return;
    try {
      context.callMethod('gtag', [
        'event',
        'game_start',
        JsObject.jsify({}),
      ]);
      debugPrint('Analytics: game_start event sent (web).');
    } catch (_) {}
  }

  static void logGameOver({required int score, int? missMs}) {
    if (!kIsWeb) return;
    try {
      final Map<String, dynamic> params = {'score': score};
      if (missMs != null) {
        params['miss_ms'] = missMs;
      }
      context.callMethod('gtag', [
        'event',
        'game_over',
        JsObject.jsify(params),
      ]);
      debugPrint('Analytics: game_over event sent (web). Params: $params');
    } catch (_) {}
  }

  static void logCheckpoint({required int checkpoint}) {
    if (!kIsWeb) return;
    try {
      context.callMethod('gtag', [
        'event',
        'checkpoint',
        JsObject.jsify({
          'value': checkpoint,
        }),
      ]);
      debugPrint('Analytics: checkpoint event sent (web). Value: $checkpoint');
    } catch (_) {}
  }
}
