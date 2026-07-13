import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';

/// 追踪子弹 — 发射后向目标微调方向，确保命中
class Projectile extends PositionComponent {
  final Vector2 direction;
  final double damage;
  final double speed;

  /// 追踪目标（可为 null，不追踪时直飞）
  PositionComponent? target;

  /// 追踪强度（0=不追踪, 1=瞬间转向, 建议 0.1~0.3）
  final double homingStrength;

  final String _spriteName;

  /// 是否触发命中 Buff（分裂弹 Lv.3 之前为 false）
  final bool applyBuffs;

  /// 缩放比例（分裂弹 = 0.5）
  final double visualScale;

  /// 是否为分裂弹（不再触发分裂，防止递归）
  final bool isSplit;

  /// 碰撞忽略的敌人（分裂弹不命中源敌人）
  PositionComponent? ignoreEnemy;

  Projectile({
    required this.direction,
    this.ignoreEnemy,
    this.damage = 1.0,
    this.speed = 440.0,
    this.target,
    this.homingStrength = 0.15,
    this.applyBuffs = true,
    this.visualScale = 1.0,
    this.isSplit = false,
    String spriteName = 'bullet_01.png',
  })  : _spriteName = spriteName,
       super(
          size: Vector2(22, 22),
          anchor: Anchor.center,
        );

  Vector2 _velocity = Vector2.zero();
  /// 当前实际速度向量（含追踪修正），用于外部物理闪避计算
  Vector2 get velocity => _velocity;
  double _lifetime = 0;
  static const double maxLifetime = 3.0;

  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    _velocity = direction * speed;
    _sprite = await Sprite.load(_spriteName);
    // 按精灵图比例调整尺寸
    if (_sprite != null) {
      final src = _sprite!.srcSize;
      const targetHeight = 36.0;
      final scale = targetHeight / src.y * visualScale;
      size = Vector2(src.x * scale, src.y * scale);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 追踪逻辑：每帧微调方向指向目标（惊雷免疫追踪）
    final homingTarget = target;
    if (homingTarget != null &&
        homingTarget.isMounted &&
        !homingTarget.isRemoving &&
        !(homingTarget is Enemy && homingTarget.homingResistant)) {
      final toTarget = homingTarget.absoluteCenter - absoluteCenter;
      if (toTarget.length > 1) {
        final desiredDir = toTarget.normalized();
        // 将当前方向平滑过渡到期望方向
        _velocity.x += (desiredDir.x * speed - _velocity.x) * homingStrength;
        _velocity.y += (desiredDir.y * speed - _velocity.y) * homingStrength;
      }
    }

    position += _velocity * dt;

    // 超时自毁
    _lifetime += dt;
    if (_lifetime > maxLifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final dir = _velocity.normalized();
    final angle = atan2(dir.y, dir.x);

    // ── 子弹精灵图（朝向飞行方向） ──
    if (_sprite != null) {
      canvas.save();
      canvas.translate(0, 0);
      canvas.rotate(angle);
      _sprite!.render(canvas, size: size);
      canvas.restore();
    }
  }
}
