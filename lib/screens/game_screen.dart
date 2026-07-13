import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/defend_the_tower_game.dart';
import '../game/buffs/buff_registry.dart' hide Element;
import '../game/buffs/buff_registry.dart' as be show Element;
import '../game/talent_manager.dart';
import 'widgets/buff_card_overlay.dart';
import 'widgets/buff_stash_bar.dart';

class GameScreen extends StatefulWidget {
  final int? startWave;
  final String? backgroundName;
  const GameScreen({super.key, this.startWave, this.backgroundName});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DefendTheTowerGame _game;

  @override
  void initState() {
    super.initState();
    final bgName = widget.backgroundName;
    _game = DefendTheTowerGame(
      backgroundName: (bgName != null && bgName.endsWith('.gif')) ? null : bgName,
    );
    _game.onBuffSelectionChanged = _onBuffStateChanged;

    // Victory navigation
    _game.onGameWon = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/victory', arguments: {
            'hp': _game.hp,
            'maxHp': _game.maxHp,
            'kills': _game.killCount,
            'wave': _game.wave,
            'levelId': 'stage_1',
          });
        }
      });
    };

    // 锁定竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _onBuffStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]); // 恢复
    super.dispose();
  }

  void _backToMenu() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        // GIF 背景
        if (widget.backgroundName != null && widget.backgroundName!.endsWith('.gif'))
          Positioned.fill(
            child: Image.asset(
              'assets/images/${widget.backgroundName}',
              fit: BoxFit.cover,
            ),
          ),

        // 游戏画布
        GameWidget(game: _game),

        // Buff 卡片弹窗（暂停遮罩）
        Builder(
          builder: (ctx) {
            final data = _game.hudNotifier.value;
            if (data.buffState == 1 && data.buffChoices != null) {
              return Positioned.fill(
                child: BuffCardOverlay(
                  choices: data.buffChoices!,
                  currentLevels: data.activeBuffs,
                  onSelected: (id) => _game.selectBuff(id),
                  onSkip: () => _game.skipBuff(),
                  onReroll: TalentManager.instance.rerollsRemaining > 0
                      ? () => _game.rerollBuffChoices()
                      : null,
                  rerollsRemaining: TalentManager.instance.rerollsRemaining,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // 暂存槽
        Positioned(
          top: 40,
          left: 0,
          child: SafeArea(
            child: Builder(
              builder: (ctx) {
                final data = _game.hudNotifier.value;
                return BuffStashBar(
                  stash: data.buffStash,
                  activeBuffs: data.activeBuffs,
                  onTap: (index) => _game.selectFromStash(index),
                );
              },
            ),
          ),
        ),

        // HUD
        _GameHud(game: _game, onBack: _backToMenu),

        // 底部提示
        const Positioned(
          bottom: 2,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Text(
              '🤖 炮塔/无人机自动瞄准 · 🏰 城墙守卫',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0x55FFFFFF), fontSize: 9),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// HUD：Timer 轮询，60fps，避开 Flame 构建期冲突
class _GameHud extends StatefulWidget {
  final DefendTheTowerGame game;
  final VoidCallback onBack;
  const _GameHud({required this.game, required this.onBack});

  @override
  State<_GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<_GameHud> {
  Timer? _timer;
  HudData _data = const HudData(
    hp: 50,
    maxHp: 50,
    exp: 0,
    expToNext: 50,
    level: 1,
    wave: 1,
    maxWave: 10,
    waveProgress: 1.0,
    gameWon: false,
    gameOver: false,
    isFinalWave: false,
  );

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted) {
        setState(() {
          _data = widget.game.hudNotifier.value;
        });
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
    final hpPercent =
        _data.maxHp > 0 ? (_data.hp / _data.maxHp).clamp(0.0, 1.0) : 0.0;
    final expPercent = _data.expToNext > 0
        ? (_data.exp / _data.expToNext).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      children: [
        // ── 左上：返回按钮 ──
        Positioned(
          top: 4,
          left: 4,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white38, size: 22),
              onPressed: widget.onBack,
            ),
          ),
        ),

        // ── 顶部中央：波次进度条 ──
        Positioned(
          top: 8,
          left: 48,
          right: 48,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _data.isFinalWave
                      ? '最后一波'
                      : '第 ${_data.wave} / ${_data.maxWave} 波',
                  style: TextStyle(
                    color: _data.isFinalWave
                        ? const Color(0xFFFF4444)
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.cyanAccent.withAlpha(60)),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _data.waveProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: _data.waveProgress > 0.3
                              ? const [
                                  Color(0xFF0088FF),
                                  Color(0xFF00CCFF)
                                ]
                              : const [
                                  Color(0xFFCC4400),
                                  Color(0xFFFF6600)
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 失败 ──
        if (_data.gameOver)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(200),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💀', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      '防线失守',
                      style: TextStyle(
                          color: Color(0xFFFF4444),
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '外星入侵者突破了防线',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: widget.onBack,
                      child: const Text('返回主菜单'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── 底部：城墙血条 ──
        Positioned(
          bottom: 20,
          left: 12,
          right: 12,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标签
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏰', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text('城墙 ${_data.hp} / ${_data.maxHp}',
                            style: TextStyle(
                                color: hpPercent > 0.4
                                    ? Colors.white70
                                    : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text(
                      hpPercent >= 1.0 ? '完好' : hpPercent >= 0.4 ? '受损' : '危急',
                      style: TextStyle(
                          color: hpPercent >= 1.0
                              ? Colors.greenAccent
                              : hpPercent >= 0.4
                                  ? Colors.orangeAccent
                                  : Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // 血条本体
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withAlpha(50), width: 1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: hpPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          colors: hpPercent > 0.4
                              ? [const Color(0xFFCC3333), const Color(0xFFFF6644)]
                              : [const Color(0xFF880000), const Color(0xFFFF2222)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 右下：Buff 清单按钮 ──
        Positioned(
          right: 4,
          bottom: 148,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => _showBuffPanel(context, _data),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withAlpha(160),
                  border: Border.all(
                    color: Colors.cyanAccent.withAlpha(100), width: 1.5),
                ),
                child: const Center(
                  child: Text('📋', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ),

        // ── 右下角：经验条 ──
        Positioned(
          right: 8,
          bottom: 16,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(160),
                    border: Border.all(
                        color: Colors.purpleAccent.withAlpha(180), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      'Lv.${_data.level}',
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 15,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amberAccent.withAlpha(100)),
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: expPercent,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xFF44CC44), Color(0xFF88EE44)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${_data.exp}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _showBuffPanel(BuildContext context, HudData data) {
  if (data.activeBuffs.isEmpty) return;
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xEE0D1B2A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      // 按元素分组排序
      final grouped = <be.Element, List<MapEntry<BuffId, int>>>{};
      for (final e in data.activeBuffs.entries) {
        final meta = BuffRegistry.data[e.key]!;
        grouped.putIfAbsent(meta.element, () => []).add(e);
      }
      // 元素展示顺序
      final elemOrder = [
        be.Element.universal, be.Element.fire, be.Element.ice,
        be.Element.lightning, be.Element.shadow, be.Element.mechanical,
      ];
      // 每组内按名称排序
      for (final list in grouped.values) {
        list.sort((a, b) => BuffRegistry.data[a.key]!.name
            .compareTo(BuffRegistry.data[b.key]!.name));
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('已激活 Buff',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final elem in elemOrder)
                      if (grouped.containsKey(elem))
                        _ElementGroup(
                          element: elem,
                          buffs: grouped[elem]!,
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ElementGroup extends StatelessWidget {
  final be.Element element;
  final List<MapEntry<BuffId, int>> buffs;
  const _ElementGroup({required this.element, required this.buffs});

  String _elemName(be.Element e) => switch (e) {
    be.Element.universal => '⚪ 通用',
    be.Element.fire => '🔥 火焰',
    be.Element.ice => '❄️ 冰霜',
    be.Element.lightning => '⚡ 雷电',
    be.Element.shadow => '🌑 暗影',
    be.Element.mechanical => '⚙️ 机械',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_elemName(element),
              style: TextStyle(
                  color: Color(BuffRegistry.elementColor(element)),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...buffs.map((e) {
            final meta = BuffRegistry.data[e.key]!;
            final lvMeta = meta.level(e.value);
            return Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${meta.icon} ',
                      style: const TextStyle(fontSize: 14)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${meta.name} ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: 'Lv.${e.value}',
                            style: TextStyle(
                                color: Colors.cyanAccent.withAlpha(180),
                                fontSize: 11),
                          ),
                          TextSpan(
                            text: '\n${lvMeta.description}',
                            style: TextStyle(
                                color: Colors.white.withAlpha(160),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
