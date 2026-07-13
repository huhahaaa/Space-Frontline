import 'dart:math';
import 'package:flame/components.dart';

/// 火焰风暴 — 在地图随机位置生成，优先朝敌人移动，吸引敌人并施加「易燃」debuff
class FireStorm extends PositionComponent {
  final double radius;
  final double pullStrength;
  final double duration;

  double _elapsed = 0;
  Vector2 _driftDirection;
  static const double _seekSpeed = 50;
  static const double _turnRate = 1.8; // 转向速率，越低越有厚重感

  static List<Sprite>? _cachedFrames;
  static const int _frameCount = 30;
  static const double _stepTime = 0.07;

  SpriteAnimationComponent? _anim;

  FireStorm({
    required this.radius,
    required this.pullStrength,
    this.duration = 7.5,
  })  : _driftDirection = Vector2.zero(),
        super(size: Vector2.zero(), anchor: Anchor.center, priority: 0) {
    final rng = Random();
    _driftDirection = Vector2(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1).normalized();
  }

  @override
  Future<void> onLoad() async {
    if (_cachedFrames == null) {
      _cachedFrames = [];
      for (int i = 0; i < _frameCount; i++) {
        _cachedFrames!.add(
          await Sprite.load('fire_storm/fire_ball_3_$i.png'),
        );
      }
    }

    final animation = SpriteAnimation.spriteList(
      _cachedFrames!,
      stepTime: _stepTime,
      loop: true,
    );

    _anim = SpriteAnimationComponent(
      animation: animation,
      size: Vector2.all(radius * 2),
      anchor: Anchor.center,
    )..opacity = 0.75;
    add(_anim!);
  }

  /// 索敌：优先朝最近的、尚未卷入风暴的敌人移动（带惯性转向）
  void seekTargets(List<PositionComponent> enemies, double dt) {
    if (enemies.isEmpty) return;

    // 找最近的尚未在风暴范围内的敌人
    PositionComponent? target;
    double nearestDist = double.infinity;
    for (final e in enemies) {
      final dist = e.position.distanceTo(position);
      if (dist > radius && dist < nearestDist) {
        nearestDist = dist;
        target = e;
      }
    }

    if (target != null) {
      final desired = (target.position - position).normalized();
      // 惯性转向：朝目标方向平滑插值，转向速率越低越厚重
      _driftDirection = (_driftDirection + desired * _turnRate * dt).normalized();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
      return;
    }
    position += _driftDirection * _seekSpeed * dt;
  }
}
