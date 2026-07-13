import 'dart:async';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/flame.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

class MonsterpediaScreen extends StatefulWidget {
  const MonsterpediaScreen({super.key});

  @override
  State<MonsterpediaScreen> createState() => _MonsterpediaScreenState();
}

class _MonsterpediaScreenState extends State<MonsterpediaScreen> {
  SpriteAnimation? _eliteAnim;
  SpriteAnimation? _jingLeiAnim;
  List<Sprite>? _nurseSprites;
  Sprite? _enemySprite;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final eliteSheet = await Flame.images.load('enemy-2.png');
    _eliteAnim = SpriteAnimation.fromFrameData(
      eliteSheet,
      SpriteAnimationData.sequenced(
        amount: 16,
        amountPerRow: 16,
        stepTime: 0.1,
        textureSize: Vector2(32, 96),
        loop: true,
      ),
    );

    // 惊雷：enemy-3.png，1 行 4 帧，每帧 32×32
    final jingLeiSheet = await Flame.images.load('enemy-3.png');
    _jingLeiAnim = SpriteAnimation.fromFrameData(
      jingLeiSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        amountPerRow: 4,
        stepTime: 0.15,
        textureSize: Vector2(32, 32),
        loop: true,
      ),
    );

    // 护士：enemy-4/，3 张独立精灵
    _nurseSprites = [];
    for (int i = 1; i <= 3; i++) {
      _nurseSprites!.add(await Sprite.load('enemy-4/$i.png'));
    }

    _enemySprite = await Sprite.load('enemy-1.png');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2D3A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '怪物图鉴',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _EnemyCard(
                      name: '普通敌人',
                      subtitle: '基础入侵单位 · 每波大量生成',
                      hp: '3.0 × 波次倍率',
                      speed: '50 px/s × 波次倍率',
                      skill: '无特殊技能',
                      description: '',
                      child: _enemySprite != null
                          ? SpriteWidget(
                              sprite: _enemySprite!,
                              anchor: Anchor.center,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _EnemyCard(
                      name: '沃土',
                      subtitle: '第 2 波起 · 每 4 个普通敌人混 1 个 · 到达中场后停驻',
                      hp: '6.0 × 波次倍率',
                      speed: '40 px/s × 波次倍率 (0.8× 基速)',
                      skill: '停驻后每 2.5 秒释放震荡波，消除普通子弹',
                      description: '',
                      child: _eliteAnim != null
                          ? _AnimatedPreview(animation: _eliteAnim!)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _EnemyCard(
                      name: '护士',
                      subtitle: '第 5 波起 · 每 3 个普通敌人混 1 个 · 辅助治疗单位',
                      hp: '4.5 × 波次倍率 (1.5× 普通敌人)',
                      speed: '25 px/s × 波次倍率 (0.5× 基速)',
                      skill: '每 2.5s 对 100px 内友军净化（清除燃烧/感电/减速）\n并恢复 80% 已损失生命值 · 赋予 1s 火焰风暴免疫',
                      description: '',
                      child: _nurseSprites != null
                          ? _SpriteListPreview(sprites: _nurseSprites!)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _EnemyCard(
                      name: '惊雷',
                      subtitle: '第 1 波起 · 每 6 个普通敌人混 1 个 · 高速闪避型精英',
                      hp: '4.5 × 波次倍率 (1.5× 普通敌人)',
                      speed: '初始 25 px/s × 波次倍率 (0.5× 基速)\n每击杀友军 +0.5× 基速（上限 +1.5×）',
                      skill: '弧线冲刺闪避子弹（0.75s CD，冲刺中无敌）\n'
                          '闪电链攻击 300px 内友军（5 伤害/秒）\n'
                          '击杀 3 友军 → 最终形态：50% 减伤、免疫减速\n'
                          '只向前闪避（3s CD）、触及炮塔伤害 10',
                      description: '',
                      child: _jingLeiAnim != null
                          ? _AnimatedPreview(animation: _jingLeiAnim!)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手动驱动 SpriteAnimation 帧播放
class _AnimatedPreview extends StatefulWidget {
  final SpriteAnimation animation;
  const _AnimatedPreview({required this.animation});

  @override
  State<_AnimatedPreview> createState() => _AnimatedPreviewState();
}

class _AnimatedPreviewState extends State<_AnimatedPreview> {
  Timer? _timer;
  int _frameIndex = 0;
  late final List<Sprite> _frames;

  @override
  void initState() {
    super.initState();
    _frames = widget.animation.frames.map((f) => f.sprite).toList();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      size: const Size(80, 100),
      painter: _SpritePainter(sprite: _frames[_frameIndex]),
    );
  }
}

/// 手动驱动多帧播放（用于独立图片合成的动画，如 enemy-4）
class _SpriteListPreview extends StatefulWidget {
  final List<Sprite> sprites;
  const _SpriteListPreview({required this.sprites});

  @override
  State<_SpriteListPreview> createState() => _SpriteListPreviewState();
}

class _SpriteListPreviewState extends State<_SpriteListPreview> {
  Timer? _timer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() => _frameIndex = (_frameIndex + 1) % widget.sprites.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sprites.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      size: const Size(80, 100),
      painter: _SpritePainter(sprite: widget.sprites[_frameIndex]),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final Sprite sprite;

  _SpritePainter({required this.sprite});

  @override
  void paint(Canvas canvas, Size size) {
    final src = sprite.srcSize;
    final scaleX = size.width / src.x;
    final scaleY = size.height / src.y;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final drawW = src.x * scale;
    final drawH = src.y * scale;
    final ox = (size.width - drawW) / 2;
    final oy = (size.height - drawH) / 2;

    sprite.render(canvas, position: Vector2(ox, oy), size: Vector2(drawW, drawH));
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) => old.sprite != sprite;
}

class _EnemyCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String hp;
  final String speed;
  final String skill;
  final String description;
  final Widget child;

  const _EnemyCard({
    required this.name,
    required this.subtitle,
    required this.hp,
    required this.speed,
    required this.skill,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3340),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(width: 80, height: 100, child: Center(child: child)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 8),
                _infoRow('❤️ 生命', hp),
                _infoRow('🏃 速度', speed),
                _infoRow('⚡ 技能', skill),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ),
    );
  }
}
