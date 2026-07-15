import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';

/// 汲取闪电链 — 惊雷与电池敌人之间的持续连锁
///
/// 动态引用两端敌人位置，每帧更新中点。
/// 任一端死亡后自移除。
/// 渲染带发光效果的锯齿闪电折线 + alpha 脉冲。
class DrainLink extends PositionComponent {
  final PositionComponent _fromRef;
  final PositionComponent _toRef;

  double _pulseTimer = 0;
  final Random _rng = Random();

  DrainLink({
    required PositionComponent fromRef,
    required PositionComponent toRef,
  })  : _fromRef = fromRef,
        _toRef = toRef,
        super(size: Vector2.zero(), anchor: Anchor.center, priority: 80) {
    position = (fromRef.position + toRef.position) / 2;
  }

  bool get _eitherDead {
    if (_fromRef.isRemoving || _toRef.isRemoving) return true;
    if (_fromRef is Enemy && _fromRef.isDead) return true;
    if (_toRef is Enemy && _toRef.isDead) return true;
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_eitherDead) {
      removeFromParent();
      return;
    }
    _pulseTimer += dt;
    position = (_fromRef.position + _toRef.position) / 2;
  }

  @override
  void render(Canvas canvas) {
    if (_eitherDead) return;

    final from = _fromRef.position;
    final to = _toRef.position;

    // 转换为以本组件为原点的本地坐标
    final localFrom = from - position;
    final localTo = to - position;

    final dir = localTo - localFrom;
    final dist = dir.length;
    if (dist < 2) return;

    // Alpha 脉冲：0.55 ~ 0.9
    final pulseAlpha = 0.55 + 0.35 * (_pulseTimer * 4.0 % 1.0 > 0.5
        ? (1.0 - (_pulseTimer * 4.0 % 1.0 - 0.5) * 2)
        : (_pulseTimer * 4.0 % 1.0) * 2);

    // 外发光
    canvas.drawLine(
      localFrom.toOffset(),
      localTo.toOffset(),
      Paint()
        ..color = const Color(0xFF40C4FF).withValues(alpha: pulseAlpha * 0.25)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 主线
    canvas.drawLine(
      localFrom.toOffset(),
      localTo.toOffset(),
      Paint()
        ..color = const Color(0xFF80D8FF).withValues(alpha: pulseAlpha * 0.7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // 内芯（更亮）
    canvas.drawLine(
      localFrom.toOffset(),
      localTo.toOffset(),
      Paint()
        ..color = Colors.white.withValues(alpha: pulseAlpha * 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 锯齿折线装饰（沿连线路径偏移）
    final normal = Vector2(-dir.y, dir.x).normalized();
    final segments = (dist / 18).ceil().clamp(3, 12);
    final path = Path();
    path.moveTo(localFrom.x, localFrom.y);
    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      final baseX = localFrom.x + dir.x * t;
      final baseY = localFrom.y + dir.y * t;
      final jitter = ((_rng.nextDouble() - 0.5) * 2) * 10.0;
      final px = baseX + normal.x * jitter;
      final py = baseY + normal.y * jitter;
      path.lineTo(px, py);
    }
    path.lineTo(localTo.x, localTo.y);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB3E5FC).withValues(alpha: pulseAlpha * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }
}
