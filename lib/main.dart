import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum GameState { aiming, dead }

class OneMoreGame extends FlameGame with TapCallbacks {
  static const double baseSpeed = 240.0;
  static const double jitterAmp = 0.03;
  static const double jitterFreq = 0.45;
  static const double radiusStart = 50.0;
  static const double radiusMin = 15.0;
  static const double k = 1.2;
  static const double nearMissThreshold = 60.0;
  static const double pNearEarly = 0.25;
  static const double pNearMid = 0.50;
  static const double pNearHigh = 0.85;

  late final Random _rng;
  double t = 0;
  double jitterPhase = 0;
  double arrowX = 0;
  double arrowY = 0;
  double targetY = 0;
  int _popCountdown = 0;
  int _scorePopCountdown = 0;
  String? _lastScoreText;
  int score = 0;
  GameState state = GameState.aiming;
  String? nearMissText;

  final Paint bg = Paint()..color = const Color(0xFFFFFFFF);
  final Paint fg = Paint()..color = const Color(0xFF000000);

  final TextPaint scorePaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
  );

  final TextPaint bigPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );

  final TextPaint smallPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.grey,
      fontSize: 9,
      fontWeight: FontWeight.normal,
    ),
  );

  final TextPaint tinyPaint = TextPaint(
    style: GoogleFonts.inter(
      color: const Color(0xFF00AA00),
      fontSize: 9,
      fontWeight: FontWeight.normal,
    ),
  );

  final TextPaint nearMissPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black,
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  );

  @override
  Future<void> onLoad() async {
    _rng = Random();
    reset();
  }

  void reset() {
    state = GameState.aiming;
    score = 0;
    t = 0;
    jitterPhase = _rng.nextDouble() * pi * 2;
    arrowX = 0;
    _popCountdown = 0;
    _scorePopCountdown = 0;
    _lastScoreText = null;
    nearMissText = null;
    arrowY = size.y * 0.9;
    targetY = size.y * 0.35;
  }

  double _speed() {
    return baseSpeed * (1 + jitterAmp * sin(jitterPhase + t * 2 * pi * jitterFreq));
  }

  double _radius() {
    return max(radiusStart - (score * k), radiusMin);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state == GameState.aiming) {
      final v = _speed();
      arrowX += v * dt;
      if (arrowX > size.x) {
        arrowX -= size.x;
      }
      t += dt;
      if (_popCountdown > 0) {
        _popCountdown--;
      }
      if (_scorePopCountdown > 0) {
        _scorePopCountdown--;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), bg);

    final cx = size.x * 0.5;
    final cyTarget = targetY;
    final cyArrow = arrowY;

    final r = _radius();
    final double popScale = _popCountdown > 0 ? 1.05 : 1.0;
    
    // Target opacity logic
    final Paint targetPaint = (state == GameState.dead) 
        ? (Paint()..color = fg.color.withValues(alpha: 0.8)) 
        : fg;

    canvas.save();
    canvas.translate(cx, cyTarget);
    canvas.scale(popScale, popScale);
    canvas.drawCircle(Offset.zero, r, targetPaint);
    canvas.restore();

    const double arrowW = 6;
    const double arrowH = 40.0;
    final Rect arrowRect = Rect.fromCenter(
      center: Offset(arrowX, cyArrow),
      width: arrowW,
      height: arrowH,
    );
    canvas.drawRect(arrowRect, fg);

    scorePaint.render(canvas, 'SCORE $score', Vector2(12, 16));
    if (_scorePopCountdown > 0 && _lastScoreText != null) {
      tinyPaint.render(canvas, _lastScoreText!, Vector2(140, 24));
    }

    if (state == GameState.dead) {
      const double oneMoreFontSize = 20.0;
      
      // ONE MORE position
      // Space between target top and ONE MORE bottom = 0.7 * r
      final double gapTarget = r * 0.70; 
      final double oneMoreY = cyTarget - r - gapTarget;

      bigPaint.render(canvas, 'ONE MORE', Vector2(cx, oneMoreY), anchor: Anchor.bottomCenter);
      
      if (nearMissText != null) {
        // Near-miss position
        // Space between ONE MORE top and Near-miss bottom = 0.9 * ONE_MORE_font
        const double gapOneMore = oneMoreFontSize * 0.9;
        final double nearMissY = (oneMoreY - oneMoreFontSize) - gapOneMore;
        
        nearMissPaint.render(canvas, nearMissText!, Vector2(cx, nearMissY), anchor: Anchor.bottomCenter);
      }
      
      // Tap to try again position
      // Space between target bottom and text top = 0.6 * r
      final double gapTry = r * 0.6;
      final double tryAgainY = cyTarget + r + gapTry;
      
      smallPaint.render(canvas, 'tap to try again', Vector2(cx, tryAgainY), anchor: Anchor.topCenter);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (state == GameState.dead) {
      reset();
      return;
    }

    final cx = size.x * 0.5;
    final dx = arrowX - cx;

    double effectiveR = _radius();
    final dist = dx.abs();
    
    if (dist <= effectiveR) {
      final d = dist / effectiveR;
      int inc = 1;
      if (d <= 0.33) {
        inc = 3;
      } else if (d <= 0.70) {
        inc = 2;
      }
      
      score += inc;
      _lastScoreText = '+$inc';
      _scorePopCountdown = 45;
      _popCountdown = 2;
    } else {
      final margin = dist - effectiveR;
      nearMissText = null;
      if (margin <= nearMissThreshold) {
        final speed = _speed();
        final timeDiff = margin / speed;
        final timeStr = timeDiff.toStringAsFixed(3);
        
        final isEarly = dx < 0;
        final suffix = isEarly ? 'TOO EARLY' : 'TOO LATE';
        
        nearMissText = '${timeStr}s $suffix';
      }
      state = GameState.dead;
    }
  }

  static double clamp(double v, double min, double max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(GameWidget(game: OneMoreGame()));
}
