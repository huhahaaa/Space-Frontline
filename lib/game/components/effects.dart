import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

/// 命中闪光 — Hit_effect_01.png 序列图动画（2×6 帧，每帧 32×32）
class HitFlash extends PositionComponent {
  HitFlash({required Vector2 at})
      : super(size: Vector2.all(48), anchor: Anchor.center) { 
    position = at;
  }

  static SpriteAnimation? _cachedAnim;

  double _elapsed = 0;
  static const double _stepTime = 0.04;
  static const int _frameCount = 12;
  double get _duration => _stepTime * _frameCount;

  @override
  Future<void> onLoad() async {
    if (_cachedAnim == null) {
      final sheet = await Flame.images.load('Hit_effect_01.png');
      _cachedAnim = SpriteAnimation.fromFrameData(
        sheet,
        SpriteAnimationData.sequenced(
          amount: _frameCount,
          amountPerRow: 6,
          stepTime: _stepTime,
          textureSize: Vector2(32, 32),
          loop: false,
        ),
      );
    }
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
    if (_cachedAnim == null) return;
    final idx = (_elapsed / _stepTime).floor().clamp(0, _frameCount - 1);
    _cachedAnim!.frames[idx].sprite.render(canvas, size: size);
  }
}

/// 死亡爆炸 — 8 帧精灵动画，播完自动移除
class DeathExplosion extends PositionComponent {
  DeathExplosion({required Vector2 at})
      : super(size: Vector2(80, 80), anchor: Anchor.center) {
    position = at;
  }

  static List<Sprite>? _cachedFrames;

  double _elapsed = 0;
  static const double _stepTime = 0.07;
  static const int _frameCount = 8;
  double get _duration => _stepTime * _frameCount;

  @override
  Future<void> onLoad() async {
    if (_cachedFrames == null) {
      _cachedFrames = [];
      for (int i = 0; i < _frameCount; i++) {
        _cachedFrames!.add(await Sprite.load('explosion/explosion-${i + 1}.png'));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_cachedFrames == null) return;
    final idx = (_elapsed / _stepTime).floor().clamp(0, _frameCount - 1);
    _cachedFrames![idx].render(canvas, size: size);
  }
}
