import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 道具使用视觉特效 — 彩色光环从指定位置扩散 + 渐隐
///
/// 用法：add(ItemEffectRing(position: pos, color: c, ...));
/// 参照 EmpWave 模式：size 为 zero，anchor center，避免裁剪问题。
class ItemEffectRing extends PositionComponent {
  final double maxRadius;
  final double duration;
  final Color color;

  double _elapsed = 0;

  ItemEffectRing({
    required Vector2 position,
    required this.color,
    this.maxRadius = 120,
    this.duration = 0.6,
  }) : super(
          size: Vector2.zero(),
          anchor: Anchor.center,
          priority: 100,
        ) {
    this.position = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final r = maxRadius * t;
    final opacity = (1.0 - t) * 0.7;

    // 外圈描边
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * (1.0 - t) + 1.5;

    canvas.drawCircle(Offset.zero, r, paint);

    // 内圈填充
    final fill = Paint()
      ..color = color.withValues(alpha: opacity * 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, r * 0.6, fill);
  }
}
