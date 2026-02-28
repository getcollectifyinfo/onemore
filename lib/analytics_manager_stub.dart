import 'package:flutter/foundation.dart';

class AnalyticsManager {
  static void logScore({
    required int score,
    required int bestScore,
    required int hits,
  }) {
    debugPrint('Analytics: logScore called (stub).');
  }

  static void logGameStart() {
    debugPrint('Analytics: logGameStart called (stub).');
  }

  static void logGameOver({required int score}) {
    debugPrint('Analytics: logGameOver called (stub).');
  }

  static void logCheckpoint({required int checkpoint}) {
    debugPrint('Analytics: logCheckpoint called (stub).');
  }

  static void logMissMs({required double ms}) {
    debugPrint('Analytics: logMissMs called (stub).');
  }
}

