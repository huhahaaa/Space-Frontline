import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/defend_the_tower_game.dart';
import '../game/buffs/buff_registry.dart' hide Element;
import '../game/buffs/buff_registry.dart' as be show Element;
import '../game/talent_manager.dart';
import 'widgets/buff_card_overlay.dart';
import '../game/items/item_data.dart';
import 'widgets/item_bar.dart';

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

        // 道具栏
        Positioned(
          top: 40,
          left: 0,
          child: SafeArea(
            child: _ItemBarPoller(game: _game),
          ),
        ),

        // 道具获取横幅（含飞入动画）
        _AcquiredBanner(game: _game),

        // 满槽替换弹窗
        _PendingItemDialog(game: _game),

        // HUD
        _GameHud(game: _game, onBack: _backToMenu),

        // 瞄准提示 / 底部提示
        Positioned(
          bottom: 2,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _AimingHintPoller(game: _game),
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
                if (_data.nextWaveReward)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      '🎁 下一波奖励：随机道具！',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
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

        // ── 正下方中央：炮塔血条 ──
        Positioned(
          bottom: 20,
          left: 12,
          right: 52,
          child: SafeArea(
            child: Container(
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
          ),
        ),

        // ── 右下：Buff 清单按钮 ──
        Positioned(
          right: 4,
          bottom: 160,
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
                  child: Align(
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

/// 道具获取横幅 — 监听 hudNotifier 中 lastAcquiredItem 变化
class _AcquiredBanner extends StatefulWidget {
  final DefendTheTowerGame game;
  const _AcquiredBanner({required this.game});

  @override
  State<_AcquiredBanner> createState() => _AcquiredBannerState();
}

class _AcquiredBannerState extends State<_AcquiredBanner>
    with SingleTickerProviderStateMixin {
  ItemId? _last;
  ItemId? _shown;
  late final AnimationController _anim = AnimationController(
    duration: const Duration(milliseconds: 2200),
    vsync: this,
  );

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (mounted) setState(() {});
    });
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final cur = widget.game.hudNotifier.value.lastAcquiredItem;
      if (cur != null && cur != _last) {
        setState(() {
          _last = cur;
          _shown = cur;
        });
        _anim.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shown == null || _anim.isCompleted) {
      return const SizedBox.shrink();
    }
    final meta = ItemRegistry.data[_shown]!;
    final t = _anim.value;
    final opacity = (t < 0.1 ? t / 0.1 : t > 0.6 ? (1 - t) / 0.4 : 1.0)
        .clamp(0.0, 1.0);
    final slideY =
        -20.0 * (1 - Curves.easeOutCubic.transform(t.clamp(0.0, 1.0)));

    return Positioned(
      top: 70,
      left: 8,
      right: 8,
      child: SafeArea(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slideY),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xDD0D1B2A),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: meta.color.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text('获得',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(meta.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(meta.name,
                      style: TextStyle(
                          color: meta.color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 道具栏轮询器 — 用 Timer 异步刷新，避免 ValueListenableBuilder 在 build 阶段崩溃
class _ItemBarPoller extends StatefulWidget {
  final DefendTheTowerGame game;
  const _ItemBarPoller({required this.game});

  @override
  State<_ItemBarPoller> createState() => _ItemBarPollerState();
}

class _ItemBarPollerState extends State<_ItemBarPoller> {
  Timer? _timer;
  late List<ItemId> _items;
  late ItemId? _aiming;

  @override
  void initState() {
    super.initState();
    final d = widget.game.hudNotifier.value;
    _items = List.from(d.items);
    _aiming = d.aimingItem;
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      final d = widget.game.hudNotifier.value;
      if (!_listEq(d.items, _items) || d.aimingItem != _aiming) {
        setState(() {
          _items = List.from(d.items);
          _aiming = d.aimingItem;
        });
      }
    });
  }

  bool _listEq(List<ItemId> a, List<ItemId> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ItemBar(
      items: _items,
      onTap: (index) => widget.game.useItem(index),
      onLongPress: _aiming == null
          ? (index) => _showItemDetail(context, _items[index])
          : null,
    );
  }
}

/// 瞄准提示轮询器 — 异步轮询，不触发 build 阶段冲突
class _AimingHintPoller extends StatefulWidget {
  final DefendTheTowerGame game;
  const _AimingHintPoller({required this.game});

  @override
  State<_AimingHintPoller> createState() => _AimingHintPollerState();
}

class _AimingHintPollerState extends State<_AimingHintPoller> {
  Timer? _timer;
  ItemId? _aiming;

  @override
  void initState() {
    super.initState();
    _aiming = widget.game.hudNotifier.value.aimingItem;
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      final cur = widget.game.hudNotifier.value.aimingItem;
      if (cur != _aiming) {
        setState(() => _aiming = cur);
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
    if (_aiming != null) {
      return const Text(
        '🎯 点击屏幕选择轨道打击位置',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Color(0xFFFF7043),
            fontSize: 12,
            fontWeight: FontWeight.bold),
      );
    }
    return const Text(
      '🤖 炮塔/无人机自动瞄准',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0x55FFFFFF), fontSize: 9),
    );
  }
}

/// 长按道具显示详情弹窗
void _showItemDetail(BuildContext context, ItemId id) {
  final meta = ItemRegistry.data[id]!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xEE0D1B2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: meta.color.withValues(alpha: 0.5)),
      ),
      title: Row(
        children: [
          Text(meta.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Text(meta.name,
              style: TextStyle(color: meta.color, fontSize: 18)),
        ],
      ),
      content: Text(
        meta.description,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child:
              const Text('关闭', style: TextStyle(color: Colors.white54)),
        ),
      ],
    ),
  );
}

/// 满槽替换弹窗 — 背包满时让玩家选择保留哪个
class _PendingItemDialog extends StatefulWidget {
  final DefendTheTowerGame game;
  const _PendingItemDialog({required this.game});

  @override
  State<_PendingItemDialog> createState() => _PendingItemDialogState();
}

class _PendingItemDialogState extends State<_PendingItemDialog> {
  Timer? _poll;
  ItemId? _pending;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final cur = widget.game.hudNotifier.value.pendingItem;
      if (cur != null && cur != _pending) {
        _pending = cur;
        _showDialog(cur);
      } else if (cur == null && _pending != null) {
        _pending = null;
      }
    });
  }

  void _showDialog(ItemId newId) {
    final newMeta = ItemRegistry.data[newId]!;
    final items = List<ItemId>.from(widget.game.hudNotifier.value.items);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEE0D1B2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: newMeta.color.withValues(alpha: 0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('背包已满',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 新道具展示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: newMeta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: newMeta.color.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(newMeta.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(newMeta.name,
                      style: TextStyle(
                          color: newMeta.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('选择要替换的道具：',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            // 当前道具列表
            ...List.generate(items.length, (i) {
              final meta = ItemRegistry.data[items[i]]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: meta.color.withValues(alpha: 0.15),
                      foregroundColor: meta.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                            color: meta.color.withValues(alpha: 0.4)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.game.confirmItemReplace(i);
                    },
                    child: Row(
                      children: [
                        Text(meta.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(meta.name, style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        const Text('替换 →',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.game.confirmItemReplace(null);
                },
                child: const Text('丢弃新道具，保留原有',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // 如果用户通过系统返回键关闭，也放弃新道具
      if (_pending != null) {
        _pending = null;
        widget.game.confirmItemReplace(null);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
