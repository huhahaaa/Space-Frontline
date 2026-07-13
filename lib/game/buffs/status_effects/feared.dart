import 'package:flame/components.dart';

/// 恐惧状态 — 反方向逃跑
class Feared extends Component {
  double _remaining;
  bool get isExpired => _remaining <= 0;

  Feared({double duration = 1.5}) : _remaining = duration;

  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
