import 'package:flame/components.dart';

/// 冻结状态 — 完全停止移动
class Frozen extends Component {
  double _remaining;
  bool get isExpired => _remaining <= 0;

  Frozen({double duration = 1.0}) : _remaining = duration;

  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
