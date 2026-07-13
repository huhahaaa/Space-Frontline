import 'dart:ui';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';

/// EMP 震荡波 — 16 帧序列图（2048×128，1行×16列，每帧128×128）
class EmpWave extends PositionComponent {
  final double maxRadius;
  double _elapsed = 0;
  static const double _expandDuration = 0.48;
  static const double _totalDuration = 0.64;
  static const int _frameCount = 16;
  static const double _frameW = 128;
  static const double _frameH = 128;

  static List<Sprite>? _frames;
  static bool _loading = false;

  /// 预加载（游戏初始化时调用一次）
  static Future<void> preload() async {
    if (_frames != null || _loading) return;
    _loading = true;
    final image = await Flame.images.load('emp.png');
    _frames = List.generate(_frameCount, (i) {
      return Sprite(
        image,
        srcPosition: Vector2(i * _frameW, 0),
        srcSize: Vector2(_frameW, _frameH),
      );
    });
    _loading = false;
  }

  EmpWave({required this.maxRadius})
      : super(size: Vector2.zero(), anchor: Anchor.center, priority: 50);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _totalDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_elapsed >= _totalDuration || _frames == null) return;

    final progress = (_elapsed / _expandDuration).clamp(0.0, 1.0);
    // ease-out 扩展
    final eased = 1.0 - (1.0 - progress) * (1.0 - progress);
    final currentRadius = maxRadius * eased;

    // 帧索引
    final frameIdx =
        ((_elapsed / _totalDuration) * _frameCount).floor().clamp(0, _frameCount - 1);
    final sprite = _frames![frameIdx];

    final diameter = currentRadius * 2;

    // 淡化阶段
    double opacity = 1.0;
    if (_elapsed >= _expandDuration) {
      opacity = 1.0 -
          (_elapsed - _expandDuration) / (_totalDuration - _expandDuration);
    }

    canvas.saveLayer(null, Paint());

    sprite.render(
      canvas,
      position: Vector2(-diameter / 2, -diameter / 2),
      size: Vector2(diameter, diameter),
    );

    // 金色染色
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: diameter, height: diameter),
      Paint()
        ..color = Color.fromRGBO(255, 200, 0, 0.45 * opacity)
        ..blendMode = BlendMode.srcATop,
    );

    canvas.restore();
  }
}
