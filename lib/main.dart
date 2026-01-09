import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameState { aiming, dead, frozen }

class OneMoreGame extends FlameGame with TapCallbacks {
  static const double baseSpeed = 240.0;
  static const double jitterAmp = 0.035; // Increased from 0.03 to 0.035
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
  double phaseOffset = 0;
  double arrowX = 0;
  double arrowY = 0;
  double targetY = 0;
  int _popCountdown = 0;
  int _scorePopCountdown = 0;
  String? _lastScoreText;
  int score = 0;
  double effectiveScore = 0;
  int bestScore = 0;
  int hits = 0;
  bool hasPlayed = false;
  double _flashOpacity = 0.0;
  bool _flashedOnce = false;
  double _ghostTapOpacity = 0.0;
  bool _ghostTapShown = false;
  double _ghostTapTimer = 0.0;
  double _freezeTimer = 0.0;
  GameState state = GameState.aiming;
  String? nearMissText;

  final Paint bg = Paint()..color = const Color(0xFFFFFFFF);
  final Paint fg = Paint()..color = const Color(0xFF000000);

  static const double S = 24.0; // Score font size reference

  final TextPaint scorePaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black,
      fontSize: S,
      fontWeight: FontWeight.w600,
    ),
  );

  final TextPaint oneMorePaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black.withValues(alpha: 0.9),
      fontSize: S * 0.70,
      fontWeight: FontWeight.bold,
    ),
  );

  final TextPaint tapToRetryPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black.withValues(alpha: 0.5),
      fontSize: S * 0.35,
      fontWeight: FontWeight.normal,
    ),
  );

  final TextPaint tinyPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black.withValues(alpha: 0.6),
      fontSize: S * 0.45,
      fontWeight: FontWeight.normal,
    ),
  );

  final TextPaint bestPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black.withValues(alpha: 0.7),
      fontSize: S * 0.55,
      fontWeight: FontWeight.normal,
    ),
  );

  final TextPaint nextPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black,
      fontSize: S * 0.60,
      fontWeight: FontWeight.w600,
    ),
  );

  final TextPaint nearMissPaint = TextPaint(
    style: GoogleFonts.inter(
      color: const Color(0xFF000000), // Fully opaque black
      fontSize: S * 0.85,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  Future<void> onLoad() async {
    _rng = Random();
    final prefs = await SharedPreferences.getInstance();
    bestScore = prefs.getInt('bestScore') ?? 0;
    hasPlayed = prefs.getBool('hasPlayed') ?? false;
    reset();
  }

  Future<void> _updateBestScore() async {
    if (score > bestScore) {
      bestScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bestScore', bestScore);
    }
  }

  Future<void> _setHasPlayed() async {
    if (!hasPlayed) {
      hasPlayed = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasPlayed', true);
    }
  }

  void reset() {
    state = GameState.aiming;
    score = 0;
    effectiveScore = 0;
    hits = 0;
    t = 0;
    phaseOffset = _rng.nextDouble() * pi * 3; // Range expanded to [0, 3π]
    arrowX = 0;
    _popCountdown = 0;
    _scorePopCountdown = 0;
    _lastScoreText = null;
    nearMissText = null;
    _flashOpacity = 0.0;
    _flashedOnce = false;
    _ghostTapOpacity = 0.0;
    _ghostTapShown = false;
    _ghostTapTimer = 0.0;
    _freezeTimer = 0.0;
    arrowY = size.y * 0.9;
    targetY = size.y * 0.5;
  }

  double _speed() {
    // effectiveSpeed(t) = baseSpeed * (1 + ε(t))
    // ε(t) = soft wave with amplitude ±2.5% - 3%
    // Using composite sine wave to break rhythm (Perlin-like feel)
    final double t1 = t * 2 * pi * jitterFreq;
    final double t2 = t * 2 * pi * (jitterFreq * 1.5); // Second frequency component
    
    // Combine two waves and normalize roughly
    final double wave = (sin(phaseOffset + t1) + 0.5 * sin(phaseOffset + t2)) / 1.5;
    
    return baseSpeed * (1 + jitterAmp * wave);
  }

  double _radius() {
    return max(radiusStart - (effectiveScore * k), radiusMin);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (state == GameState.frozen) {
      _freezeTimer -= dt;
      if (_freezeTimer <= 0) {
        state = GameState.dead;
        _updateBestScore();
      }
      return;
    }
    
    if (state == GameState.aiming) {
      final cx = size.x * 0.5;
      final double oldArrowX = arrowX;
      
      final v = _speed();
      arrowX += v * dt;
      if (arrowX > size.x) {
        arrowX -= size.x;
      }
      
      // Check if arrow crossed the center in this frame
      // Logic: It was left of center before, and is at or right of center now
      // (ignoring wrap-around case since center is middle of screen)
      bool crossedCenter = (oldArrowX < cx && arrowX >= cx);
      
      if (crossedCenter) {
        if (!hasPlayed) {
          if (!_flashedOnce) {
            _flashOpacity = 0.12;
            _flashedOnce = true;
          }
          
          if (!_ghostTapShown) {
             _ghostTapOpacity = 0.14;
             _ghostTapTimer = 1.4; // 1.4s duration
             _ghostTapShown = true;
          }
        }
      } else if (arrowX > cx + 20.0) {
        _flashedOnce = false;
        _ghostTapShown = false;
      }
      
      t += dt;
      if (_popCountdown > 0) {
        _popCountdown--;
      }
      if (_scorePopCountdown > 0) {
        _scorePopCountdown--;
      }
    }
    
    if (_flashOpacity > 0) {
      _flashOpacity -= dt * 1.0; 
      if (_flashOpacity < 0) _flashOpacity = 0;
    }
    
    // Ghost Tap fade out logic
    if (_ghostTapTimer > 0) {
      _ghostTapTimer -= dt;
      if (_ghostTapTimer > 0) {
        _ghostTapOpacity = 0.14 * (_ghostTapTimer / 1.4);
      } else {
        _ghostTapOpacity = 0;
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

    // Layout constants
    const double S = OneMoreGame.S;
    const double radiusStart = OneMoreGame.radiusStart;
    
    const double oneMoreFontSize = S * 0.85;
    const double bestFontSize = S * 0.55;
    const double nextFontSize = S * 0.60;
    
    // Reference Point: CenterY = screenHeight * 0.5
    final double centerY = size.y * 0.5;
    
    // ONE MORE (Fixed Anchor - Top)
    // Distance from Target Top to One More Bottom = S * 0.9
    // Target Top = CenterY - radiusStart
    // One More Bottom = (CenterY - radiusStart) - (S * 0.9)
    final double oneMoreY = (centerY - radiusStart) - (S * 0.9);
    
    // SCORE (Fixed Anchor - Bottom)
    // Distance from Target Bottom to Score Top = S
    // Target Bottom = CenterY + radiusStart
    // Score Top = (CenterY + radiusStart) + S
    final double scoreY = (centerY + radiusStart) + S;
    
    // Near-miss (Above ONE MORE)
    final double nearMissY = oneMoreY - oneMoreFontSize - 12;
    
    // BEST (Below SCORE)
    final double bestY = scoreY + S + 8;
    
    // NEXT (Below BEST)
    // next = ((score ~/ 10) + 1) * 10
    final int nextScore = ((score ~/ 10) + 1) * 10;
    final double nextY = bestY + bestFontSize + 8;
    
    // Tap to try again (Below NEXT)
    final double tryAgainY = nextY + nextFontSize + 24;

    scorePaint.render(canvas, '$score', Vector2(cx, scoreY), anchor: Anchor.topCenter);
    
    if (_scorePopCountdown > 0 && _lastScoreText != null) {
      // Position above SCORE (scoreY is top of score text)
      // No animation, just static fade (controlled by opacity in paint)
      tinyPaint.render(canvas, _lastScoreText!, Vector2(cx, scoreY - 4), anchor: Anchor.bottomCenter);
    }

    if (state == GameState.dead) {
      oneMorePaint.render(canvas, 'ONE MORE', Vector2(cx, oneMoreY), anchor: Anchor.bottomCenter);
      
      if (nearMissText != null) {
        nearMissPaint.render(canvas, nearMissText!, Vector2(cx, nearMissY), anchor: Anchor.bottomCenter);
      }
      
      // Render BEST and NEXT
      bestPaint.render(canvas, 'BEST: $bestScore', Vector2(cx, bestY), anchor: Anchor.topCenter);
      nextPaint.render(canvas, 'NEXT: $nextScore', Vector2(cx, nextY), anchor: Anchor.topCenter);
      
      tapToRetryPaint.render(canvas, 'tap to try again', Vector2(cx, tryAgainY), anchor: Anchor.topCenter);
    }
    
    // Render flash overlay if active
    if (_flashOpacity > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.black.withValues(alpha: _flashOpacity),
      );
    }
    
    // Render Ghost Tap
    if (_ghostTapOpacity > 0) {
      final double ghostRadius = r * 0.525;
      final double ghostX = cx + (r * 0.9) + 50;
      final double ghostY = cyTarget + (r * 0.6) + 30;
      
      // Outer circle
      canvas.drawCircle(
        Offset(ghostX, ghostY),
        ghostRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: _ghostTapOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Inner circle
      canvas.drawCircle(
        Offset(ghostX, ghostY),
        ghostRadius * 0.8,
        Paint()
          ..color = Colors.black.withValues(alpha: _ghostTapOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (event.canvasPosition.y >= size.y * 0.85) {
      return;
    }

    if (state == GameState.dead) {
      reset();
      return;
    }

    final cx = size.x * 0.5;
    final dx = arrowX - cx;

    final double visualR = _radius();
    // effectiveRadius = visualRadius * (1 - microBias)
    // microBias ∈ [0, 0.15]
    // Increases slowly with score (approx max at score 60)
    final double microBias = clamp(score * 0.002, 0.0, 0.15);
    final double effectiveR = visualR * (1 - microBias);
    
    final dist = dx.abs();
    
    if (dist <= effectiveR) {
      // Successful hit
      if (!hasPlayed) {
        _setHasPlayed();
      }
      
      // Stop tutorial animations immediately on hit
      _flashOpacity = 0.0;
      _ghostTapOpacity = 0.0;
      _ghostTapTimer = 0.0;
      _ghostTapShown = true; // Prevent re-triggering
      _flashedOnce = true;   // Prevent re-triggering
      
      final d = dist / effectiveR;
      int inc = 1;
      if (d <= 0.33) {
        inc = 3;
      } else if (d <= 0.70) {
        inc = 2;
      }
      
      score += inc;
      
      // Update effectiveScore based on difficulty rules
      if (score <= 10) {
        // No increase
      } else if (score <= 30) {
        effectiveScore += 0.5;
      } else {
        effectiveScore += 1.0;
      }
      
      hits++;
      
      _lastScoreText = null;
      // Condition: inc > 1 (never show +1), score >= 15, ~25% chance
      if (inc > 1 && score >= 15 && _rng.nextDouble() < 0.25) {
        _lastScoreText = '+$inc';
        _scorePopCountdown = 9; // ~150ms at 60fps
      } else {
        _scorePopCountdown = 0;
      }

      _popCountdown = 2;
    } else {
      // Miss logic
      if (!hasPlayed) {
        // Soft penalty for first run: Vibrate only, no game over, no score
        HapticFeedback.lightImpact();
        // Mark as played ONLY on first hit, not miss.
        // So tutorial animations persist until first hit.
        return;
      }
      
      _setHasPlayed(); // Ensure it's marked (redundant but safe)
      
      final margin = dist - effectiveR;
      nearMissText = null;
      
      final speed = _speed();
      final timeDiff = margin / speed;
      
      if (timeDiff <= 0.06) {
        final timeStr = timeDiff.toStringAsFixed(3);
        
        final isEarly = dx < 0;
        final suffix = isEarly ? 'TOO EARLY' : 'TOO LATE';
        
        nearMissText = '${timeStr}s $suffix';
        
        // Freeze for 300ms before showing Game Over screen (increased from 120ms for visibility)
        state = GameState.frozen;
        _freezeTimer = 0.300;
        return;
      }
      state = GameState.dead;
      _updateBestScore();
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
