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
                      name: '水银',
                      subtitle: '基础单位 · 大量生成',
                      hp: '3.0 × 倍率',
                      speed: '50 px/s × 倍率',
                      skill: '无',
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
                      subtitle: '第 2 波起 · 中场停驻 · 持续产兵',
                      hp: '6.0 × 倍率',
                      speed: '40 px/s × 倍率',
                      skill: '每 2.5s 释放震荡波消除子弹\n定期在自身位置生成普通敌人',
                      description: '',
                      child: _eliteAnim != null
                          ? _AnimatedPreview(animation: _eliteAnim!)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _EnemyCard(
                      name: '护士',
                      subtitle: '第 4 波起 · 辅助治疗',
                      hp: '4.5 × 倍率',
                      speed: '25 px/s × 倍率',
                      skill: '每 2.5s 净化 100px 内友军\n恢复 80% 已损失 HP',
                      description: '',
                      child: _nurseSprites != null
                          ? _SpriteListPreview(sprites: _nurseSprites!)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _EnemyCard(
                      name: '惊雷',
                      subtitle: '第 6 波起 · 汲取型精英',
                      hp: '4.5 × 倍率',
                      speed: '汲取中 0.5× 基速\n汲取后 0.5~2.0×（按汲取数）',
                      skill: '出场与 3 个电池敌人闪电链相连（三角阵）\n'
                          '每 1.0s 汲取 1 个电池 → 自身获得增益\n'
                          '汲取完成：移速/减伤/闪避 CD 按汲取数梯度\n'
                          '汲取阶段无闪避 · 玩家可击杀电池削弱\n'
                          '弧线冲刺闪避子弹（冲刺中无敌）',
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
