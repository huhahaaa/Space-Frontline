import 'package:flame/components.dart';

/// 净化保护 — 被护士净化后 1s 内免疫火焰风暴吸引与易燃
class PurgeProtected extends Component {
  double _remaining;

  PurgeProtected({double duration = 1.0}) : _remaining = duration;

  bool get isActive => _remaining > 0;

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
