import 'dart:js';
import 'package:flutter/foundation.dart';

class AnalyticsManager {
  static void logScore({
    required int score,
    required int bestScore,
    required int hits,
  }) {
    if (!kIsWeb) return;
    try {
      context.callMethod('gtag', [
        'event',
        'score',
        JsObject.jsify({
          'value': score,
          'score': score,
          'best_score': bestScore,
          'hits': hits,
        }),
      ]);
      debugPrint('Analytics: score event sent (web).');
    } catch (_) {}
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

  static void logGameOver({required int score}) {
    if (!kIsWeb) return;
    try {
      context.callMethod('gtag', [
        'event',
        'game_over',
        JsObject.jsify({
          'score': score,
        }),
      ]);
      debugPrint('Analytics: game_over event sent (web).');
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
      debugPrint('Analytics: checkpoint event sent (web).');
    } catch (_) {}
  }

  static void logMissMs({required double ms}) {
    if (!kIsWeb) return;
    try {
      context.callMethod('gtag', [
        'event',
        'miss_ms',
        JsObject.jsify({
          'value': ms,
        }),
      ]);
      debugPrint('Analytics: miss_ms event sent (web).');
    } catch (_) {}
  }
}

