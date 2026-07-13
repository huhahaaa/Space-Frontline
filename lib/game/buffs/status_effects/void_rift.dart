import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 虚空裂隙 — 持续对范围内敌人造成伤害
class VoidRift extends PositionComponent {
  final double dps;
  final double radius;
  final double pullStrength;
  double _elapsed = 0;
  final double duration;

  VoidRift({
    required this.dps,
    required this.duration,
    this.radius = 60,
    this.pullStrength = 0,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center);

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
    final progress = 1.0 - (_elapsed / duration);
    final paint = Paint()
      ..color = const Color(0xFFAB47BC).withValues(alpha: 0.25 * progress)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFAB47BC).withValues(alpha: 0.6 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, radius * (0.4 + 0.6 * (1 - progress)), paint);
    canvas.drawCircle(Offset.zero, radius * (0.4 + 0.6 * (1 - progress)), stroke);
  }
}
