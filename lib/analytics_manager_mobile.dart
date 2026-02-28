import 'package:flutter/foundation.dart';

class AnalyticsManager {
  static void logScore({
    required int score,
    required int bestScore,
    required int hits,
  }) {
    // Mobile implementation (empty for now)
    debugPrint('Analytics: logScore called (mobile).');
  }

  static void logGameStart() {
    debugPrint('Analytics: logGameStart called (mobile).');
  }

  static void logGameOver({required int score}) {
    debugPrint('Analytics: logGameOver called (mobile).');
  }

  static void logCheckpoint({required int checkpoint}) {
    debugPrint('Analytics: logCheckpoint called (mobile).');
  }

  static void logMissMs({required double ms}) {
    debugPrint('Analytics: logMissMs called (mobile).');
  }
}

