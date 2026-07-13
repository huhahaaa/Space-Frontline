import 'dart:math';
import 'dart:ui';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'enemy.dart';
import 'nurse_enemy.dart';
import 'projectile.dart';
import 'drone_bullet.dart';
import '../buffs/status_effects/slowed.dart';

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

/// 惊雷 — 躲避子弹，闪电链攻击友军，击杀后逐步强化
/// HP = 普通敌人 ×1.5，移速 = 普通敌人 ×1.5
class JingLeiEnemy extends Enemy {
  JingLeiEnemy({
    super.hpMultiplier = 1.0,
    super.speedMultiplier = 1.0,
  }) : super(variant: null) {
    hp = Enemy.baseHp * hpMultiplier * 1.5;
  }

  @override
  double get maxHp => super.maxHp * 1.5;

  /// 基础移速倍率（击杀友军后会增加）
  double _speedBonus = 0;
  @override
  double get speedFactor => 0.5 + _speedBonus;

  /// 击杀友军计数
  int _friendlyKills = 0;
  static const int _maxKills = 3;

  /// 是否已进入最终形态（3 击杀后）
  bool get isFinalForm => _friendlyKills >= _maxKills;

  @override
  bool get homingResistant => true; // 子弹不追踪惊雷

  // ─── 闪电链攻击友军 ───
  static const double chainDamage = 5.0;
  static const double chainInterval = 1.0; // 每秒一次
  static const double chainRange = 300.0;
  double _chainTimer = chainInterval; // 首击延迟缩短，生成后较快出手

  // ─── 最终形态：50% 减伤 ───
  @override
  void takeDamage(double damage) {
    // 冲刺期间无敌
    if (_dodgeState == _DodgeState.dodging) return;
    if (isFinalForm) damage *= 0.5;
    super.takeDamage(damage);
  }

  /// 是否免疫减速/吸引（最终形态）
  bool get immuneToCrowdControl => isFinalForm;

  // ─── 物理闪避 ───
  static const double _dodgeDetectRadius = 120.0;
  static const double _dodgeThreshold = 38.0;

  // ─── 闪避状态机 ───
  _DodgeState _dodgeState = _DodgeState.idle;
  double _dodgeTimer = 0;
  static const double _dodgeDuration = 0.18;
  double get _cooldownDuration => isFinalForm ? 3.0 : 0.75;

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
    if (!isFinalForm) {
      _chainTimer += dt;
    } else {
      firstChild<Slowed>()?.removeFromParent();
    }
    // 始终更新残影年龄和粒子（无论闪避状态）
    for (final a in _afterimages) {
      a.age += dt;
    }
    _afterimages.removeWhere((a) => a.age > 0.2);
    for (final p in _particles) {
      p.pos.add(p.vel * dt);
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    // 冻结/恐惧时不启动新闪避，但允许完成正在进行的冲刺
    if (!isFrozen && !isFeared) {
      _dodgeBullets(dt);
    } else if (_dodgeState == _DodgeState.dodging) {
      _updateDodging(dt);
    }
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
      // Anchor.center: canvas origin is top-left of component
      // Scale around center = translate to center, scale, translate back
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
    // 收集所有威胁子弹（不只是最近的一个）
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
      // 生成候选闪避方向
      final candidates = <Vector2>[];
      for (final threat in threats) {
        // 后退方向：远离子弹来向
        final backDir = (position - threat.pos);
        if (backDir.length > 0.001) {
          candidates.add(backDir.normalized());
        }
        // 垂直于子弹飞行方向的两个方向
        final bulletDir = threat.vel.normalized();
        candidates.add(Vector2(-bulletDir.y, bulletDir.x));   // 垂直左
        candidates.add(Vector2(bulletDir.y, -bulletDir.x));   // 垂直右
      }

      // 获取地图边界
      final gameSize = g.size;
      const margin = 40.0; // 留边距防止贴边
      const dashDist = 80.0;

      // 底线附近：禁止向上闪避（不能退缩，只能横移或继续向下）
      final nearBottom = position.y > gameSize.y * 0.80;

      // 筛选 + 评分：终点必须在地图内，选离所有威胁最远的
      Vector2? bestDodgeDir;
      double bestScore = -double.infinity;
      for (final dir in candidates) {
        // 底线附近排除向上的方向（远离炮塔 = 退缩，不允许）
        if (nearBottom && dir.y < -0.3) continue;
        // 最终形态：只向前（向下，向炮塔）闪避
        if (isFinalForm && dir.y < 0) continue;

        final endPos = position + dir * dashDist;
        // 边界检查
        if (endPos.x < margin || endPos.x > gameSize.x - margin) continue;
        if (endPos.y < margin || endPos.y > gameSize.y - margin) continue;

        // 综合评分：对所有威胁的加权距离（越近的威胁权重越大）
        double score = 0;
        for (final t in threats) {
          final d = (endPos - t.predicted).length;
          score += d * d; // 平方加权，偏好远离最近的威胁
        }
        if (score > bestScore) {
          bestScore = score;
          bestDodgeDir = dir;
        }
      }

      // 如果没有方向能完全在地图内，选一个最不坏的（允许 clamp）
      if (bestDodgeDir == null) {
        // 重试：选综合评分最高的方向，即使可能出界
        for (final dir in candidates) {
          double score = 0;
          final endPos = position + dir * dashDist;
          // 越界惩罚
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

  /// easeOut 缓动函数（先快后慢）
  double _easeOut(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
  }

  /// 启动弧线冲刺
  /// [evadeDir] — 选定的闪避方向单位向量
  /// [gameSize] — 地图尺寸，用于边界 clamp
  void _startDodge(Vector2 evadeDir, Vector2 gameSize) {
    _dodgeState = _DodgeState.dodging;
    _dodgeTimer = 0;
    _dodgeStartPos = position.clone();
    _dodgeDirection = evadeDir.clone();

    // 终点：起点 + evadeDir * 80px（clamp 到地图边界内）
    const dashDist = 80.0;
    var endPos = _dodgeStartPos + evadeDir * dashDist;
    final margin = size.x; // 留一个自身宽度
    endPos.x = endPos.x.clamp(margin, gameSize.x - margin);
    endPos.y = endPos.y.clamp(margin, gameSize.y - margin);
    _dodgeEndPos = endPos;

    // 控制点：中点 + 垂直于闪避方向的随机侧向偏移（产生真正的弧线！）
    final mid = (_dodgeStartPos + _dodgeEndPos) * 0.5;
    final perp = Vector2(-evadeDir.y, evadeDir.x); // 垂直于闪避方向
    // 随机侧向偏移 ±25px，方向随机
    final sideOffset = (_rng.nextDouble() - 0.5) * 2 * 25.0;
    _dodgeControlPoint = mid + perp * sideOffset;

    // 清空残影和粒子
    _afterimages.clear();
    _afterimageSampleAccum = 0;
    _particles.clear();
    _particleEmitAccum = 0;

    // 重置缩放
    _scaleBounce = 1.0;
  }

  /// 每帧更新冲刺逻辑
  void _updateDodging(double dt) {
    _dodgeTimer += dt;

    final t = (_dodgeTimer / _dodgeDuration).clamp(0.0, 1.0);
    final easedT = _easeOut(t);

    // 二次贝塞尔曲线插值：B(t) = (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
    final oneMinusT = 1.0 - easedT;
    final a = oneMinusT * oneMinusT;
    final b = 2 * oneMinusT * easedT;
    final c = easedT * easedT;

    position.x = a * _dodgeStartPos.x + b * _dodgeControlPoint.x + c * _dodgeEndPos.x;
    position.y = a * _dodgeStartPos.y + b * _dodgeControlPoint.y + c * _dodgeEndPos.y;

    // 边界保护：防止冲出地图
    final g = findGame();
    if (g != null) {
      final gs = g.size;
      final m = size.x;
      position.x = position.x.clamp(m, gs.x - m);
      position.y = position.y.clamp(m, gs.y - m);
    }

    // 缩放微弹：0→0.1s(55%进度) 膨胀到 1.15，0.1→0.18s 缩回 1.0
    if (t < 0.55) {
      _scaleBounce = 1.0 + (t / 0.55) * 0.15;
    } else {
      _scaleBounce = 1.15 - ((t - 0.55) / 0.45) * 0.15;
    }

    // 采样残影
    _afterimageSampleAccum += dt;
    if (_afterimageSampleAccum >= _afterimageSampleInterval &&
        _afterimages.length < _maxAfterimages) {
      _afterimageSampleAccum = 0;
      _afterimages.add(_Afterimage(position: position.clone()));
    }

    // 发射粒子
    _particleEmitAccum += dt;
    while (_particleEmitAccum >= 1.0 / _particleEmitRate) {
      _particleEmitAccum -= 1.0 / _particleEmitRate;
      _emitDodgeParticle();
    }

    // 冲刺结束 → 进入冷却
    if (_dodgeTimer >= _dodgeDuration) {
      _dodgeState = _DodgeState.cooldown;
      _dodgeTimer = 0;
      _scaleBounce = 1.0;
    }
  }

  void _emitDodgeParticle() {
    // 后向扇形：冲刺反方向 ±60°
    final baseAngle = atan2(_dodgeDirection.y, _dodgeDirection.x) + 3.14159; // 反向（π）
    final spread = (_rng.nextDouble() - 0.5) * (3.14159 / 3); // ±60°
    final angle = baseAngle + spread;
    final speed = 40.0 + _rng.nextDouble() * 80.0; // 40–120 px/s
    final life = 0.2 + _rng.nextDouble() * 0.1; // 0.2–0.3s
    final size = 2.0 + _rng.nextDouble() * 2.0; // 2–4px

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
      // 透明度曲线：0→0.05s 淡入到 0.35，0.05→0.2s 淡出到 0
      double alpha;
      if (a.age < 0.05) {
        alpha = (a.age / 0.05) * 0.35;
      } else {
        alpha = 0.35 * (1.0 - (a.age - 0.05) / 0.15);
      }
      alpha = alpha.clamp(0.0, 0.35);
      if (alpha <= 0.01) continue;

      // 残影在世界坐标中的位置 → 转换为相对于组件当前位置的偏移
      final localOffset = a.position - position;

      canvas.save();
      // 移动到残影应该显示的位置（相对于组件原点）
      canvas.translate(localOffset.x, localOffset.y);

      // 使用 saveLayer 做淡紫色颜色混合
      canvas.saveLayer(
        Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y),
        Paint(),
      );

      // 渲染精灵（在 (0,0)，即残影位置的中心，因为 anchor 是 center）
      sprite.render(
        canvas,
        size: size,
        overridePaint: Paint()
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(180, 140, 255, alpha),
            BlendMode.srcATop,
          ),
      );

      canvas.restore(); // restore saveLayer
      canvas.restore(); // restore translate
    }
  }

  void _renderParticles(Canvas canvas) {
    if (_particles.isEmpty) return;

    for (final p in _particles) {
      final lifeRatio = (p.life / 0.3).clamp(0.0, 1.0);
      if (lifeRatio <= 0.01) continue;

      // 转为相对于组件原点的本地坐标
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

  /// 是否应该在本帧触发闪电链攻击
  bool shouldChainAttack() {
    if (isDead || isFinalForm) return false;
    if (_chainTimer >= chainInterval) {
      _chainTimer = 0;
      return true;
    }
    return false;
  }

  /// 对最近的普通敌人发出闪电链
  /// 返回 (target, wasKilled) 或 null
  ({PositionComponent target, bool killed})? tryChainAttack(
    Iterable<PositionComponent> allEnemies,
  ) {
    if (isDead || isFinalForm) return null;

    // 找最近的普通敌人（排除自身和其他惊雷/精英/护士）
    Enemy? nearest;
    double nearestDist = double.infinity;
    for (final e in allEnemies.whereType<Enemy>()) {
      if (e == this) continue;
      if (e is JingLeiEnemy || e is NurseEnemy) continue;
      if (e.isDead) continue;
      final d = e.position.distanceTo(position);
      if (d < chainRange && d < nearestDist) {
        nearestDist = d;
        nearest = e;
      }
    }
    if (nearest == null) return null;

    // 造成伤害
    nearest.takeDamage(chainDamage);
    final wasKilled = nearest.isDead;

    return (target: nearest, killed: wasKilled);
  }

  /// 记录击杀友军（由游戏调用）
  void onFriendlyKilled() {
    if (isFinalForm) return;
    _friendlyKills++;
    _speedBonus = _friendlyKills * 0.5;
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
