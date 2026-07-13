import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 伤害/治疗数字 — 弹跳上飘 + 渐隐消失 + 可选元素图标
class DamageNumber extends PositionComponent {
  final double amount;
  final Color color;
  final String icon; // 元素 emoji（'' 则不显示）
  final String _prefix; // '-' 伤害 / '+' 治疗

  double _elapsed = 0;
  static const double _duration = 0.85;
  double _velocityY = 0;

  static final _rng = Random();

  DamageNumber({
    required this.amount,
    required Vector2 at,
    this.color = Colors.white,
    this.icon = '',
  })  : _prefix = '-',
        super(anchor: Anchor.center) {
    position = at + Vector2((_rng.nextDouble() - 0.5) * 16, 0);
    _velocityY = -59 - _rng.nextDouble() * 35;
    size = Vector2(40, 20);
  }

  /// 治疗数字（粉红色 "+x" + 红心图标）
  DamageNumber.heal({
    required this.amount,
    required Vector2 at,
  })  : color = const Color(0xFFFF69B4),
        icon = '❤️',
        _prefix = '+',
        super(anchor: Anchor.center) {
    position = at + Vector2((_rng.nextDouble() - 0.5) * 16, 0);
    _velocityY = -59 - _rng.nextDouble() * 35;
    size = Vector2(40, 20);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
      return;
    }

    // 弹跳：速度逐渐衰减，模拟重力 + 回弹
    _velocityY += 141 * dt; // 重力
    position.y += _velocityY * dt;
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);

    // 弹跳缩放：开始时略大，然后缩回
    double scale;
    if (progress < 0.12) {
      scale = 1.0 + (1.0 - progress / 0.12) * 0.25;
    } else {
      scale = 1.0;
    }

    // 渐隐：前 40% 不透明，之后淡出
    final alpha = progress < 0.4
        ? 1.0
        : (1.0 - (progress - 0.4) / 0.6).clamp(0.0, 1.0);

    final numText = amount <= 0
        ? ''
        : (amount == amount.roundToDouble()
            ? '${amount.toInt()}'
            : amount.toStringAsFixed(1));

    if (numText.isEmpty && icon.isEmpty) return;

    // 数字 + 元素 emoji（纯图标时不带空格和前缀）
    final displayText = numText.isEmpty ? icon : '$_prefix$numText $icon';

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: color.withValues(alpha: alpha),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: alpha * 0.8),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(-textPainter.width / 2 * scale, -textPainter.height / 2 * scale);
    canvas.scale(scale, scale);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}
