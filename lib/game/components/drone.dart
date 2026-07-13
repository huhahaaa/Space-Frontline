import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';

/// 无人机 — 位于炮塔右侧，每 5 秒发射大型穿透弹
///
/// 由鼠标控制瞄准方向，准心 UI 提示当前射击目标。
class Drone extends PositionComponent {
  Drone()
      : super(
          size: Vector2(33, 42), // 22×24 放大 ~1.5x
          anchor: Anchor.center,
        );

  /// 当前瞄准方向（弧度）
  double _aimAngle = -pi / 2; // 默认指向上方

  double get aimAngle => _aimAngle;

  /// 更新瞄准目标（世界坐标）
  void aimAt(Vector2 target) {
    final toTarget = target - position;
    _aimAngle = atan2(toTarget.y, toTarget.x);
    angle = _aimAngle; // 旋转整个无人机
  }

  SpriteAnimationComponent? _anim;

  @override
  Future<void> onLoad() async {
    final sheet = await Flame.images.load('drone-1.png');
    final animation = SpriteAnimation.fromFrameData(
      sheet,
      SpriteAnimationData.sequenced(
        amount: 10,
        amountPerRow: 10,
        stepTime: 0.1,
        textureSize: Vector2(22, 24),
        loop: true,
      ),
    );

    _anim = SpriteAnimationComponent(
      animation: animation,
      size: size,
      anchor: Anchor.center,
      position: Vector2.zero(),
    );
    add(_anim!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle = _aimAngle; // 持续跟踪瞄准方向
  }
}
