import 'package:flame/components.dart';

/// 感电状态 — 每秒受到固定电击伤害
class Shocked extends Component {
  final double dps;
  double _remaining;
  bool get isExpired => _remaining <= 0;

  Shocked({this.dps = 2.0, double duration = 3.0})
      : _remaining = duration;

  /// 刷新持续时间
  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
