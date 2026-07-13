import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'burning.dart';

/// 燃烧视觉特效 — BurningEffect.png 2×6 序列图，循环播放
/// 作为 child 挂在敌人身上，父级 Burning 状态消失后自动移除
class BurningEffect extends PositionComponent {
  static SpriteAnimation? _cachedAnim;

  double _elapsed = 0;
  static const double _stepTime = 0.06;
  static const int _frameCount = 12;

  /// 随机偏移（相对于父级中心）
  final Vector2 offset;

  BurningEffect({Vector2? offset})
      : offset = offset ?? Vector2.zero(),
        super(size: Vector2.all(40), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    if (_cachedAnim == null) {
      final sheet = await Flame.images.load('BurningEffect.png');
      _cachedAnim = SpriteAnimation.fromFrameData(
        sheet,
        SpriteAnimationData.sequenced(
          amount: _frameCount,
          amountPerRow: 6,
          stepTime: _stepTime,
          textureSize: Vector2(32, 32),
          loop: true,
        ),
      );
    }
    // 子组件统一居中于父级碰撞体
    final p = parent;
    if (p is PositionComponent) {
      position = Vector2(p.size.x / 2, p.size.y / 2) + offset;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    // 父级 Burning 状态消失后自毁
    final p = parent;
    if (p != null && p.firstChild<Burning>() == null) {
      removeFromParent();
      return;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_cachedAnim == null) return;
    final idx = (_elapsed / _stepTime).floor() % _frameCount;
    _cachedAnim!.frames[idx].sprite.render(canvas, size: size);
  }
}
