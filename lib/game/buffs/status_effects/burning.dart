import 'dart:ui';
import 'package:flame/components.dart';

/// 燃烧伤害来源
enum BurnSource { scorchingShot, emberEcho, splitShot }

/// 灼烧状态 — 按来源追踪层数，同源覆盖、异源叠加
///
/// 每层 = 1.0 DPS（基础值），不同来源的层数相加得到总 DPS
class Burning extends PositionComponent {
  /// 来源 → 层数（同来源写入覆盖，不同来源并存叠加）
  final Map<BurnSource, double> sourceStacks = {};

  double _remaining;
  bool get isExpired => _remaining <= 0;

  Burning({double duration = 3.0})
      : _remaining = duration,
        super(size: Vector2.zero(), anchor: Anchor.center);

  /// 总 DPS = 各来源层数之和（每层 = 1.0 DPS）
  double get dps {
    double total = 0;
    for (final v in sourceStacks.values) {
      total += v;
    }
    return total;
  }

  /// 是否有指定来源的燃烧
  bool hasSource(BurnSource source) => sourceStacks.containsKey(source);

  /// 施加燃烧：同来源覆盖层数，异源叠加
  void apply(BurnSource source, double stacks, double duration) {
    sourceStacks[source] = stacks;
    if (duration > _remaining) _remaining = duration;
  }

  /// 叠加燃烧（同来源也叠加，用于余烬余波 Lv.3）
  void addStacks(BurnSource source, double stacks, double duration) {
    sourceStacks[source] = (sourceStacks[source] ?? 0) + stacks;
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // 灼烧视觉在 enemy 渲染时处理（BurningEffect），此处不绘制
  }
}
