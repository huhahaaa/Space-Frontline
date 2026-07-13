import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../buffs/status_effects/frozen.dart';
import '../buffs/status_effects/feared.dart';
import '../buffs/status_effects/slowed.dart';
import '../buffs/status_effects/marked.dart';
import '../buffs/status_effects/burning.dart';

/// 精英敌人
class EliteEnemy extends PositionComponent {
  final double hpMultiplier;
  final double speedMultiplier;

  EliteEnemy({
    this.hpMultiplier = 1.0,
    this.speedMultiplier = 1.0,
  }) : super(size: Vector2(24, 72), anchor: Anchor.center);

  // ─── 属性 ───
  static const double baseSpeed = 40.0;
  static const double baseHp = 6.0;

  late double hp = baseHp * hpMultiplier;
  double get maxHp => baseHp * hpMultiplier;

  bool get isDead => hp <= 0;
  int expValue = 30;

  /// 停驻 Y 坐标
  double _stopY = double.infinity;
  set stopY(double v) => _stopY = v;

  bool _stopped = false;
  bool get isStopped => _stopped;

  // ─── 状态查询 ───
  bool get isSlowed => firstChild<Slowed>() != null;
  Slowed? get slowed => firstChild<Slowed>();
  bool get isFrozen => firstChild<Frozen>() != null;
  bool get isFeared => firstChild<Feared>() != null;
  bool get isBurning => firstChild<Burning>() != null;
  bool get isMarked => firstChild<Marked>() != null;
  bool isFlammable = false; // 火焰风暴施加的易燃debuff

  // ─── 动画 ───
  SpriteAnimationComponent? _anim;

  @override
  Future<void> onLoad() async {
    final sheet = await Flame.images.load('enemy-2.png');
    final animation = SpriteAnimation.fromFrameData(
      sheet,
      SpriteAnimationData.sequenced(
        amount: 16, amountPerRow: 16, stepTime: 0.08,
        textureSize: Vector2(32, 96), loop: true,
      ),
    );
    _anim = SpriteAnimationComponent(
      animation: animation, size: size,
      anchor: Anchor.center, position: Vector2(size.x / 2, size.y / 2),
    );
    add(_anim!);
  }

  void takeDamage(double damage) {
    hp -= damage;
  }

  // ─── 震荡波 ───
  double _shockwaveTimer = 0;
  static const double _shockwaveInterval = 2.5;
  static const double _shockwaveDuration = 0.6;
  static const double _shockwaveRadiusFactor = 1.5;

  double _shockwaveElapsed = -1;
  Vector2 _shockwaveCenter = Vector2.zero();

  /// 已释放震荡波次数
  int _shockwaveCount = 0;

  /// 产怪计时器（从第 2 次震荡波开始）
  double _minionSpawnTimer = 0;
  double minionSpawnInterval = 2.0;
  void Function()? onSpawnMinion;

  bool get shockwaveActive => _shockwaveElapsed >= 0;

  double get shockwaveRadius {
    if (!shockwaveActive) return 0;
    final maxDim = size.x > size.y ? size.x : size.y;
    final t = (_shockwaveElapsed / _shockwaveDuration).clamp(0.0, 1.0);
    return maxDim * _shockwaveRadiusFactor * t;
  }

  bool isInsideShockwave(Vector2 point) {
    if (!shockwaveActive) return false;
    return point.distanceTo(_shockwaveCenter) <= shockwaveRadius;
  }

  void _emit() {
    _shockwaveCount++;
    _shockwaveCenter = position.clone();
    _shockwaveElapsed = 0;
    _shockwaveTimer = 0;
  }

  // ─── 移动 ───
  @override
  void update(double dt) {
    super.update(dt);

    if (isFrozen) {
      // 冻结中仍可计时震荡波与产怪
      if (_stopped) {
        _updateShockwave(dt);
        _updateMinionSpawn(dt);
      }
      return;
    }

    if (!_stopped) {
      if (isFeared) {
        position.y -= baseSpeed * speedMultiplier * dt;
      } else {
        final slowFactor = isSlowed ? (1.0 - slowed!.factor) : 1.0;
        final effectiveSpeed = baseSpeed * slowFactor;
        position.y += effectiveSpeed * speedMultiplier * dt;
      }

      if (position.y >= _stopY) {
        position.y = _stopY;
        _stopped = true;
        _emit();
      }
    } else {
      _updateShockwave(dt);
      _updateMinionSpawn(dt);
    }
  }

  void _updateMinionSpawn(double dt) {
    if (_shockwaveCount < 2 || onSpawnMinion == null) return;
    _minionSpawnTimer += dt;
    if (_minionSpawnTimer >= minionSpawnInterval) {
      _minionSpawnTimer = 0;
      onSpawnMinion!();
    }
  }

  void _updateShockwave(double dt) {
    if (_shockwaveElapsed >= 0) {
      _shockwaveElapsed += dt;
      if (_shockwaveElapsed >= _shockwaveDuration) {
        _shockwaveElapsed = -1;
      }
    } else {
      _shockwaveTimer += dt;
      if (_shockwaveTimer >= _shockwaveInterval) {
        _emit();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!shockwaveActive) return;

    final t = (_shockwaveElapsed / _shockwaveDuration).clamp(0.0, 1.0);
    final r = shockwaveRadius;
    final paintFill = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.13 * (1 - t) * 0.6)
      ..style = PaintingStyle.fill;
    final paintOuter = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.67 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final paintThin = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4 * (1 - t) * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(Offset.zero, r * 0.9, paintFill);
    canvas.drawCircle(Offset.zero, r, paintOuter);
    canvas.drawCircle(Offset.zero, r * 1.05, paintThin);
  }
}
