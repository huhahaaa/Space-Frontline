import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

/// 防御塔 — Turret.png 底座 + 短白炮管
class Tower extends PositionComponent {
  Tower()
      : super(
          size: Vector2(100, 110),
          anchor: Anchor.center,
        );

  double _aimAngle = -pi / 2;

  void aimAt(Vector2 target) {
    final dx = target.x - position.x;
    final dy = target.y - position.y;
    _aimAngle = atan2(dy, dx);
  }

  double get aimAngle => _aimAngle;

  /// 炮口到中心的距离，与绘制炮管等长
  static const double muzzleDistance = 16.0;

  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    _sprite = await Sprite.load('Turret.png');
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 底座精灵 — 画布原点即组件左上角，直接画占满 size
    _sprite?.render(canvas, size: size);

    // 炮管 — 从中心偏上出发，指向目标
    final cx = size.x / 2;
    final cy = size.y * 0.42;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(_aimAngle);

    final halfW = 2.0;
    final len = muzzleDistance;
    canvas.drawRRect(
      RRect.fromLTRBR(0, -halfW, len, halfW, const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    canvas.restore();
  }
}
