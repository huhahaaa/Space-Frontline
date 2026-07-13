import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';
import 'elite_enemy.dart';

/// 无人机大型穿透弹 — 伤害 2 倍，穿透敌人不消失
class DroneBullet extends PositionComponent {
  final Vector2 direction;
  final double speed;

  DroneBullet({
    required this.direction,
    this.speed = 560,
  }) : super(
          size: Vector2(69, 30), // 212×92 等比缩放
          anchor: Anchor.center,
        );

  static const double damage = 2.0;
  double _lifetime = 0;
  static const double maxLifetime = 3.0;

  /// 已命中的敌人集合，穿透不重复伤害
  final Set<int> _hitEnemies = {};

  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    _sprite = await Sprite.load('bullet-02.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * speed * dt;

    _lifetime += dt;
    if (_lifetime > maxLifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_sprite != null) {
      // 旋转朝向飞行方向
      final angle = atan2(direction.y, direction.x);
      canvas.save();
      canvas.translate(0, 0);
      canvas.rotate(angle);
      _sprite!.render(canvas, size: size);
      canvas.restore();
    }
  }

  /// 尝试命中敌人，返回是否成功（穿透弹命中后不消失）
  bool tryHit(PositionComponent enemy) {
    final id = enemy.hashCode;
    if (_hitEnemies.contains(id)) return false; // 已命中过
    if (!toRect().overlaps(enemy.toRect())) return false;

    _hitEnemies.add(id);
    if (enemy is Enemy) enemy.takeDamage(damage);
    if (enemy is EliteEnemy) enemy.takeDamage(damage);
    return true;
  }
}
