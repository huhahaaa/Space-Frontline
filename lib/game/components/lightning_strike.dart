import 'dart:ui';
import 'package:flame/components.dart';

/// 落雷视觉特效 — 使用 Lightning/effect-2 帧序列（45帧）
/// 两段式：前 0.7s 蓄力（敌人定身），0.7s 时触发伤害回调
class LightningStrike extends PositionComponent {
  final Vector2 target;
  final double startY;

  /// 伤害判定回调（在 ~0.7s 时触发）
  void Function()? onStrike;

  static const double strikeDelay = 0.7; // 伤害判定时机

  static List<Sprite>? _cachedFrames;
  static bool _loading = false;
  static const int _frameCount = 45;
  static const double _stepTime = 0.018; // 45 帧 × 18ms ≈ 0.81 秒

  /// 预加载精灵（游戏初始化时调用一次）
  static Future<void> preload() async {
    if (_cachedFrames != null || _loading) return;
    _loading = true;
    final frames = <Sprite>[];
    for (int i = 0; i < _frameCount; i++) {
      final num = (i + 1).toString().padLeft(4, '0');
      frames.add(await Sprite.load('lightning_strike/comp_$num.png'));
    }
    _cachedFrames = frames;
    _loading = false;
  }

  /// 每帧雷柱底部在源素材中的水平偏移（归一化到 0~1，即占源图宽度的比例）
  /// 正值 = 偏右，需要向左补偿
  static const List<double> _xOffsets = [
    -0.014, -0.014, -0.002, -0.002, -0.002,   //  1-5
     0.012,  0.012,  0.014,  0.050,  0.050,   //  6-10
     0.093,  0.093, -0.051,  0.024,  0.024,   // 11-15
     0.024,  0.148,  0.160,  0.160,  0.185,   // 16-20
     0.000,  0.000,  0.000,  0.000,  0.142,   // 21-25
     0.142,  0.144,  0.144,  0.000,  0.142,   // 26-30
     0.142,  0.120,  0.106,  0.106,  0.070,   // 31-35
     0.070,  0.066,  0.000,  0.000,  0.083,   // 36-40
     0.048,  0.048,  0.053,  0.053,  0.000,   // 41-45
  ];

  double _elapsed = 0;
  bool _strikeFired = false;
  final double _totalDuration;

  LightningStrike({required this.target, required this.startY, this.onStrike})
      : _totalDuration = _stepTime * _frameCount,
        super(size: Vector2.zero(), anchor: Anchor.center, priority: 55) {
    position = target.clone();
  }

  @override
  Future<void> onLoad() async {
    await preload();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    // 在 strikeDelay 时刻触发伤害
    if (!_strikeFired && _elapsed >= strikeDelay) {
      _strikeFired = true;
      onStrike?.call();
    }
    if (_elapsed >= _totalDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_cachedFrames == null) return;
    final idx = (_elapsed / _stepTime).floor().clamp(0, _frameCount - 1);
    final sprite = _cachedFrames![idx];

    const maxBoltHeight = 400.0;
    final rawHeight = target.y - startY;
    if (rawHeight < 1) return;
    final boltHeight = rawHeight.clamp(0.0, maxBoltHeight);

    // 拉伸精灵到目标高度，宽度按比例
    final srcSize = sprite.srcSize;
    final aspectRatio = srcSize.x / srcSize.y;
    final drawWidth = boltHeight * aspectRatio;
    final drawHeight = boltHeight;

    // 精灵顶部：从 target 向上 boltHeight
    final actualStartY = target.y - boltHeight;

    // 水平补偿偏移使落点居中
    final xOffset = _xOffsets[idx] * drawWidth;
    final drawX = -drawWidth / 2 - xOffset;
    final drawY = actualStartY - target.y;

    sprite.render(
      canvas,
      position: Vector2(drawX, drawY),
      size: Vector2(drawWidth, drawHeight),
    );

    // ── 落点闪光（伤害判定后更强）──
    final progress = (_elapsed / _totalDuration).clamp(0.0, 1.0);
    if (_strikeFired) {
      // 命中后的强闪光
      final postProgress = ((_elapsed - strikeDelay) / (_totalDuration - strikeDelay)).clamp(0.0, 1.0);
      final flashAlpha = ((1.0 - postProgress) * 255).round();
      final flashPaint = Paint()
        ..color = Color.fromARGB(flashAlpha, 0xFF, 0xFF, 0xFF);
      canvas.drawCircle(Offset.zero, 30, flashPaint);
      final glowPaint = Paint()
        ..color = Color.fromARGB((flashAlpha ~/ 2), 0xFF, 0xDD, 0x44)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset.zero, 40, glowPaint);
    } else if (progress < 0.5) {
      // 蓄力阶段的微弱预闪光
      final flashAlpha = ((1.0 - progress / 0.5) * 80).round();
      final flashPaint = Paint()
        ..color = Color.fromARGB(flashAlpha, 0xFF, 0xFF, 0xDD);
      canvas.drawCircle(Offset.zero, 12, flashPaint);
    }
  }
}
