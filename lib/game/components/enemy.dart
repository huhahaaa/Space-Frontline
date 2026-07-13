import 'dart:ui';
import 'package:flame/components.dart';
import '../buffs/status_effects/burning.dart';
import '../buffs/status_effects/slowed.dart';
import '../buffs/status_effects/frozen.dart';
import '../buffs/status_effects/marked.dart';
import '../buffs/status_effects/feared.dart';

/// 敌人视觉变体
enum EnemyVariant { type1 }

/// 外星敌人 — 从天空降落的入侵者
class Enemy extends PositionComponent {
  final double hpMultiplier;
  final double speedMultiplier;
  final EnemyVariant variant;

  Enemy({
    this.hpMultiplier = 1.0,
    this.speedMultiplier = 1.0,
    EnemyVariant? variant,
  })  : variant = variant ?? _randomVariant(),
        super(size: Vector2.all(35.2), anchor: Anchor.center);

  /// 随机选择变体
  static EnemyVariant _randomVariant() => EnemyVariant.type1;

  // ─── 属性 ───
  static const double baseSpeed = 50.0;
  static const double baseHp = 3.0;

  late double hp = baseHp * hpMultiplier;
  double get maxHp => baseHp * hpMultiplier;
  double get speedFactor => 1.0; // 子类可覆盖（护士 0.5×）

  bool get isDead => hp <= 0;
  bool get homingResistant => false; // 惊雷覆盖，禁用子弹追踪
  int expValue = 10;

  // ─── 精灵（子类可访问）───
  Sprite? enemySprite;
  List<Sprite>? frames;
  int currentFrame = 0;
  double animTimer = 0;
  static const double animFrameTime = 0.15;

  @override
  Future<void> onLoad() async {
    enemySprite = await Sprite.load('enemy-1.png');
    final src = enemySprite!.srcSize;
    final scale = 38.4 / src.y;
    size = Vector2(src.x * scale, src.y * scale);
    anchor = Anchor.center;
  }

  // ─── 状态查询 ───
  bool get isSlowed => firstChild<Slowed>() != null;
  Slowed? get slowed => firstChild<Slowed>();
  bool get isFrozen => firstChild<Frozen>() != null;
  bool get isFeared => firstChild<Feared>() != null;
  bool get isBurning => firstChild<Burning>() != null;
  bool get isMarked => firstChild<Marked>() != null;
  bool isFlammable = false; // 火焰风暴施加的易燃debuff

  void takeDamage(double damage) {
    hp -= damage;
  }

  // ─── 每帧更新 ───
  @override
  void update(double dt) {
    super.update(dt);

    // 帧动画
    if (frames != null && frames!.isNotEmpty) {
      animTimer += dt;
      if (animTimer >= animFrameTime) {
        animTimer = 0;
        currentFrame = (currentFrame + 1) % frames!.length;
      }
    }

    // 冻结时不移动
    if (isFrozen) return;

    // 恐惧时反向（向上）移动
    if (isFeared) {
      position.y -= baseSpeed * speedMultiplier * dt;
      return;
    }

    // 减速判定
    final slowFactor = isSlowed ? (1.0 - slowed!.factor) : 1.0;
    final effectiveSpeed = baseSpeed * slowFactor;
    position.y += effectiveSpeed * speedMultiplier * speedFactor * dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (frames != null && frames!.isNotEmpty) {
      frames![currentFrame].render(canvas, size: size);
    } else {
      enemySprite?.render(canvas, size: size);
    }
  }
}
