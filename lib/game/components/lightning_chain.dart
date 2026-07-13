import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

/// 连锁闪电特效 — 在两敌之间建立链接，播放 25 帧闪电动画（不循环）
class LightningChain extends PositionComponent {
  final Vector2 from;
  final Vector2 to;

  static List<Sprite>? _cachedFrames;
  static bool _loading = false;

  double _elapsed = 0;
  static const double _stepTime = 0.012; // 25 帧 × 12ms = 0.3 秒
  static const int _frameCount = 25;

  /// 预加载精灵（游戏初始化时调用一次）
  static Future<void> preload() async {
    if (_cachedFrames != null || _loading) return;
    _loading = true;
    final frames = <Sprite>[];
    for (int i = 0; i < _frameCount; i++) {
      final num = (i + 1).toString().padLeft(4, '0');
      frames.add(await Sprite.load('lightning_chain/comp_$num.png'));
    }
    _cachedFrames = frames;
    _loading = false;
  }

  LightningChain({required this.from, required this.to})
      : super(anchor: Anchor.center) {
    position = (from + to) / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _stepTime * _frameCount) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_cachedFrames == null) return;
    final idx = (_elapsed / _stepTime).floor().clamp(0, _frameCount - 1);
    final sprite = _cachedFrames![idx];

    final dir = to - from;
    final dist = dir.length;
    if (dist < 1) return;
    final angle = atan2(dir.y, dir.x);

    // 固定高度 = 闪电粗细，宽度拉伸到两点间距
    const boltHeight = 56.0;
    final boltWidth = dist + 16; // 略超出端点，覆盖更好

    canvas.save();
    canvas.rotate(angle);
    // Sprite 以 canvas 原点为左上角，需要偏移使其中心对齐原点
    sprite.render(
      canvas,
      position: Vector2(-boltWidth / 2, -boltHeight / 2),
      size: Vector2(boltWidth, boltHeight),
    );
    canvas.restore();
  }
}
