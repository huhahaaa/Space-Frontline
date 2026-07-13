import 'package:flame/components.dart';

/// 暗影标记 — 塔对该目标伤害增加
class Marked extends Component {
  final double damageMultiplier; // 塔伤害加成（1.0 + bonus）
  double _remaining;
  bool get isExpired => _remaining <= 0;

  Marked({required this.damageMultiplier, double duration = 3.0})
      : _remaining = duration;

  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
