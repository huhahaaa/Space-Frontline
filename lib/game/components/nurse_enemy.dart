import 'dart:ui';
import 'package:flame/components.dart';
import 'enemy.dart';
import 'elite_enemy.dart';
import '../buffs/status_effects/burning.dart';
import '../buffs/status_effects/shocked.dart';
import '../buffs/status_effects/slowed.dart';
import '../buffs/status_effects/purge_protected.dart';

/// 护士敌人 — 第 5 波后出现，每 2.5s 净化 + 治疗周围敌人（含自身）
/// HP = 普通敌人 ×1.5，移速 = 普通敌人 ×0.5
class NurseEnemy extends Enemy {
  NurseEnemy({
    super.hpMultiplier = 1.0,
    super.speedMultiplier = 1.0,
  }) : super(variant: null) {
    hp = Enemy.baseHp * hpMultiplier * 1.5;
  }

  // ─── 属性覆盖 ───
  @override
  double get maxHp => super.maxHp * 1.5;

  @override
  double get speedFactor => 0.5;

  // ─── 净化 + 治疗光环（每 2.5s 跳一次）───
  static const double purgeRadius = 100.0;
  static const double healMissingPercent = 0.80; // 已损失 HP 的 80%
  static const double purgeInterval = 2.5;

  double _purgeTimer = 0;
  double _highlightTimer = 0;
  static const double _highlightDuration = 0.5;

  @override
  void update(double dt) {
    super.update(dt);
    _purgeTimer += dt;
    if (_highlightTimer > 0) _highlightTimer -= dt;
  }

  /// 返回本帧是否应该触发净化
  bool shouldPurgeTick() {
    if (isDead) return false;
    if (_purgeTimer >= purgeInterval) {
      _purgeTimer = 0;
      _highlightTimer = _highlightDuration;
      return true;
    }
    return false;
  }

  /// 对范围内敌人执行净化 + 治疗，返回飘字列表
  List<({PositionComponent target, double amount})> purgeTick(
    Iterable<PositionComponent> allEnemies,
  ) {
    final results = <({PositionComponent target, double amount})>[];
    if (isDead) return results;

    for (final e in allEnemies) {
      if (e is! Enemy && e is! EliteEnemy) continue;

      final dist = e.position.distanceTo(position);
      if (dist > purgeRadius) continue;

      // ── 净化：移除燃烧、感电、减速 ──
      e.firstChild<Burning>()?.removeFromParent();
      e.firstChild<Shocked>()?.removeFromParent();
      e.firstChild<Slowed>()?.removeFromParent();
      // 1s 免疫火焰风暴吸引 + 易燃
      e.add(PurgeProtected());

      // ── 治疗：已损失 HP × 80% ──
      final double maxHp;
      final double currentHp;
      if (e is Enemy) {
        maxHp = e.maxHp;
        currentHp = e.hp;
      } else if (e is EliteEnemy) {
        maxHp = e.maxHp;
        currentHp = e.hp;
      } else {
        continue;
      }

      final missing = maxHp - currentHp;
      if (missing <= 0.01) continue;

      final healAmount = missing * healMissingPercent;
      if (e is Enemy) {
        e.hp = (currentHp + healAmount).clamp(0.0, maxHp);
      } else if (e is EliteEnemy) {
        e.hp = (currentHp + healAmount).clamp(0.0, maxHp);
      }

      results.add((target: e, amount: healAmount));
    }

    return results;
  }

  @override
  Future<void> onLoad() async {
    frames = [];
    for (int i = 1; i <= 3; i++) {
      frames!.add(await Sprite.load('enemy-4/$i.png'));
    }

    final src = frames!.isNotEmpty ? frames![0].srcSize : Vector2(32, 32);
    final scale = 52.0 / src.y;
    size = Vector2(src.x * scale, src.y * scale);
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = size.x * 0.38;

    // 高亮期间光晕更强+更大，随后线性衰减回正常
    final highlightT = _highlightTimer > 0
        ? (_highlightTimer / _highlightDuration).clamp(0.0, 1.0)
        : 0.0;
    final glowAlpha = 0.15 + 0.75 * highlightT;
    final glowR = r * (1.0 + 0.35 * highlightT);

    // 径向渐变：中心最亮 → 边缘完全透明，天然无轮廓
    final glowPaint = Paint()
      ..shader = Gradient.radial(
        Offset(cx, cy),
        glowR,
        [
          Color.fromRGBO(255, 120, 170, glowAlpha),
          Color.fromRGBO(255, 160, 200, glowAlpha * 0.5),
          Color.fromRGBO(255, 140, 180, 0),
        ],
        [0.0, 0.3, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), glowR, glowPaint);
  }
}
