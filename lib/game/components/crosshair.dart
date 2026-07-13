import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 瞄准准心 — 跟随鼠标/手指位置
///
/// 后续可替换为 SpriteComponent 加载美术图片
/// 图片路径：assets/images/crosshair.png
class Crosshair extends PositionComponent {
  Crosshair()
      : super(
          size: Vector2(32, 32),
          anchor: Anchor.center,
          priority: 100, // 渲染在顶层
        );

  /// 每帧由 Game 调用，更新到鼠标位置
  void follow(Vector2 target) {
    position = target;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = const Color(0xCCFF4444)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 外圈（圆环）
    canvas.drawCircle(Offset.zero, 10, paint);

    // 中心点
    canvas.drawCircle(
      Offset.zero,
      2,
      Paint()..color = const Color(0xFFFF4444),
    );

    // 十字线
    canvas.drawLine(const Offset(-14, 0), const Offset(-5, 0), paint);
    canvas.drawLine(const Offset(5, 0), const Offset(14, 0), paint);
    canvas.drawLine(const Offset(0, -14), const Offset(0, -5), paint);
    canvas.drawLine(const Offset(0, 5), const Offset(0, 14), paint);

    // 内圈
    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()
        ..color = const Color(0x88FF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
