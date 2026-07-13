import 'package:flame/components.dart';

/// 减速状态 — 降低移动速度
class Slowed extends Component {
  final double factor;   // 减速系数（0.3 = 减速 30%）
  double _remaining;
  bool get isExpired => _remaining <= 0;

  Slowed({required this.factor, double duration = 2.0})
      : _remaining = duration;

  /// 剩余减速时间
  double get remaining => _remaining;

  /// 延长减速时间（用于同类 buff 叠加刷新）
  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
