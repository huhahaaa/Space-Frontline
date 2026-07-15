import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 瞄准准心 — 跟随手指位置，带呼吸动画
class Crosshair extends PositionComponent {
  double _pulse = 0;

  Crosshair()
      : super(
          size: Vector2.all(64),
          anchor: Anchor.center,
          priority: 200,
        );

  void follow(Vector2 target) {
    position = target;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    final breathe = 1.0 + sin(_pulse * 4) * 0.15;
    final alpha = (0.7 + sin(_pulse * 3) * 0.3).clamp(0.4, 1.0);
    final s = 20.0 * breathe;

    final paint = Paint()
      ..color = const Color(0xFFFF7043).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * breathe;

    // 外圈
    canvas.drawCircle(Offset.zero, s, paint);
    // 内圈
    canvas.drawCircle(Offset.zero, s * 0.35, paint);

    // 十字线
    canvas.drawLine(Offset(-s, 0), Offset(-s * 0.3, 0), paint);
    canvas.drawLine(Offset(s * 0.3, 0), Offset(s, 0), paint);
    canvas.drawLine(Offset(0, -s), Offset(0, -s * 0.3), paint);
    canvas.drawLine(Offset(0, s * 0.3), Offset(0, s), paint);

    // 中心点
    canvas.drawCircle(
      Offset.zero,
      3.0,
      Paint()
        ..color = const Color(0xFFFF7043).withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
  }
}
