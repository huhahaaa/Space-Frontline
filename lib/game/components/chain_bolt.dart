import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

/// 连锁闪电视觉弹丸 — 金黄色放大版子弹，从敌人 A 飞到敌人 B，到达后自毁
class ChainBolt extends PositionComponent {
  final Vector2 target;
  final double speed;

  static Sprite? _sprite;
  static Paint? _goldPaint;

  ChainBolt({
    required Vector2 from,
    required this.target,
  })  : speed = 500,
        super(size: Vector2.all(14.3), anchor: Anchor.center) { // 11*1.3, 比普攻子弹缩小版大30%
    position = from;
  }

  @override
  Future<void> onLoad() async {
    _sprite ??= await Sprite.load('bullet_01.png');
    _goldPaint ??= (Paint()
      ..colorFilter = const ColorFilter.mode(
        Color(0xFFFFD740),
        BlendMode.srcATop,
      ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final toTarget = target - position;
    final dist = toTarget.length;
    if (dist < 4) {
      removeFromParent();
      return;
    }
    final step = speed * dt;
    if (step >= dist) {
      position = target.clone();
      removeFromParent();
      return;
    }
    position += toTarget.normalized() * step;
  }

  @override
  void render(Canvas canvas) {
    if (_sprite == null) return;
    final dir = target - position;
    if (dir.length < 0.01) return;
    final angle = atan2(dir.y, dir.x);
    canvas.save();
    canvas.translate(0, 0);
    canvas.rotate(angle);
    _sprite!.render(canvas, size: size, overridePaint: _goldPaint);
    canvas.restore();
  }
}
