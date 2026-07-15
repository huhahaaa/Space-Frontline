import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 道具飞入动画（Flame 组件）：
/// 阶段 1 (0~0.3s)：掉落位置放大弹出（0 → 1.8×）
/// 阶段 2 (0.3~0.8s)：飞向道具栏区域，逐渐缩小
/// 阶段 3 (0.8~0.9s)：到达后收拢消失
class ItemFlyToBar extends PositionComponent {
  final Vector2 _from;
  final Vector2 _to;
  final Color _color;
  final String _icon;

  double _elapsed = 0;
  static const double _duration = 0.9;

  // 阶段时间点（归一化）
  static const double _tPopEnd = 0.30;   // 放大结束
  static const double _tFlyEnd = 0.82;   // 飞行结束
  static const double _maxScale = 2.1;    // 放大峰值

  ItemFlyToBar({
    required Vector2 from,
    required Color color,
    required String icon,
  })  : _from = from.clone(),
        _to = Vector2(30, 80),
        _color = color,
        _icon = icon,
        super(
          size: Vector2.zero(),
          anchor: Anchor.center,
          priority: 150,
        ) {
    position = _from.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
      return;
    }

    final t = (_elapsed / _duration).clamp(0.0, 1.0);

    if (t <= _tPopEnd) {
      // 阶段 1：原地放大
      position = _from.clone();
    } else if (t <= _tFlyEnd) {
      // 阶段 2：飞向目标
      final flyT = (t - _tPopEnd) / (_tFlyEnd - _tPopEnd);
      final curved = Curves.easeInOutCubic.transform(flyT);
      position = _from + (_to - _from) * curved;
    } else {
      // 阶段 3：到达，微调
      position = _to.clone();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _duration).clamp(0.0, 1.0);

    double scale;
    double opacity;

    if (t <= _tPopEnd) {
      // 放大阶段：0 → maxScale（easeOutBack 弹性）
      final popT = t / _tPopEnd;
      scale = Curves.easeOutBack.transform(popT) * _maxScale;
      opacity = (popT * 0.85).clamp(0.0, 0.85);
    } else if (t <= _tFlyEnd) {
      // 飞行阶段：保持大尺寸 → 逐渐缩小
      final flyT = (t - _tPopEnd) / (_tFlyEnd - _tPopEnd);
      scale = _maxScale - flyT * (_maxScale - 0.55);
      opacity = 0.85;
    } else {
      // 收拢阶段：缩小 + 渐隐
      final landT = (t - _tFlyEnd) / (1.0 - _tFlyEnd);
      scale = 0.55 * (1.0 - landT);
      opacity = 0.85 * (1.0 - landT);
    }

    final r = 20.0 * scale;

    // 外发光（glow）
    canvas.drawCircle(
      Offset.zero,
      r * 1.6,
      Paint()
        ..color = _color.withValues(alpha: opacity * 0.18)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 实心圆
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = _color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );

    // 白色边框
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * scale.clamp(0.3, 1.0),
    );

    // Emoji
    if (scale > 0.2) {
      final tp = TextPainter(
        text: TextSpan(
          text: _icon,
          style: TextStyle(
            color: Colors.white.withValues(alpha: opacity),
            fontSize: 18 * scale.clamp(0.3, 1.0),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }
  }
}
