import 'dart:ui';
import 'package:flame/components.dart';

/// 城墙 — 横跨屏幕底部，根据耐久切换精灵
class Wall extends PositionComponent {
  Sprite? _spriteFull;   // 100%
  Sprite? _spriteMid;    // 40%~99%
  Sprite? _spriteLow;    // <40%

  int _hp = 100;
  int _maxHp = 100;

  Wall() : super(anchor: Anchor.bottomCenter, priority: 10);

  int get hp => _hp;
  int get maxHp => _maxHp;

  double get hpPercent => _maxHp > 0 ? _hp / _maxHp : 0;

  void updateHp(int hp, int maxHp) {
    _hp = hp;
    _maxHp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    _spriteFull = await Sprite.load('wall_1.png');
    _spriteMid = await Sprite.load('wall_2.png');
    _spriteLow = await Sprite.load('Wall_3.png');
  }

  /// 由 game 在 resize 时调用，设置城墙宽高
  void setScreenSize(double screenW, double screenH) {
    // 城墙宽度 = 屏幕宽度，高度按 sprite 比例
    final sprite = _currentSprite;
    if (sprite == null) return;
    final ratio = sprite.srcSize.y / sprite.srcSize.x;
    final w = screenW;
    final h = w * ratio;
    size = Vector2(w, h);
    position = Vector2(screenW / 2, screenH);
  }

  Sprite? get _currentSprite {
    if (_hp >= _maxHp && _spriteFull != null) return _spriteFull;
    if (hpPercent >= 0.4) return _spriteMid ?? _spriteFull ?? _spriteLow;
    return _spriteLow ?? _spriteMid ?? _spriteFull;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final sprite = _currentSprite;
    if (sprite != null) {
      sprite.render(canvas, size: size);
    }
  }
}
