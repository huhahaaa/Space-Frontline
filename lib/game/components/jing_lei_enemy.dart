import 'dart:math';
import 'dart:ui';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'enemy.dart';
import 'elite_trait.dart';
import 'projectile.dart';
import 'drone_bullet.dart';

/// 闪避状态机
enum _DodgeState { idle, dodging, cooldown }

/// 残影采样数据
class _Afterimage {
  final Vector2 position;
  double age;
  _Afterimage({required this.position}) : age = 0;
}

/// 冲刺粒子
class _DodgeParticle {
  final Vector2 pos;
  final Vector2 vel;
  double life;
  final double size;
  _DodgeParticle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
  });
}

/// 惊雷 — 汲取三角阵中的电池敌人，完成后获得移速/减伤/闪避
///
/// **阶段一（汲取阶段）**：惊雷 + 3 电池以 0.5x 移速向下移动。
/// 每 1.0s 汲取一个电池（电池死亡），惊雷获得一份增益。
/// 玩家可在间隔中击杀电池，减少惊雷最终增益。
/// 汲取阶段惊雷不闪避、不减伤。
///
/// **阶段二（最终形态）**：根据实际汲取次数获得一次性属性：
/// - 移速 = 0.5 + 汲取数 * 0.5
/// - 减伤 = 0% / 20% / 35% / 50%（汲取 0/1/2/3）
/// - 闪避 CD = 1.25 / 1.0 / 0.85 / 0.75s
class JingLeiEnemy extends Enemy with EliteTrait {
  JingLeiEnemy({
    super.hpMultiplier = 1.0,
    super.speedMultiplier = 1.0,
  }) : super(variant: null) {
    hp = Enemy.baseHp * hpMultiplier * 1.5;
  }

  @override
  double get maxHp => super.maxHp * 1.5;

  // ─── 汲取阶段 ───
  final List<Enemy> _linkedEnemies = [];
  int _drainCount = 0;
  double _drainTimer = 0;
  static const double _drainInterval = 1.0;
  bool _drainPhaseComplete = false;

  /// 汲取阶段中惊雷是否静止等待（汲取完成前不移动，完成后开始向下）
  bool get isDrainPhaseComplete => _drainPhaseComplete;

  /// 汲取数量（0~3）
  int get drainCount => _drainCount;

  /// 汲取动画回调（由游戏侧设置，用于添加 DrainArrow）
  void Function(Vector2 position)? onDrain;

  /// 电池被汲取死亡回调（由游戏侧设置，用于添加 DeathExplosion）
  void Function(Vector2 position)? onBatteryDrained;

  /// 由游戏调用，注册一个电池敌人
  void registerLinkedEnemy(Enemy e) {
    _linkedEnemies.add(e);
  }

  /// 由游戏调用，当电池被玩家击杀时通知惊雷
  void onLinkedEnemyKilledByPlayer(Enemy e) {
    // 电池已被玩家击杀 — 从汲取队列中自然排除
    // _drainNextEnemy 中会跳过已死亡的电池
  }

  // ─── 移速 ───
  double _speedBonus = 0; // 汲取完成后一次性设置
  @override
  double get speedFactor {
    if (!_drainPhaseComplete) return 0.5; // 汲取阶段固定 0.5x
    return 0.5 + _speedBonus;
  }

  @override
  bool get homingResistant => true;

  @override
  int get expValue => 30; // 精英级经验

  // ─── 减伤（按汲取数梯度）───
  double get _damageReduction {
    switch (_drainCount) {
      case 0: return 0.0;
      case 1: return 0.20;
      case 2: return 0.35;
      case 3: return 0.50;
      default: return 0.50;
    }
  }

  @override
  void takeDamage(double damage) {
    if (_dodgeState == _DodgeState.dodging) return;
    if (_drainPhaseComplete && _damageReduction > 0) {
      damage *= (1.0 - _damageReduction);
    }
    super.takeDamage(damage);
  }

  @override
  double effectiveDamage(double incoming) {
    if (isDead || _dodgeState == _DodgeState.dodging) return 0;
    if (_drainPhaseComplete && _damageReduction > 0) {
      return incoming * (1.0 - _damageReduction);
    }
    return incoming;
  }

  // ─── 闪避 ───
  static const double _dodgeDetectRadius = 120.0;
  static const double _dodgeThreshold = 38.0;

  _DodgeState _dodgeState = _DodgeState.idle;
  double _dodgeTimer = 0;
  static const double _dodgeDuration = 0.18;

  /// 闪避 CD（按汲取数梯度）
  double get _cooldownDuration {
    switch (_drainCount) {
      case 0: return 1.25;
      case 1: return 1.0;
      case 2: return 0.85;
      case 3: return 0.75;
      default: return 0.75;
    }
  }

  // ─── 弧线冲刺参数 ───
  Vector2 _dodgeStartPos = Vector2.zero();
  Vector2 _dodgeControlPoint = Vector2.zero();
  Vector2 _dodgeEndPos = Vector2.zero();
  Vector2 _dodgeDirection = Vector2.zero();

  // ─── 残影 ───
  final List<_Afterimage> _afterimages = [];
  static const double _afterimageSampleInterval = 0.04;
  static const int _maxAfterimages = 3;
  double _afterimageSampleAccum = 0;

  // ─── 粒子 ───
  final List<_DodgeParticle> _particles = [];
  final Random _rng = Random();
  static const double _particleEmitRate = 30;
  double _particleEmitAccum = 0;

  // ─── 视觉效果 ───
  double _scaleBounce = 1.0;
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    // ─── 汲取阶段计时 ───
    if (!_drainPhaseComplete) {
      _drainTimer += dt;
      if (_drainTimer >= _drainInterval) {
        _drainTimer = 0;
        _drainNextEnemy();
      }
    }

    // ─── 残影 + 粒子（始终更新）───
    for (final a in _afterimages) {
      a.age += dt;
    }
    _afterimages.removeWhere((a) => a.age > 0.2);
    for (final p in _particles) {
      p.pos.add(p.vel * dt);
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    // ─── 闪避：仅在最终形态启用 ───
    if (_drainPhaseComplete) {
      if (!isFrozen && !isFeared) {
        _dodgeBullets(dt);
      } else if (_dodgeState == _DodgeState.dodging) {
        _updateDodging(dt);
      }
    }
  }

  /// 汲取下一个活着的电池
  void _drainNextEnemy() {
    // 找第一个还活着的电池
    Enemy? target;
    for (final e in _linkedEnemies) {
      if (!e.isDead) {
        target = e;
        break;
      }
    }
    if (target == null) {
      // 所有电池都已死亡 → 进入最终形态
      _finalizeDrainPhase();
      return;
    }

    // 汲取：秒杀电池（不显示伤害数字）
    final batteryPos = target.position.clone();
    target.takeDamage(9999);
    _drainCount++;

    // 触发汲取箭头动画
    onDrain?.call(position.clone());

    // 电池死亡爆炸
    onBatteryDrained?.call(batteryPos);

    // 移除电池（DrainLink 会自检死亡并自移除）
    target.removeFromParent();

    // 检查是否所有电池都死了
    final allDead = _linkedEnemies.every((e) => e.isDead);
    if (allDead) {
      _finalizeDrainPhase();
    }
  }

  /// 汲取阶段结束 → 一次性应用最终属性
  void _finalizeDrainPhase() {
    _drainPhaseComplete = true;
    _speedBonus = _drainCount * 0.5;

    // 清除所有残留的电池引用中的闪电链（DrainLink 会自动检测死亡并自移除）
    _linkedEnemies.clear();
  }

  @override
  void render(Canvas canvas) {
    // ── 绘制粒子（在本体下方）──
    _renderParticles(canvas);

    // ── 绘制残影（在本体下方）──
    _renderAfterimages(canvas);

    // ── 绘制本体（带冲刺缩放微弹）──
    canvas.save();
    if (_scaleBounce != 1.0) {
      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(_scaleBounce, _scaleBounce);
      canvas.translate(-size.x / 2, -size.y / 2);
    }
    super.render(canvas);
    canvas.restore();

    // ── 冲刺紫色覆盖（本体上方）──
    if (_dodgeState == _DodgeState.dodging) {
      final overlay = Paint()
        ..color = Color.fromRGBO(160, 120, 255, 0.25);
      canvas.drawRect(size.toRect(), overlay);
    }

    // ── 汲取阶段视觉标记：闪电光环 ──
    if (!_drainPhaseComplete && !isDead) {
      final ringPaint = Paint()
        ..color = const Color(0xFFFFD740).withValues(alpha: 0.12 + 0.08 * (_drainTimer % 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.85,
        ringPaint,
      );
    }
  }

  void _dodgeBullets(double dt) {
    final g = findGame();
    if (g == null) return;

    // 冷却中：计时
    if (_dodgeState == _DodgeState.cooldown) {
      _dodgeTimer += dt;
      if (_dodgeTimer >= _cooldownDuration) {
        _dodgeState = _DodgeState.idle;
        _dodgeTimer = 0;
      }
      return;
    }

    // 冲刺中：继续弧线运动
    if (_dodgeState == _DodgeState.dodging) {
      _updateDodging(dt);
      return;
    }

    // IDLE 状态：收集威胁 + 生成多候选闪避方向
    final threats = <({Vector2 pos, Vector2 vel, Vector2 predicted})>[];
    for (final c in g.children) {
      Vector2 bulletPos, bulletVel;
      if (c is Projectile) {
        bulletPos = c.position;
        bulletVel = c.velocity;
      } else if (c is DroneBullet) {
        bulletPos = c.position;
        bulletVel = c.direction * c.speed;
      } else {
        continue;
      }

      final toSelf = position - bulletPos;
      final dist = toSelf.length;
      if (dist > _dodgeDetectRadius) continue;

      final dot = toSelf.dot(bulletVel);
      if (dot < 0) continue;

      final t = dot / bulletVel.dot(bulletVel);
      if (t > 0.5) continue;

      final predicted = bulletPos + bulletVel * t;
      final missDist = (position - predicted).length;
      if (missDist > _dodgeThreshold) continue;

      threats.add((pos: bulletPos, vel: bulletVel, predicted: predicted));
    }

    if (threats.isNotEmpty) {
      final candidates = <Vector2>[];
      for (final threat in threats) {
        final bulletDir = threat.vel.normalized();
        candidates.add(Vector2(-bulletDir.y, bulletDir.x));
        candidates.add(Vector2(bulletDir.y, -bulletDir.x));
      }

      final diagCandidates = [
        Vector2(-0.707, 0.707),
        Vector2(0.707, 0.707),
        Vector2(-0.707, -0.707),
        Vector2(0.707, -0.707),
        Vector2(-1.0, 0.0),
        Vector2(1.0, 0.0),
      ];
      candidates.addAll(diagCandidates);

      final gameSize = g.size;
      const margin = 40.0;
      const dashDist = 80.0;

      Vector2? bestDodgeDir;
      double bestScore = -double.infinity;
      for (final dir in candidates) {
        if (dir.y < -0.5 && dir.x.abs() < 0.4) continue;

        final endPos = position + dir * dashDist;
        if (endPos.x < margin || endPos.x > gameSize.x - margin) continue;
        if (endPos.y < margin || endPos.y > gameSize.y - margin) continue;

        double score = 0;
        for (final t in threats) {
          final d = (endPos - t.predicted).length;
          score += d * d;
        }
        if (score > bestScore) {
          bestScore = score;
          bestDodgeDir = dir;
        }
      }

      if (bestDodgeDir == null) {
        for (final dir in candidates) {
          double score = 0;
          final endPos = position + dir * dashDist;
          double boundPenalty = 0;
          if (endPos.x < 0) boundPenalty += (0 - endPos.x) * 5;
          if (endPos.x > gameSize.x) boundPenalty += (endPos.x - gameSize.x) * 5;
          if (endPos.y < 0) boundPenalty += (0 - endPos.y) * 5;
          if (endPos.y > gameSize.y) boundPenalty += (endPos.y - gameSize.y) * 5;
          for (final t in threats) {
            final d = (endPos - t.predicted).length;
            score += d * d;
          }
          score -= boundPenalty;
          if (score > bestScore) {
            bestScore = score;
            bestDodgeDir = dir;
          }
        }
      }

      if (bestDodgeDir != null) {
        _startDodge(bestDodgeDir, gameSize);
      }
    }
  }

  double _easeOut(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
  }

  void _startDodge(Vector2 evadeDir, Vector2 gameSize) {
    _dodgeState = _DodgeState.dodging;
    _dodgeTimer = 0;
    _dodgeStartPos = position.clone();
    _dodgeDirection = evadeDir.clone();

    const dashDist = 80.0;
    var endPos = _dodgeStartPos + evadeDir * dashDist;
    final margin = size.x;
    endPos.x = endPos.x.clamp(margin, gameSize.x - margin);
    endPos.y = endPos.y.clamp(margin, gameSize.y - margin);
    _dodgeEndPos = endPos;

    final mid = (_dodgeStartPos + _dodgeEndPos) * 0.5;
    final perp = Vector2(-evadeDir.y, evadeDir.x);
    final sideOffset = (_rng.nextDouble() - 0.5) * 2 * 25.0;
    _dodgeControlPoint = mid + perp * sideOffset;

    _afterimages.clear();
    _afterimageSampleAccum = 0;
    _particles.clear();
    _particleEmitAccum = 0;

    _scaleBounce = 1.0;
  }

  void _updateDodging(double dt) {
    _dodgeTimer += dt;

    final t = (_dodgeTimer / _dodgeDuration).clamp(0.0, 1.0);
    final easedT = _easeOut(t);

    final oneMinusT = 1.0 - easedT;
    final a = oneMinusT * oneMinusT;
    final b = 2 * oneMinusT * easedT;
    final c = easedT * easedT;

    position.x = a * _dodgeStartPos.x + b * _dodgeControlPoint.x + c * _dodgeEndPos.x;
    position.y = a * _dodgeStartPos.y + b * _dodgeControlPoint.y + c * _dodgeEndPos.y;

    final g = findGame();
    if (g != null) {
      final gs = g.size;
      final m = size.x;
      position.x = position.x.clamp(m, gs.x - m);
      position.y = position.y.clamp(m, gs.y - m);
    }

    if (t < 0.55) {
      _scaleBounce = 1.0 + (t / 0.55) * 0.15;
    } else {
      _scaleBounce = 1.15 - ((t - 0.55) / 0.45) * 0.15;
    }

    _afterimageSampleAccum += dt;
    if (_afterimageSampleAccum >= _afterimageSampleInterval &&
        _afterimages.length < _maxAfterimages) {
      _afterimageSampleAccum = 0;
      _afterimages.add(_Afterimage(position: position.clone()));
    }

    _particleEmitAccum += dt;
    while (_particleEmitAccum >= 1.0 / _particleEmitRate) {
      _particleEmitAccum -= 1.0 / _particleEmitRate;
      _emitDodgeParticle();
    }

    if (_dodgeTimer >= _dodgeDuration) {
      _dodgeState = _DodgeState.cooldown;
      _dodgeTimer = 0;
      _scaleBounce = 1.0;
    }
  }

  void _emitDodgeParticle() {
    final baseAngle = atan2(_dodgeDirection.y, _dodgeDirection.x) + 3.14159;
    final spread = (_rng.nextDouble() - 0.5) * (3.14159 / 3);
    final angle = baseAngle + spread;
    final speed = 40.0 + _rng.nextDouble() * 80.0;
    final life = 0.2 + _rng.nextDouble() * 0.1;
    final size = 2.0 + _rng.nextDouble() * 2.0;

    _particles.add(_DodgeParticle(
      pos: position.clone(),
      vel: Vector2(cos(angle), sin(angle)) * speed,
      life: life,
      size: size,
    ));
  }

  void _renderAfterimages(Canvas canvas) {
    if (_afterimages.isEmpty || frames == null || frames!.isEmpty) return;
    final sprite = frames![currentFrame];

    for (final a in _afterimages) {
      double alpha;
      if (a.age < 0.05) {
        alpha = (a.age / 0.05) * 0.35;
      } else {
        alpha = 0.35 * (1.0 - (a.age - 0.05) / 0.15);
      }
      alpha = alpha.clamp(0.0, 0.35);
      if (alpha <= 0.01) continue;

      final localOffset = a.position - position;

      canvas.save();
      canvas.translate(localOffset.x, localOffset.y);

      canvas.saveLayer(
        Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y),
        Paint(),
      );

      sprite.render(
        canvas,
        size: size,
        overridePaint: Paint()
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(180, 140, 255, alpha),
            BlendMode.srcATop,
          ),
      );

      canvas.restore();
      canvas.restore();
    }
  }

  void _renderParticles(Canvas canvas) {
    if (_particles.isEmpty) return;

    for (final p in _particles) {
      final lifeRatio = (p.life / 0.3).clamp(0.0, 1.0);
      if (lifeRatio <= 0.01) continue;

      final localOffset = p.pos - position;
      final r = p.size / 2;

      _particlePaint.shader = Gradient.radial(
        Offset(localOffset.x, localOffset.y),
        r,
        [
          Color.fromRGBO(200, 160, 255, lifeRatio),
          Color.fromRGBO(140, 100, 220, lifeRatio * 0.3),
          Color.fromRGBO(100, 60, 200, 0),
        ],
        [0.0, 0.3, 1.0],
      );

      canvas.drawCircle(Offset(localOffset.x, localOffset.y), r, _particlePaint);
    }
  }

  @override
  Future<void> onLoad() async {
    final image = await Flame.images.load('enemy-3.png');
    frames = List.generate(4, (i) {
      return Sprite(
        image,
        srcPosition: Vector2(i * 32.0, 0),
        srcSize: Vector2(32, 32),
      );
    });

    final src = frames!.isNotEmpty ? frames![0].srcSize : Vector2(32, 32);
    final scale = 38.4 / src.y;
    size = Vector2(src.x * scale, src.y * scale);
    anchor = Anchor.center;
  }
}
