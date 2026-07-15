import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 汲取箭头动画 — 惊雷汲取电池时头顶冒出的 ↑ 箭头
///
/// 0.35s 生命周期：
/// - 箭头从惊雷头顶 (-20px) 上升至 (-55px)
/// - 同时从 0.5x 放大至 1.3x
/// - 最后 30% 渐隐
/// - 带外发光效果
class DrainArrow extends PositionComponent {
  double _elapsed = 0;
  static const double _duration = 0.35;

  DrainArrow({required Vector2 at})
      : super(size: Vector2.zero(), anchor: Anchor.center, priority: 160) {
    position = at.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _duration).clamp(0.0, 1.0);

    // 垂直上移
    final offsetY = -20 - 35 * t;

    // 缩放：0.5 → 1.3
    final scale = 0.5 + t * 0.8;

    // 透明度：前 70% 保持 1.0，后 30% 渐隐至 0
    final opacity = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;

    if (opacity <= 0.01) return;

    final fontSize = 26 * scale;

    // 外发光
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD740).withValues(alpha: opacity * 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(
      Offset(0, offsetY),
      fontSize * 0.5,
      glowPaint,
    );

    // ↑ 箭头文字
    final tp = TextPainter(
      text: TextSpan(
        text: '⚡',
        style: TextStyle(
          color: const Color(0xFFFFD740).withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, offsetY - tp.height / 2));
  }
}
