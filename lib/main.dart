import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_manager.dart';
import 'analytics_manager.dart';

enum GameState { aiming, firing, dead }

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

  // Checkpoint & Progress constants
  static const List<int> checkpointScores = [20, 50, 80, 100, 120, 150, 180, 200, 230, 250, 300, 350, 400, 500];
  static const int totalDots = 200;
  static const int totalDotsOuter = 300;
  static const double progressCircleRadius = 90.0;
  static const double progressCircleRadiusOuter = 110.0;

  late final Random _rng;
  double t = 0;
  double phaseOffset = 0;
  double arrowX = 0;
  double arrowY = 0;
  double targetY = 0;
  double _currentRange = 100.0;
  int _popCountdown = 0;
  int _scorePopCountdown = 0;
  String? _lastScoreText;
  int score = 0;
  double effectiveScore = 0;
  int bestScore = 0;
  
  // Checkpoint state
  int lastCheckpointScore = 0;
  double lastCheckpointEffectiveScore = 0;

  int hits = 0;
  bool hasPlayed = false;
  double _flashOpacity = 0.0;
  bool _flashedOnce = false;
  double _ghostTapOpacity = 0.0;
  bool _ghostTapShown = false;
  double _ghostTapTimer = 0.0;
  double _nearMissDelayTimer = 0.0;
  String? _pendingNearMissText;
  GameState state = GameState.aiming;
  String? nearMissText;

  // Firing state
  double _firingStartY = 0;
  double _firingTargetY = 0;
  double _firingProgress = 0;
  bool _isNearMiss = false;
  bool _wasHit = false;
  // Pending results
  int _pendingScoreInc = 0;
  double _pendingEffectiveScoreInc = 0;
  double? _pendingMissSeconds;
  bool _pendingEarly = false;
  
  // Safety flags
  double _timeSinceDeath = 0;
  bool isSharing = false;

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

  final TextPaint brandingPaint = TextPaint(
    style: GoogleFonts.inter(
      color: Colors.black.withValues(alpha: 0.4),
      fontSize: S * 0.45,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
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

  void _logScoreEvent(double? missSeconds) {
    int? missMsInt;
    if (missSeconds != null) {
      missMsInt = (missSeconds * 1000).round();
    }
    AnalyticsManager.logGameOver(score: score, missMs: missMsInt);
  }

  void reset() {
    AnalyticsManager.logGameStart();
    overlays.remove('ShareButton');
    overlays.remove('AdRecovery'); // Ensure AdRecovery is gone
    state = GameState.aiming;
    score = lastCheckpointScore;
    effectiveScore = lastCheckpointEffectiveScore;
    hits = 0;
    t = 0;
    phaseOffset = _rng.nextDouble() * pi * 3; // Range expanded to [0, 3π]
    _currentRange = 100.0 + _rng.nextDouble() * 50.0; // Random range between 100 and 150
    arrowX = size.x * 0.5 - _currentRange;
    _popCountdown = 0;
    _scorePopCountdown = 0;
    _lastScoreText = null;
    nearMissText = null;
    _flashOpacity = 0.0;
    _flashedOnce = false;
    _ghostTapOpacity = 0.0;
    _ghostTapShown = false;
    _ghostTapTimer = 0.0;
    _nearMissDelayTimer = 0.0;
    _pendingNearMissText = null;
    arrowY = size.y * 0.85;
    targetY = size.y * 0.5 - 100.0;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    targetY = size.y * 0.5 - 100.0;
    arrowY = size.y * 0.9;
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

  void resumeGame() {
    state = GameState.aiming;
    arrowY = size.y * 0.85; // Reset arrow position
    nearMissText = null;
    _pendingNearMissText = null;
    _nearMissDelayTimer = 0;
    overlays.remove('ShareButton');
  }
  
  void _handleDeath(double? missSeconds) {
    state = GameState.dead;
    _timeSinceDeath = 0;
    _updateBestScore();
    _logScoreEvent(missSeconds);
    
    // Always show share button on death
    overlays.add('ShareButton');
    
    // Check for recovery
    // Find next checkpoint
    int nextCheckpoint = -1;
    for (final cp in checkpointScores) {
      if (cp > score) {
        nextCheckpoint = cp;
        break;
      }
    }
    
    // If within 3 points of next checkpoint AND score >= 20
    if (score >= 20 && nextCheckpoint != -1 && nextCheckpoint - score <= 3) {
      // Show ad offer
      overlays.add('AdRecovery');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (state == GameState.dead) {
      // Force arrow to stay at target visually
      arrowY = targetY;
      
      _timeSinceDeath += dt;
      if (_nearMissDelayTimer > 0) {
        _nearMissDelayTimer -= dt;
        if (_nearMissDelayTimer <= 0) {
          nearMissText = _pendingNearMissText;
          _pendingNearMissText = null;
        }
      }
    }
    
    if (state == GameState.firing) {
      // Animation logic
      double speed = 5.0; // Base speed multiplier (1/duration)
      
      // If near miss, slow down as we approach target
      if (_isNearMiss) {
        // Normal speed until 50%, then slow down
        if (_firingProgress > 0.5) {
          speed = 0.5; // Very slow
        } else {
          speed = 6.0; // Fast initial
        }
      } else {
        // Normal shot
        speed = 8.0; // Very fast
      }
      
      _firingProgress += dt * speed;
      
      if (_firingProgress >= 1.0) {
        _firingProgress = 1.0;
        // Hit logic applied
        if (_wasHit) {
           score += _pendingScoreInc;
           effectiveScore += _pendingEffectiveScoreInc;
           
           // Checkpoint Logic
           for (final cp in checkpointScores) {
             if (score >= cp && cp > lastCheckpointScore) {
               lastCheckpointScore = cp;
               lastCheckpointEffectiveScore = effectiveScore;
               AnalyticsManager.logCheckpoint(checkpoint: cp);
             }
           }
           
           hits++;
           
           // Pop effect
           _popCountdown = 2;
           
           // Score text
           _lastScoreText = null;
           if (_pendingScoreInc > 1 && score >= 15 && _rng.nextDouble() < 0.25) {
             _lastScoreText = '+$_pendingScoreInc';
             _scorePopCountdown = 9;
           } else {
             _scorePopCountdown = 0;
           }
           
           // Reset arrow
           arrowY = _firingStartY;
           state = GameState.aiming;
           
           // Randomize range for next pass immediately?
           // The update loop will handle movement.
           
        } else {
          // Miss
          arrowY = targetY; // Stay at target visually
          
          _setHasPlayed();
          
          // Near miss text logic
          if (_pendingMissSeconds != null) {
             final timeStr = _pendingMissSeconds!.toStringAsFixed(3);
             const suffix = 's'; // Simplified
             
             final label = _pendingEarly ? 'EARLY' : 'LATE';
             _pendingNearMissText = '$label\n$timeStr$suffix';
             _nearMissDelayTimer = 0.300;
          }
          
          _handleDeath(_pendingMissSeconds);
        }
      } else {
        // Update arrowY
        // Interpolate from start to target
        arrowY = _firingStartY + (_firingTargetY - _firingStartY) * _firingProgress;
      }
      return; // Skip aiming update logic
    }

    if (state == GameState.aiming) {
      final cx = size.x * 0.5;
      final startX = cx - _currentRange;
      final endX = cx + _currentRange;
      final double oldArrowX = arrowX;
      
      final v = _speed();
      arrowX += v * dt;
      if (arrowX > endX) {
        arrowX = startX + (arrowX - endX);
        // Randomize range for next pass
        _currentRange = 100.0 + _rng.nextDouble() * 50.0;
      }
      if (arrowX < startX) {
        arrowX = startX;
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
        ? (Paint()..color = fg.color.withValues(alpha: 0.6)) 
        : fg;

    canvas.save();
    canvas.translate(cx, cyTarget);
    
    // Draw Progress Circle (Dots)
    const double progressCircleRadius = OneMoreGame.progressCircleRadius;
    const double angleStep = (2 * pi) / OneMoreGame.totalDots;
    // Start from top (-pi/2)
    const double startAngle = -pi / 2;

    // INNER CIRCLE (0-200)
    for (int i = 0; i < OneMoreGame.totalDots; i++) {
      final double angle = startAngle + (i * angleStep);
      final double dotX = progressCircleRadius * cos(angle);
      final double dotY = progressCircleRadius * sin(angle);
      
      // Determine if this dot is active (score based)
      // i=0 corresponds to score 1
      final int dotScore = i + 1;
      
      // If score > 200, all inner dots are active
      final bool isActive = (score > 200) || (score >= dotScore);
      
      // Determine if this dot is a checkpoint
      final bool isCheckpoint = OneMoreGame.checkpointScores.contains(dotScore);
      
      if (isCheckpoint) {
        // Draw Checkpoint Circle
        // Hollow if not reached, filled if reached
        final bool isReached = (score > 200) || (score >= dotScore);
        
        canvas.drawCircle(
          Offset(dotX, dotY),
          4.0, // Radius for checkpoint dot
          Paint()
            ..color = isReached ? const Color(0xFF333333) : const Color(0xFFBBBBBB)
            ..style = isReached ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        // Regular dot
        canvas.drawCircle(
          Offset(dotX, dotY),
          1.5, // Radius for regular dot
          Paint()
            ..color = isActive 
                ? const Color(0xFF333333) // Dark Gray for active
                : const Color(0xFFE0E0E0), // Very Light Gray for inactive
        );
      }
    }
    
    // OUTER CIRCLE (201-500)
    if (score > 200 || OneMoreGame.checkpointScores.any((cp) => cp > 200 && score >= cp)) {
      // Actually, we can just always render the outer circle structure (faded) if we want, 
      // but usually it appears when needed. Let's show it always but inactive, or only when score > 200?
      // User said: "oyuncu 200 ü aştığında bu dairenin çevresinde yeni bir daire oluşsun."
      // So only render if score > 200.
      
      const double progressCircleRadiusOuter = OneMoreGame.progressCircleRadiusOuter;
      const double angleStepOuter = (2 * pi) / OneMoreGame.totalDotsOuter;
      
      for (int i = 0; i < OneMoreGame.totalDotsOuter; i++) {
        final double angle = startAngle + (i * angleStepOuter);
        final double dotX = progressCircleRadiusOuter * cos(angle);
        final double dotY = progressCircleRadiusOuter * sin(angle);
        
        // i=0 corresponds to score 201
        final int dotScore = 201 + i;
        
        final bool isActive = score >= dotScore;
        
        // Checkpoints for outer circle
        final bool isCheckpoint = OneMoreGame.checkpointScores.contains(dotScore);
        
        if (isCheckpoint) {
           final bool isReached = score >= dotScore;
           canvas.drawCircle(
            Offset(dotX, dotY),
            4.0, 
            Paint()
              ..color = isReached ? const Color(0xFF333333) : const Color(0xFFBBBBBB)
              ..style = isReached ? PaintingStyle.fill : PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        } else {
           canvas.drawCircle(
            Offset(dotX, dotY),
            1.5, 
            Paint()
              ..color = isActive 
                  ? const Color(0xFF333333) 
                  : const Color(0xFFE0E0E0), 
          );
        }
      }
    }

    canvas.scale(popScale, popScale);
    canvas.drawCircle(Offset.zero, r, targetPaint);
    canvas.restore();

    const double arrowW = 4.0;
    const double headW = 6.0;
    const double headH = 6.0;
    const double totalH = 40.0;

    final Path arrowPath = Path();
    // Arrow tip is at top
    final double tipY = cyArrow - (totalH / 2);
    final double headBottomY = tipY + headH;
    final double tailY = cyArrow + (totalH / 2);

    // Draw Triangle Tip
    arrowPath.moveTo(arrowX, tipY);
    arrowPath.lineTo(arrowX - (headW / 2), headBottomY);
    arrowPath.lineTo(arrowX + (headW / 2), headBottomY);
    arrowPath.close();

    // Draw Body
    arrowPath.addRect(Rect.fromLTRB(
      arrowX - (arrowW / 2),
      headBottomY,
      arrowX + (arrowW / 2),
      tailY
    ));

    canvas.drawPath(arrowPath, fg);

    // Layout constants
    const double S = OneMoreGame.S;
    const double progressRadius = OneMoreGame.progressCircleRadius;
    
    const double oneMoreFontSize = S * 0.85;
    const double bestFontSize = S * 0.55;
    const double nextFontSize = S * 0.60;
    
    // Reference Point: CenterY (shifted up)
    final double centerY = targetY; 
    
    // ONE MORE (Fixed Anchor - Top)
    // Distance from Target Top to One More Bottom = S * 0.9
    // Target Top = CenterY - radiusStart
    // One More Bottom = (CenterY - radiusStart) - (S * 0.9)
    // Move slightly higher to clear the progress circle
    // Increased gap from 1.5 * S to 2.5 * S
    final double oneMoreY = (centerY - progressRadius) - (S * 2.5);
    
    // SCORE (Fixed Anchor - Bottom)
    // Distance from Target Bottom to Score Top = S
    // Target Bottom = CenterY + radiusStart
    // Score Top = (CenterY + radiusStart) + S
    // Adjusted to be below the progress circle
    // Increased gap from 20 to 40
    final double scoreY = (centerY + progressRadius) + S + 40;
    
    // Near-miss (Above ONE MORE)
    final double nearMissY = oneMoreY - oneMoreFontSize - 12;
    
    // BEST (Below SCORE)
    final double bestY = scoreY + S + 8;
    
    // NEXT (Below BEST)
    final double nextY = bestY + bestFontSize + 8;
    
    // Tap to try again (Below NEXT)
    final double tryAgainY = nextY + nextFontSize + 24;
    
    // Branding (Bottom of screen)
    final double brandingY = size.y - S - 12;

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
    
    // Calculate NEXT target based on checkpoints
    int nextTarget = 500; // Default max
    for (final cp in OneMoreGame.checkpointScores) {
      if (cp > score) {
        nextTarget = cp;
        break;
      }
    }
    // If score is 500 or more, we can just show 500 or "MAX"
    if (score >= 500) nextTarget = 500;

    nextPaint.render(canvas, 'NEXT: $nextTarget', Vector2(cx, nextY), anchor: Anchor.topCenter);
      
      tapToRetryPaint.render(canvas, 'tap to try again', Vector2(cx, tryAgainY), anchor: Anchor.topCenter);
      
      brandingPaint.render(canvas, 'try onemore.now', Vector2(cx, brandingY), anchor: Anchor.bottomCenter);
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
    if (isSharing) return;

    if (event.canvasPosition.y >= size.y * 0.85) {
      return;
    }

    if (state == GameState.dead) {
      if (overlays.isActive('AdRecovery')) return;

      reset();
      return;
    }
    
    if (state != GameState.aiming) {
      return;
    }

    // Transition to Firing State
    state = GameState.firing;
    _firingStartY = arrowY;
    // Target Y is the center of the target. We want arrow to stop there.
    _firingTargetY = targetY; 
    _firingProgress = 0.0;
    
    // Pre-calculate result
    final cx = size.x * 0.5;
    final dx = arrowX - cx;
    _pendingEarly = dx < 0; // True if left of center (early), False if right (late)
    final double visualR = _radius();
    final double microBias = clamp(score * 0.002, 0.0, 0.15);
    final double effectiveR = visualR * (1 - microBias);
    final dist = dx.abs();
    
    _wasHit = (dist <= effectiveR);
    
    // Determine if it's a near miss
    // Near miss: Missed, but VERY close (missSeconds < 0.01s)
    
    if (_wasHit) {
      _isNearMiss = false;
      
      if (!hasPlayed) {
        _setHasPlayed();
      }
      
      // Stop tutorial animations immediately on hit
      _flashOpacity = 0.0;
      _ghostTapOpacity = 0.0;
      _ghostTapTimer = 0.0;
      _ghostTapShown = true; 
      _flashedOnce = true;
      
      final d = dist / effectiveR;
      int inc = 1;
      if (d <= 0.33) {
        inc = 3;
      } else if (d <= 0.70) {
        inc = 2;
      }
      
      _pendingScoreInc = inc;
      
      // Update effectiveScore based on difficulty rules
      if (score + inc <= 10) {
        _pendingEffectiveScoreInc = 0;
      } else if (score + inc <= 30) {
        _pendingEffectiveScoreInc = 0.5;
      } else {
        _pendingEffectiveScoreInc = 1.0;
      }
      
      _pendingMissSeconds = null;

    } else {
      // Miss
      final missDist = dist - effectiveR;
      final missPx = missDist;
      final speed = _speed().abs();
      // approximate time missed by
      final missSeconds = missPx / speed;
      _pendingMissSeconds = missSeconds;
      
      // Check for near miss condition (strict)
      if (missSeconds < 0.050) {
        _isNearMiss = true;
      } else {
        _isNearMiss = false;
      }
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

  // Initialize Ads
  await AdManager.instance.initialize();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GameScreen(),
  ));
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final OneMoreGame _game = OneMoreGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RepaintBoundary(
        key: _globalKey,
        child: GameWidget<OneMoreGame>(
          game: _game,
          overlayBuilderMap: {
            'AdRecovery': (BuildContext context, OneMoreGame game) {
              int nextCheckpoint = -1;
              for (final cp in OneMoreGame.checkpointScores) {
                if (cp > game.score) {
                  nextCheckpoint = cp;
                  break;
                }
              }
              final int diff = nextCheckpoint - game.score;

              return BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Center(
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              diff == 1 ? '1 POINT AWAY' : 'SO CLOSE',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                fontFamily: 'Inter',
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Continue and secure checkpoint $nextCheckpoint?',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  game.overlays.remove('AdRecovery');
                                  AdManager.instance.showRewardedAd(
                                    onUserEarnedReward: () {
                                      game.resumeGame();
                                    },
                                    onAdDismissed: () {
                                      // Stay dead
                                    },
                                    onAdFailed: (error) {
                                      // Stay dead
                                    },
                                  );
                                },
                                child: const Text(
                                  'Continue (Watch 1 Video)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                game.overlays.remove('AdRecovery');
                              },
                              child: const Text(
                                'No thanks',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            'ShareButton': (BuildContext context, OneMoreGame game) {
              return Positioned(
                top: 60,
                right: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Image.asset(
                      'assets/images/share.png',
                      width: 24,
                      height: 24,
                    ),
                    onPressed: _captureAndShare,
                    tooltip: 'Share Score',
                  ),
                ),
              );
            },
          },
        ),
      ),
    );
  }

  Future<void> _captureAndShare() async {
    _game.isSharing = true;
    try {
      // Hide share button before capture
      _game.overlays.remove('ShareButton');
      
      // Wait for a frame to ensure the overlay is removed from the visual tree
      await Future.delayed(const Duration(milliseconds: 50));

      final RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      
      // Show share button again
      _game.overlays.add('ShareButton');

      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        if (kIsWeb) {
             final XFile file = XFile.fromData(
                pngBytes,
                mimeType: 'image/png',
                name: 'onemore_score.png',
              );
              await SharePlus.instance.share(ShareParams(files: [file], text: 'Can you beat my score in One More?'));
          } else {
              final directory = await getTemporaryDirectory();
              final File imgFile = File('${directory.path}/onemore_score.png');
              await imgFile.writeAsBytes(pngBytes);

              final XFile file = XFile(imgFile.path);
              await SharePlus.instance.share(ShareParams(files: [file], text: 'Can you beat my score in One More?'));
          }
      }
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (!_game.overlays.isActive('ShareButton')) {
         _game.overlays.add('ShareButton');
      }
    } finally {
      _game.isSharing = false;
    }
  }
}
