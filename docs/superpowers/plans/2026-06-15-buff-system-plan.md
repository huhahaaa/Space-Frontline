# Buff 选择系统 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 每次升级触发三选一 buff 弹窗（游戏暂停），支持暂存最多 3 组 FIFO，同名 buff Lv.1→3 叠加，18 个 buff 覆盖 5 个元素系。

**Architecture:** BuffRegistry（静态数据）→ BuffManager（运行时状态，挂载在 Flame 世界）→ DefendTheTowerGame 通过回调通知 game_screen 弹窗 → 玩家选择后 BuffManager 更新等级 → 各系统读 BuffManager 查询接口应用效果。状态效果以独立 Component 形式挂载在敌人上。

**Tech Stack:** Dart / Flutter / Flame 1.26.1

---

### Task 1: BuffRegistry — 枚举 + 静态注册表

**Files:**
- Create: `lib/game/buffs/buff_registry.dart`

- [ ] **Step 1: 创建 buff_registry.dart**

```dart
/// Buff 标识枚举
enum BuffId {
  rapidFire, powerShot, eagleEye, droneOverload, barrageExpand,
  scorchingShot, fireStorm, emberEcho,
  frostShot, frostNova, frostAura,
  chainLightning, staticField, emp,
  bloodthirst, shadowMark, fearTouch, voidRift,
}

/// 元素分类
enum Element { universal, fire, ice, lightning, shadow }

/// 单级描述
class BuffLevelMeta {
  final String description;
  final Map<String, double> params;
  const BuffLevelMeta({required this.description, this.params = const {}});
}

/// 单个 Buff 的完整定义
class BuffMeta {
  final BuffId id;
  final String name;
  final String icon;
  final Element element;
  final int maxLevel;
  final List<BuffLevelMeta> levels; // [Lv.1, Lv.2, Lv.3]

  const BuffMeta({
    required this.id,
    required this.name,
    required this.icon,
    required this.element,
    this.maxLevel = 3,
    required this.levels,
  });

  /// 获取指定等级的 BuffLevelMeta（等级从 1 开始）
  BuffLevelMeta level(int lv) => levels[lv - 1];
}

/// 静态注册表 — 18 个 buff 的完整定义
class BuffRegistry {
  BuffRegistry._();

  static const Map<BuffId, BuffMeta> data = {
    // ═══ 通用系 ═══
    BuffId.rapidFire: BuffMeta(
      id: BuffId.rapidFire, name: '急速射击', icon: '⚡',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '攻击间隔 -15%', params: {'rate': 0.15}),
        BuffLevelMeta(description: '攻击间隔 -25%', params: {'rate': 0.25}),
        BuffLevelMeta(description: '攻击间隔 -35% · 10%概率双发', params: {'rate': 0.35, 'doubleChance': 0.10}),
      ],
    ),
    BuffId.powerShot: BuffMeta(
      id: BuffId.powerShot, name: '强化弹头', icon: '💥',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '子弹伤害 +30%', params: {'dmg': 0.30}),
        BuffLevelMeta(description: '子弹伤害 +50%', params: {'dmg': 0.50}),
        BuffLevelMeta(description: '子弹伤害 +70% · 对精英额外+20%', params: {'dmg': 0.70, 'eliteBonus': 0.20}),
      ],
    ),
    BuffId.eagleEye: BuffMeta(
      id: BuffId.eagleEye, name: '鹰眼', icon: '👁️',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '索敌范围扩展至 90%', params: {'rangePct': 0.90}),
        BuffLevelMeta(description: '索敌范围扩展至 100%（全屏）', params: {'rangePct': 1.0}),
        BuffLevelMeta(description: '全屏索敌 · 追踪强度 +30%', params: {'rangePct': 1.0, 'homingBonus': 0.30}),
      ],
    ),
    BuffId.droneOverload: BuffMeta(
      id: BuffId.droneOverload, name: '无人机过载', icon: '🚁',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '无人机冷却 5.0→3.5秒', params: {'cooldown': 3.5}),
        BuffLevelMeta(description: '无人机冷却 →2.5秒', params: {'cooldown': 2.5}),
        BuffLevelMeta(description: '无人机冷却 2.5秒 · 双发', params: {'cooldown': 2.5, 'doubleShot': 1.0}),
      ],
    ),
    BuffId.barrageExpand: BuffMeta(
      id: BuffId.barrageExpand, name: '弹幕扩充', icon: '🎯',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '每第 5 发额外追加一弹', params: {'everyN': 5, 'count': 1}),
        BuffLevelMeta(description: '每第 4 发追加一弹', params: {'everyN': 4, 'count': 1}),
        BuffLevelMeta(description: '每第 3 发追加两弹', params: {'everyN': 3, 'count': 2}),
      ],
    ),
    // ═══ 火焰系 ═══
    BuffId.scorchingShot: BuffMeta(
      id: BuffId.scorchingShot, name: '灼热弹头', icon: '🔥',
      element: Element.fire,
      levels: [
        BuffLevelMeta(description: '命中点燃 · 3秒内每秒5伤害', params: {'dps': 5, 'dur': 3.0}),
        BuffLevelMeta(description: '命中点燃 · 每秒8伤害', params: {'dps': 8, 'dur': 3.0}),
        BuffLevelMeta(description: '命中点燃 · 每秒12伤害 · 死亡爆炸', params: {'dps': 12, 'dur': 3.0, 'explode': 1.0}),
      ],
    ),
    BuffId.fireStorm: BuffMeta(
      id: BuffId.fireStorm, name: '火焰风暴', icon: '🌪️',
      element: Element.fire,
      levels: [
        BuffLevelMeta(description: '每第 7 发追加火焰弹（范围灼烧）', params: {'everyN': 7, 'count': 1}),
        BuffLevelMeta(description: '每第 5 发追加火焰弹', params: {'everyN': 5, 'count': 1}),
        BuffLevelMeta(description: '每第 5 发追加双火焰弹', params: {'everyN': 5, 'count': 2}),
      ],
    ),
    BuffId.emberEcho: BuffMeta(
      id: BuffId.emberEcho, name: '余烬余波', icon: '✨',
      element: Element.fire,
      levels: [
        BuffLevelMeta(description: '击杀灼烧敌人 · 灼烧周围', params: {'radius': 100}),
        BuffLevelMeta(description: '击杀灼烧敌人 · 范围+30%', params: {'radius': 130}),
        BuffLevelMeta(description: '击杀灼烧敌人 · 灼烧可多层叠加', params: {'radius': 130, 'stack': 1.0}),
      ],
    ),
    // ═══ 冰霜系 ═══
    BuffId.frostShot: BuffMeta(
      id: BuffId.frostShot, name: '冰霜弹头', icon: '❄️',
      element: Element.ice,
      levels: [
        BuffLevelMeta(description: '命中减速 30% · 持续2秒', params: {'slow': 0.30, 'dur': 2.0}),
        BuffLevelMeta(description: '命中减速 50% · 持续2秒', params: {'slow': 0.50, 'dur': 2.0}),
        BuffLevelMeta(description: '减速 ≥80% 时冻结 1 秒', params: {'slow': 0.50, 'dur': 2.0, 'freeze': 1.0}),
      ],
    ),
    BuffId.frostNova: BuffMeta(
      id: BuffId.frostNova, name: '冰霜新星', icon: '💠',
      element: Element.ice,
      levels: [
        BuffLevelMeta(description: '精英死亡触发冰爆 · 冻结0.8秒', params: {'radius': 120, 'freezeDur': 0.8}),
        BuffLevelMeta(description: '冰爆范围+40% · 冻结1.2秒', params: {'radius': 168, 'freezeDur': 1.2}),
        BuffLevelMeta(description: '被冻敌人死亡也触发小冰爆', params: {'radius': 168, 'freezeDur': 1.2, 'chain': 1.0}),
      ],
    ),
    BuffId.frostAura: BuffMeta(
      id: BuffId.frostAura, name: '极寒光环', icon: '🧊',
      element: Element.ice,
      levels: [
        BuffLevelMeta(description: '塔周围减速 15%', params: {'slow': 0.15, 'radius': 80}),
        BuffLevelMeta(description: '塔周围减速 25%', params: {'slow': 0.25, 'radius': 80}),
        BuffLevelMeta(description: '塔周围减速 25% · 每波 1 层护盾', params: {'slow': 0.25, 'radius': 80, 'shield': 1.0}),
      ],
    ),
    // ═══ 雷电系 ═══
    BuffId.chainLightning: BuffMeta(
      id: BuffId.chainLightning, name: '连锁闪电', icon: '⚡',
      element: Element.lightning,
      levels: [
        BuffLevelMeta(description: '命中弹射 1 次 · 60% 伤害', params: {'chain': 1, 'dmgPct': 0.60}),
        BuffLevelMeta(description: '命中弹射 2 次 · 60% 伤害', params: {'chain': 2, 'dmgPct': 0.60}),
        BuffLevelMeta(description: '弹射可重复命中同一目标', params: {'chain': 2, 'dmgPct': 0.60, 'repeat': 1.0}),
      ],
    ),
    BuffId.staticField: BuffMeta(
      id: BuffId.staticField, name: '静电场', icon: '🌩️',
      element: Element.lightning,
      levels: [
        BuffLevelMeta(description: '每 10 秒随机落雷 · 范围 30 伤害', params: {'interval': 10, 'dmg': 30, 'radius': 70}),
        BuffLevelMeta(description: '每 7 秒落雷', params: {'interval': 7, 'dmg': 30, 'radius': 70}),
        BuffLevelMeta(description: '双雷同时落下', params: {'interval': 7, 'dmg': 30, 'radius': 70, 'doubleStrike': 1.0}),
      ],
    ),
    BuffId.emp: BuffMeta(
      id: BuffId.emp, name: '电磁脉冲', icon: '💫',
      element: Element.lightning,
      levels: [
        BuffLevelMeta(description: '击杀释放 EMP 消除震荡波', params: {'radius': 100}),
        BuffLevelMeta(description: 'EMP 范围 +50%', params: {'radius': 150}),
        BuffLevelMeta(description: '被 EMP 命中精英震荡波 CD +3 秒', params: {'radius': 150, 'shockCdPenalty': 3.0}),
      ],
    ),
    // ═══ 暗影系 ═══
    BuffId.bloodthirst: BuffMeta(
      id: BuffId.bloodthirst, name: '嗜血渴望', icon: '🩸',
      element: Element.shadow,
      levels: [
        BuffLevelMeta(description: '击杀 5% 概率回复 5% HP', params: {'chance': 0.05, 'healPct': 0.05}),
        BuffLevelMeta(description: '击杀 10% 概率回复 5% HP', params: {'chance': 0.10, 'healPct': 0.05}),
        BuffLevelMeta(description: '击杀 15% 概率回复 5% HP · 血怒：3秒伤害+20%', params: {'chance': 0.15, 'healPct': 0.05, 'rageDur': 3.0, 'rageDmg': 0.20}),
      ],
    ),
    BuffId.shadowMark: BuffMeta(
      id: BuffId.shadowMark, name: '暗影标记', icon: '🏷️',
      element: Element.shadow,
      levels: [
        BuffLevelMeta(description: '无人机命中标记 · 塔伤害+40% 持续3秒', params: {'dmgBonus': 0.40, 'dur': 3.0}),
        BuffLevelMeta(description: '标记目标 · 塔伤害+60%', params: {'dmgBonus': 0.60, 'dur': 3.0}),
        BuffLevelMeta(description: '标记死亡时传染附近敌人', params: {'dmgBonus': 0.60, 'dur': 3.0, 'spread': 1.0, 'spreadRadius': 120}),
      ],
    ),
    BuffId.fearTouch: BuffMeta(
      id: BuffId.fearTouch, name: '恐惧之触', icon: '👻',
      element: Element.shadow,
      levels: [
        BuffLevelMeta(description: '敌人进入索敌区 15% 概率恐惧 1.5 秒', params: {'chance': 0.15, 'dur': 1.5}),
        BuffLevelMeta(description: '进入索敌区 25% 概率恐惧', params: {'chance': 0.25, 'dur': 1.5}),
        BuffLevelMeta(description: '恐惧碰撞传染', params: {'chance': 0.25, 'dur': 1.5, 'spread': 1.0}),
      ],
    ),
    BuffId.voidRift: BuffMeta(
      id: BuffId.voidRift, name: '虚空裂隙', icon: '🕳️',
      element: Element.shadow,
      levels: [
        BuffLevelMeta(description: '每波 1 个裂隙 · 5 秒 · 每秒 8 伤害', params: {'dps': 8, 'dur': 5.0, 'radius': 60}),
        BuffLevelMeta(description: '每波 1 个裂隙 · 每秒 12 伤害', params: {'dps': 12, 'dur': 5.0, 'radius': 60}),
        BuffLevelMeta(description: '裂隙吸引附近的敌人', params: {'dps': 12, 'dur': 5.0, 'radius': 60, 'pull': 1.0, 'pullStrength': 80}),
      ],
    ),
  };

  /// 所有 BuffId 列表（用于随机抽取）
  static const List<BuffId> allIds = BuffId.values;

  /// 元素 → 颜色映射
  static int elementColor(Element e) => switch (e) {
    Element.universal => 0xFFB0BEC5,
    Element.fire      => 0xFFFF6D3F,
    Element.ice        => 0xFF64B5F6,
    Element.lightning  => 0xFFFFD740,
    Element.shadow     => 0xFFAB47BC,
  };
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/buffs/buff_registry.dart
```

---

### Task 2: BuffCardData — 暂存序列化数据

**Files:**
- Create: `lib/game/buffs/buff_card_data.dart`

- [ ] **Step 1: 创建 buff_card_data.dart**

```dart
import 'buff_registry.dart';

/// 一组待选的 3 张卡片（用于暂存槽持久化）
class BuffCardSet {
  final List<BuffId> choices;
  BuffCardSet(this.choices);

  BuffMeta meta(int index) => BuffRegistry.data[choices[index]]!;
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/buffs/buff_card_data.dart
```

---

### Task 3: BuffManager — 运行时组件

**Files:**
- Create: `lib/game/buffs/buff_manager.dart`

- [ ] **Step 1: 创建 BuffManager 组件**

```dart
import 'dart:math';
import 'package:flame/components.dart';
import 'buff_registry.dart';
import '../components/enemy.dart';
import '../components/elite_enemy.dart';

/// 运行时 Buff 状态管理器，作为 Component 挂载在 Flame 世界中
class BuffManager extends Component {
  final Map<BuffId, int> _levels = {};

  // ─── 查询接口 ───
  int levelOf(BuffId id) => _levels[id] ?? 0;
  bool has(BuffId id) => levelOf(id) > 0;
  Map<BuffId, int> get allLevels => Map.unmodifiable(_levels);

  /// 应用 buff（等级 +1，最多 maxLevel）
  void addLevel(BuffId id) {
    final meta = BuffRegistry.data[id]!;
    if (levelOf(id) >= meta.maxLevel) return;
    _levels[id] = levelOf(id) + 1;
  }

  // ─── 随机生成 3 张候选卡 ───
  List<BuffId> generateChoices({int count = 3}) {
    final rng = Random();
    final available = <BuffId>[];
    for (final id in BuffId.values) {
      final meta = BuffRegistry.data[id]!;
      if (levelOf(id) < meta.maxLevel) {
        available.add(id);
      }
    }
    available.shuffle(rng);
    final result = available.take(count).toList();
    // 不足时补齐（理论上不会发生，18 个 buff 三级 = 54 格）
    if (result.length < count) {
      final extras = BuffId.values.where((id) => !result.contains(id)).toList()..shuffle(rng);
      for (final id in extras) {
        if (result.length >= count) break;
        result.add(id);
      }
    }
    return result;
  }

  // ═══════════════════════════════════════════
  // 通用系
  // ═══════════════════════════════════════════

  double get fireRateMultiplier {
    return switch (levelOf(BuffId.rapidFire)) {
      1 => 0.85, 2 => 0.75, 3 => 0.65, _ => 1.0,
    };
  }
  bool get rapidFireDoubleShot => levelOf(BuffId.rapidFire) >= 3;
  double get rapidFireDoubleChance => 0.10;

  double get damageMultiplier {
    return switch (levelOf(BuffId.powerShot)) {
      1 => 1.30, 2 => 1.50, 3 => 1.70, _ => 1.0,
    };
  }
  double get powerShotEliteBonus => levelOf(BuffId.powerShot) >= 3 ? 0.20 : 0.0;

  /// 索敌比：底部多少比例是索敌区
  double get rangePercent {
    return switch (levelOf(BuffId.eagleEye)) {
      1 => 0.90, 2 => 1.0, 3 => 1.0, _ => 0.80,
    };
  }
  double get eagleEyeHomingBonus => levelOf(BuffId.eagleEye) >= 3 ? 0.30 : 0.0;

  double get droneCooldown {
    return switch (levelOf(BuffId.droneOverload)) {
      1 => 3.5, 2 => 2.5, 3 => 2.5, _ => 5.0,
    };
  }
  bool get droneDoubleShot => levelOf(BuffId.droneOverload) >= 3;

  int get barrageEveryN {
    return switch (levelOf(BuffId.barrageExpand)) {
      1 => 5, 2 => 4, 3 => 3, _ => 0,
    };
  }
  int get barrageExtraCount => levelOf(BuffId.barrageExpand) >= 3 ? 2 : 1;

  // ═══════════════════════════════════════════
  // 火焰系
  // ═══════════════════════════════════════════

  double get burnDps {
    return switch (levelOf(BuffId.scorchingShot)) {
      1 => 5, 2 => 8, 3 => 12, _ => 0,
    };
  }
  double get burnDuration => 3.0;
  bool get scorchingShotExplosion => levelOf(BuffId.scorchingShot) >= 3;

  int get fireStormEveryN {
    return switch (levelOf(BuffId.fireStorm)) {
      1 => 7, 2 => 5, 3 => 5, _ => 0,
    };
  }
  int get fireStormExtraCount => levelOf(BuffId.fireStorm) >= 3 ? 2 : 1;

  int get emberEchoLevel => levelOf(BuffId.emberEcho);
  double get emberEchoRadius => emberEchoLevel >= 2 ? 130 : 100;
  bool get emberEchoStack => emberEchoLevel >= 3;

  // ═══════════════════════════════════════════
  // 冰霜系
  // ═══════════════════════════════════════════

  double get frostSlowFactor {
    return switch (levelOf(BuffId.frostShot)) {
      1 => 0.30, 2 => 0.50, 3 => 0.50, _ => 0,
    };
  }
  bool get frostShotFreeze => levelOf(BuffId.frostShot) >= 3;

  int get frostNovaLevel => levelOf(BuffId.frostNova);
  double get frostNovaRadius => frostNovaLevel >= 2 ? 168 : 120;
  double get frostNovaFreezeDuration => frostNovaLevel >= 2 ? 1.2 : 0.8;
  bool get frostNovaChain => frostNovaLevel >= 3;

  int get frostAuraLevel => levelOf(BuffId.frostAura);
  double get frostAuraSlow => frostAuraLevel >= 2 ? 0.25 : 0.15;
  double get frostAuraRadius => 80;
  bool get frostAuraShield => frostAuraLevel >= 3;
  int _shieldCount = 0;
  int get shieldCount => _shieldCount;
  void addWaveShield() { if (frostAuraShield) _shieldCount++; }
  /// 消耗一层护盾，返回是否成功
  bool consumeShield() {
    if (_shieldCount <= 0) return false;
    _shieldCount--;
    return true;
  }

  // ═══════════════════════════════════════════
  // 雷电系
  // ═══════════════════════════════════════════

  int get chainCount {
    return switch (levelOf(BuffId.chainLightning)) {
      1 => 1, 2 => 2, 3 => 2, _ => 0,
    };
  }
  double get chainDamageRatio => 0.60;
  bool get chainRepeatTarget => levelOf(BuffId.chainLightning) >= 3;

  int get staticFieldLevel => levelOf(BuffId.staticField);
  double get staticFieldInterval => staticFieldLevel >= 2 ? 7.0 : 10.0;
  double get staticFieldDamage => 30;
  double get staticFieldRadius => 70;
  int get staticFieldCount => staticFieldLevel >= 3 ? 2 : 1;

  int get empLevel => levelOf(BuffId.emp);
  double get empRadius => empLevel >= 2 ? 150 : 100;
  bool get empShockCdPenalty => empLevel >= 3;
  double get empShockCdPenaltyAmount => 3.0;

  // ═══════════════════════════════════════════
  // 暗影系
  // ═══════════════════════════════════════════

  int get bloodthirstLevel => levelOf(BuffId.bloodthirst);
  double get bloodthirstChance {
    return switch (bloodthirstLevel) {
      1 => 0.05, 2 => 0.10, 3 => 0.15, _ => 0,
    };
  }
  double get bloodthirstHealPercent => 0.05;
  bool get bloodthirstRage => bloodthirstLevel >= 3;
  bool _bloodRageActive = false;
  double _bloodRageTimer = 0;
  bool get bloodRageActive => _bloodRageActive;
  double get bloodRageDamageBonus => 0.20;
  void triggerBloodRage() { _bloodRageActive = true; _bloodRageTimer = 3.0; }

  int get shadowMarkLevel => levelOf(BuffId.shadowMark);
  double get shadowMarkDamageBonus => shadowMarkLevel >= 2 ? 0.60 : 0.40;
  double get shadowMarkDuration => 3.0;
  bool get shadowMarkSpread => shadowMarkLevel >= 3;
  double get shadowMarkSpreadRadius => 120;

  int get fearTouchLevel => levelOf(BuffId.fearTouch);
  double get fearTouchChance => fearTouchLevel >= 2 ? 0.25 : 0.15;
  double get fearTouchDuration => 1.5;
  bool get fearTouchSpread => fearTouchLevel >= 3;

  int get voidRiftLevel => levelOf(BuffId.voidRift);
  double get voidRiftDps => voidRiftLevel >= 2 ? 12 : 8;
  double get voidRiftDuration => 5.0;
  double get voidRiftRadius => 60;
  bool get voidRiftPull => voidRiftLevel >= 3;
  double get voidRiftPullStrength => 80;

  // ─── 周期性更新（血怒计时）───
  @override
  void update(double dt) {
    super.update(dt);
    if (_bloodRageActive) {
      _bloodRageTimer -= dt;
      if (_bloodRageTimer <= 0) _bloodRageActive = false;
    }
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/buffs/buff_manager.dart
```

---

### Task 4: 状态效果组件

**Files:**
- Create: `lib/game/buffs/status_effects/burning.dart`
- Create: `lib/game/buffs/status_effects/slowed.dart`
- Create: `lib/game/buffs/status_effects/frozen.dart`
- Create: `lib/game/buffs/status_effects/marked.dart`
- Create: `lib/game/buffs/status_effects/feared.dart`

- [ ] **Step 1: 创建 burning.dart**

```dart
import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 灼烧状态 — 持续扣血，可多层叠加
class Burning extends PositionComponent {
  final double dps;
  double _remaining;
  bool get isExpired => _remaining <= 0;
  int stackCount = 1;

  Burning({required this.dps, double duration = 3.0})
      : _remaining = duration,
        super(size: Vector2.zero(), anchor: Anchor.center);

  /// 刷新灼烧持续时间（用于同名叠加）
  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // 灼烧视觉在 enemy 渲染时处理，此处不绘制
  }
}
```

- [ ] **Step 2: 创建 slowed.dart**

```dart
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
```

- [ ] **Step 3: 创建 frozen.dart**

```dart
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
```

- [ ] **Step 4: 创建 marked.dart**

```dart
import 'package:flame/components.dart';

/// 暗影标记 — 塔对该目标伤害增加
class Marked extends Component {
  final double damageMultiplier; // 塔伤害加成（1.0 + bonus）
  double _remaining;
  bool get isExpired => _remaining <= 0;

  Marked({required this.damageMultiplier, double duration = 3.0})
      : _remaining = duration;

  void refresh(double duration) {
    if (duration > _remaining) _remaining = duration;
  }

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
  }
}
```

- [ ] **Step 5: 创建 feared.dart**

```dart
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
```

- [ ] **Step 6: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/buffs/status_effects/
```

---

### Task 5: 改造 Enemy — 支持状态效果

**Files:**
- Modify: `lib/game/components/enemy.dart`

- [ ] **Step 1: 重写 Enemy 支持多种状态**

完整的 enemy.dart 重写如下。关键变化：
- 移除旧的 `_slowTimer` / `isSlowed`（改为使用 Slowed 组件）
- `update()` 中检查 Frozen / Feared / Slowed 组件来决策移动
- Burning 的伤害由游戏主循环统一结算

```dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../buffs/status_effects/burning.dart';
import '../buffs/status_effects/slowed.dart';
import '../buffs/status_effects/frozen.dart';
import '../buffs/status_effects/marked.dart';
import '../buffs/status_effects/feared.dart';

/// 外星敌人 — 从天空降落的入侵者
class Enemy extends PositionComponent {
  final double hpMultiplier;
  final double speedMultiplier;

  Enemy({
    this.hpMultiplier = 1.0,
    this.speedMultiplier = 1.0,
  }) : super(size: Vector2(44, 44), anchor: Anchor.center);

  // ─── 属性 ───
  static const double baseSpeed = 50.0;
  static const double baseHp = 2.0;

  late double hp = baseHp * hpMultiplier;
  double get maxHp => baseHp * hpMultiplier;

  bool get isDead => hp <= 0;
  int expValue = 10;

  // ─── 精灵 ───
  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    _sprite = await Sprite.load('enemy-1.png');
    if (_sprite != null) {
      final src = _sprite!.srcSize;
      final scale = 48.0 / src.y;
      size = Vector2(src.x * scale, src.y * scale);
      anchor = Anchor.center;
    }
  }

  // ─── 状态查询 ───
  bool get isSlowed => firstChild<Slowed>() != null;
  Slowed? get slowed => firstChild<Slowed>();
  bool get isFrozen => firstChild<Frozen>() != null;
  bool get isFeared => firstChild<Feared>() != null;
  bool get isBurning => firstChild<Burning>() != null;
  bool get isMarked => firstChild<Marked>() != null;

  void takeDamage(double damage) {
    hp -= damage;
  }

  // ─── 每帧更新 ───
  @override
  void update(double dt) {
    super.update(dt);

    // 冻结时不移动
    if (isFrozen) return;

    // 恐惧时反向（向上）移动
    if (isFeared) {
      position.y -= baseSpeed * speedMultiplier * dt;
      return;
    }

    // 减速判定
    final slowFactor = isSlowed ? (1.0 - slowed!.factor) : 1.0;
    final effectiveSpeed = baseSpeed * slowFactor;
    position.y += effectiveSpeed * speedMultiplier * dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _sprite?.render(canvas, size: size);
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/components/enemy.dart
```

---

### Task 6: 改造 EliteEnemy — 支持状态效果

**Files:**
- Modify: `lib/game/components/elite_enemy.dart`

- [ ] **Step 1: 重写 EliteEnemy 支持多种状态**

关键变化同 Enemy：移除 `_slowTimer`，改用组件判定。

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../buffs/status_effects/frozen.dart';
import '../buffs/status_effects/feared.dart';
import '../buffs/status_effects/slowed.dart';
import '../buffs/status_effects/marked.dart';
import '../buffs/status_effects/burning.dart';

/// 精英敌人
class EliteEnemy extends PositionComponent {
  final double hpMultiplier;
  final double speedMultiplier;

  EliteEnemy({
    this.hpMultiplier = 1.0,
    this.speedMultiplier = 1.0,
  }) : super(size: Vector2(24, 72), anchor: Anchor.center);

  // ─── 属性 ───
  static const double baseSpeed = 40.0;
  static const double baseHp = 4.8;

  late double hp = baseHp * hpMultiplier;
  double get maxHp => baseHp * hpMultiplier;

  bool get isDead => hp <= 0;
  int expValue = 30;

  /// 停驻 Y 坐标
  double _stopY = double.infinity;
  set stopY(double v) => _stopY = v;

  bool _stopped = false;
  bool get isStopped => _stopped;

  // ─── 状态查询 ───
  bool get isSlowed => firstChild<Slowed>() != null;
  Slowed? get slowed => firstChild<Slowed>();
  bool get isFrozen => firstChild<Frozen>() != null;
  bool get isFeared => firstChild<Feared>() != null;
  bool get isBurning => firstChild<Burning>() != null;
  bool get isMarked => firstChild<Marked>() != null;

  // ─── 动画 ───
  SpriteAnimationComponent? _anim;

  @override
  Future<void> onLoad() async {
    final sheet = await Flame.images.load('enemy-2.png');
    final animation = SpriteAnimation.fromFrameData(
      sheet,
      SpriteAnimationData.sequenced(
        amount: 16, amountPerRow: 16, stepTime: 0.08,
        textureSize: Vector2(32, 96), loop: true,
      ),
    );
    _anim = SpriteAnimationComponent(
      animation: animation, size: size,
      anchor: Anchor.center, position: Vector2.zero(),
    );
    add(_anim!);
  }

  void takeDamage(double damage) {
    hp -= damage;
  }

  // ─── 震荡波 ───
  double _shockwaveTimer = 0;
  static const double _shockwaveInterval = 5.0;
  static const double _shockwaveDuration = 0.6;
  static const double _shockwaveRadiusFactor = 1.5;

  double _shockwaveElapsed = -1;
  Vector2 _shockwaveCenter = Vector2.zero();

  bool get shockwaveActive => _shockwaveElapsed >= 0;

  double get shockwaveRadius {
    if (!shockwaveActive) return 0;
    final maxDim = size.x > size.y ? size.x : size.y;
    final t = (_shockwaveElapsed / _shockwaveDuration).clamp(0.0, 1.0);
    return maxDim * _shockwaveRadiusFactor * t;
  }

  bool isInsideShockwave(Vector2 point) {
    if (!shockwaveActive) return false;
    return point.distanceTo(_shockwaveCenter) <= shockwaveRadius;
  }

  void _emit() {
    _shockwaveCenter = position.clone();
    _shockwaveElapsed = 0;
    _shockwaveTimer = 0;
  }

  /// EMP 惩罚 — 震荡波 CD +N 秒
  double _shockCdPenalty = 0;
  void applyShockCdPenalty(double seconds) {
    _shockCdPenalty += seconds;
  }

  /// 强制取消当前震荡波（EMP 效果）
  void cancelShockwave() {
    _shockwaveElapsed = -1;
  }

  // ─── 移动 ───
  @override
  void update(double dt) {
    super.update(dt);

    if (isFrozen) {
      // 冻结中仍可计时震荡波
      if (_stopped) {
        _updateShockwave(dt);
      }
      return;
    }

    if (!_stopped) {
      if (isFeared) {
        position.y -= baseSpeed * speedMultiplier * dt;
      } else {
        final slowFactor = isSlowed ? (1.0 - slowed!.factor) : 1.0;
        final effectiveSpeed = baseSpeed * slowFactor;
        position.y += effectiveSpeed * speedMultiplier * dt;
      }

      if (position.y >= _stopY) {
        position.y = _stopY;
        _stopped = true;
        _emit();
      }
    } else {
      _updateShockwave(dt);
    }
  }

  void _updateShockwave(double dt) {
    if (_shockwaveElapsed >= 0) {
      _shockwaveElapsed += dt;
      if (_shockwaveElapsed >= _shockwaveDuration) {
        _shockwaveElapsed = -1;
      }
    } else {
      _shockwaveTimer += dt;
      final effectiveInterval = _shockwaveInterval + _shockCdPenalty;
      if (_shockwaveTimer >= effectiveInterval) {
        _shockCdPenalty = 0; // 一次性惩罚，用完重置
        _emit();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!shockwaveActive) return;

    final t = (_shockwaveElapsed / _shockwaveDuration).clamp(0.0, 1.0);
    final r = shockwaveRadius;
    final paintFill = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.13 * (1 - t) * 0.6)
      ..style = PaintingStyle.fill;
    final paintOuter = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.67 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final paintThin = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4 * (1 - t) * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(Offset.zero, r * 0.9, paintFill);
    canvas.drawCircle(Offset.zero, r, paintOuter);
    canvas.drawCircle(Offset.zero, r * 1.05, paintThin);
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/components/elite_enemy.dart
```

---

### Task 7: 更新 Projectile — 支持 buff 伤害加成

**Files:**
- Modify: `lib/game/components/projectile.dart`

- [ ] **Step 1: 不改变 Projectile 自身逻辑，伤害由外部传入**

Projectile 无需修改。伤害由 `_fireBullet()` 传入——该处将使用 BuffManager 的 damageMultiplier 来调整 `damage` 参数。

无需修改 projectile.dart。

---

### Task 8: 更新 drone_bullet.dart — 支持暗影标记

**Files:**
- Modify: `lib/game/components/drone_bullet.dart`

- [ ] **Step 1: 添加标记支持**

DroneBullet 的 `tryHit` 命中后需要检查暗影标记 buff。修改 `tryHit`：

```dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';
import 'elite_enemy.dart';
import '../buffs/status_effects/marked.dart';
import '../buffs/buff_manager.dart';

class DroneBullet extends PositionComponent {
  final Vector2 direction;
  final double speed;

  DroneBullet({required this.direction, this.speed = 700})
      : super(size: Vector2(69, 30), anchor: Anchor.center);

  static const double damage = 2.0;
  double _lifetime = 0;
  static const double maxLifetime = 3.0;

  final Set<int> _hitEnemies = {};
  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    _sprite = await Sprite.load('bullet-02.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * speed * dt;
    _lifetime += dt;
    if (_lifetime > maxLifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_sprite != null) {
      final angle = atan2(direction.y, direction.x);
      canvas.save();
      canvas.translate(0, 0);
      canvas.rotate(angle);
      _sprite!.render(canvas, size: size);
      canvas.restore();
    }
  }

  /// 尝试命中敌人，返回是否成功
  bool tryHit(PositionComponent enemy) {
    final id = enemy.hashCode;
    if (_hitEnemies.contains(id)) return false;
    if (!toRect().overlaps(enemy.toRect())) return false;

    _hitEnemies.add(id);
    if (enemy is Enemy) enemy.takeDamage(damage);
    if (enemy is EliteEnemy) enemy.takeDamage(damage);

    // 暗影标记：命中后挂标记
    _applyShadowMark(enemy);

    return true;
  }

  void _applyShadowMark(PositionComponent enemy) {
    final bm = _findBuffManager();
    if (bm == null || !bm.has(BuffId.shadowMark)) return;

    final existing = (enemy as Component).firstChild<Marked>();
    if (existing != null) {
      existing.refresh(bm.shadowMarkDuration);
    } else {
      (enemy as Component).add(Marked(
        damageMultiplier: 1.0 + bm.shadowMarkDamageBonus,
        duration: bm.shadowMarkDuration,
      ));
    }
  }

  BuffManager? _findBuffManager() {
    Component? p = this;
    while (p != null) {
      final bm = (p as dynamic).buffManager;
      if (bm is BuffManager) return bm;
      p = p.parent;
    }
    return null;
  }
}
```

`_findBuffManager` 通过父链查找——BuffManager 被 DefendTheTowerGame 持有且作为 child 添加。实际上更好做法是在碰撞检查处统一处理。我们将在后续 Task 中改用 game 直接处理标记逻辑。

**简化方案：不在 DroneBullet 内查 BuffManager，而是在 game._checkCollisions 中处理**。因此本文件保持不变，无需修改。

- [ ] **Step 1-实际: 不修改 drone_bullet.dart**

~~无需改 drone_bullet.dart。标记逻辑由 `defend_the_tower_game.dart` 的 `_checkCollisions` 统一处理。~~

---

### Task 9: 集成 DefendTheTowerGame — 暂停 + BuffManager + 回调

**Files:**
- Modify: `lib/game/defend_the_tower_game.dart`

这是核心改造。需要修改的内容：
- 添加 `BuffManager _buffManager` 字段和公开 getter
- 替换 `rangePercent` 为 BuffManager 读取
- `_paused` 暂停字段
- 升级时触发 buff 选择流程
- 射击时应用 damageMultiplier, fireRateMultiplier, barrage, fireStorm
- 碰撞中应用灼烧/减速/标记/连锁
- 击杀中应用余烬/冰爆/EMP/嗜血
- 周期性静电场/虚空裂隙/极寒光环
- 护盾逻辑

- [ ] **Step 1: 查找 BuffManager 的便捷方法**

在 DefendTheTowerGame 中添加：

```dart
BuffManager? get buffManager => _buffManager;
```

- [ ] **Step 2: 修改 HudData — 添加 buff 状态字段**

```dart
class HudData {
  final int hp; final int maxHp;
  final int exp; final int expToNext; final int level;
  final int wave; final int maxWave; final double waveProgress;
  final bool gameWon; final bool gameOver; final bool isFinalWave;
  final bool paused;
  final int buffState; // 0=idle, 1=selecting buff cards
  final List<BuffId>? buffChoices; // null when not selecting
  final List<List<BuffId>> buffStash; // stash entries
  final Map<BuffId, int> activeBuffs; // for HUD display

  const HudData({
    required this.hp, required this.maxHp,
    required this.exp, required this.expToNext, required this.level,
    required this.wave, required this.maxWave, required this.waveProgress,
    required this.gameWon, required this.gameOver, required this.isFinalWave,
    this.paused = false,
    this.buffState = 0,
    this.buffChoices,
    this.buffStash = const [],
    this.activeBuffs = const {},
  });
}
```

- [ ] **Step 3: 修改 DefendTheTowerGame**

完整的变更，分步骤展示关键代码段：

**添加导入和字段：**

```dart
import 'buffs/buff_registry.dart';
import 'buffs/buff_manager.dart';
import 'buffs/buff_card_data.dart';
import 'buffs/status_effects/burning.dart';
import 'buffs/status_effects/slowed.dart';
import 'buffs/status_effects/frozen.dart';
import 'buffs/status_effects/marked.dart';
import 'buffs/status_effects/feared.dart';
```

**新增字段：**

```dart
bool _paused = false;
BuffManager? _buffManager;
bool get paused => _paused;

// Buff 选择
int _buffState = 0; // 0=idle, 1=selecting
List<BuffId>? _buffChoices;

// 暂存槽 FIFO
final List<BuffCardSet> _buffStash = [];
static const int maxStashSize = 3;

// 子弹计数（弹幕扩充 / 火焰风暴）
int _bulletCount = 0;

// 静电场计时器
double _staticFieldTimer = 0;

// 虚空裂隙
bool _voidRiftSpawnedThisWave = false;

// 回调：通知 game_screen 弹出 buff 卡片
void Function()? onBuffSelectionChanged;

// 护盾已应用于本波
bool _shieldApplied = false;
```

**onLoad 中初始化 BuffManager：**

```dart
@override
Future<void> onLoad() async {
  _bgSprite = await Sprite.load(_bgName);
  _setupBackground();
  _spawnTower();
  _spawnDrone();
  _spawnCrosshair();
  _buffManager = BuffManager();
  add(_buffManager!);
}
```

**update 顶部添加暂停：**

```dart
@override
void update(double dt) {
  super.update(dt);
  if (_gameWon || _gameOver) { _notifyHud(); return; }
  if (_paused) { _notifyHud(); return; }
  // ... rest unchanged
}
```

- [ ] **Step 4: 升级触发 buff 选择**

在 `update()` 中的经验检查后，替换原有的 `while (_exp >= expToNextLevel)` 为：

```dart
// 检查升级触发
if (_exp >= expToNextLevel && _buffState == 0) {
  _triggerLevelUp();
}

// 移除原有的 while 循环中的自动升级——
// 升级 + buff 选择在 _triggerLevelUp 中处理
```

新增方法：

```dart
void _triggerLevelUp() {
  _exp -= expToNextLevel;
  _level++;
  _paused = true;
  _buffState = 1;
  _buffChoices = _buffManager!.generateChoices();
  _notifyHud();
  onBuffSelectionChanged?.call();
}

/// 玩家选择 buff（外部调用）
void selectBuff(BuffId id) {
  _buffManager!.addLevel(id);
  _buffState = 0;
  _buffChoices = null;
  _paused = false;
  _notifyHud();
  onBuffSelectionChanged?.call();
}

/// 玩家跳过 buff（外部调用）
void skipBuff() {
  if (_buffChoices == null) return;
  // FIFO 入队
  _buffStash.add(BuffCardSet(List.from(_buffChoices!)));
  if (_buffStash.length > maxStashSize) {
    _buffStash.removeAt(0); // 顶掉最老的
  }
  _buffState = 0;
  _buffChoices = null;
  _paused = false;
  _notifyHud();
  onBuffSelectionChanged?.call();
}

/// 从暂存槽重新选择
void selectFromStash(int index) {
  if (index < 0 || index >= _buffStash.length) return;
  final cardSet = _buffStash.removeAt(index);
  _paused = true;
  _buffState = 1;
  _buffChoices = cardSet.choices;
  _notifyHud();
  onBuffSelectionChanged?.call();
}
```

- [ ] **Step 5: 射击系统读取 BuffManager**

修改 `_fireBullet()` 中的伤害和间隔：

```dart
void _fireBullet() {
  if (_tower == null || _buffManager == null) return;

  final inRange = enemiesInRange;
  if (inRange.isEmpty) return;

  // ... 找最近敌人（不变）...

  final baseDamage = 1.0;
  final bm = _buffManager!;

  // 伤害倍率
  double finalDamage = baseDamage * bm.damageMultiplier;

  // 暗影标记加成
  final marked = (target as Component).firstChild<Marked>();
  if (marked != null) finalDamage *= marked.damageMultiplier;

  // 血怒加成
  if (bm.bloodRageActive) finalDamage *= (1.0 + bm.bloodRageDamageBonus);

  // 精英额外伤害
  if (target is EliteEnemy) finalDamage *= (1.0 + bm.powerShotEliteBonus);

  // 发射主子弹
  _launchBullet(finalDamage, target);

  // 弹幕扩充
  _bulletCount++;
  final everyN = bm.barrageEveryN;
  if (everyN > 0 && _bulletCount % everyN == 0) {
    for (int i = 0; i < bm.barrageExtraCount; i++) {
      _launchBullet(finalDamage, target);
    }
  }

  // 火焰风暴
  final fireN = bm.fireStormEveryN;
  if (fireN > 0 && _bulletCount % fireN == 0) {
    for (int i = 0; i < bm.fireStormExtraCount; i++) {
      // 火焰弹：范围灼烧
      _launchFireBullet(target);
    }
  }

  // 双发（急速射击 Lv.3）
  if (bm.rapidFireDoubleShot && Random().nextDouble() < bm.rapidFireDoubleChance) {
    _launchBullet(finalDamage, target);
  }
}

void _launchBullet(double damage, PositionComponent target) {
  if (_tower == null) return;
  final toTarget = target.position - _tower!.position;
  final angle = atan2(toTarget.y, toTarget.x);
  final direction = Vector2(cos(angle), sin(angle));

  final bm = _buffManager!;
  final homingBonus = bm.eagleEyeHomingBonus;

  const dist = Tower.muzzleDistance;
  final muzzleX = _tower!.position.x + cos(angle) * dist;
  final muzzleY = _tower!.position.y + sin(angle) * dist;

  final bullet = Projectile(
    direction: direction,
    target: target,
    homingStrength: 0.12 + homingBonus,
    speed: 550,
    damage: damage,
  );
  bullet.position = Vector2(muzzleX, muzzleY);
  add(bullet);
}

void _launchFireBullet(PositionComponent target) {
  if (_tower == null || _buffManager == null) return;
  final bm = _buffManager!;
  final toTarget = target.position - _tower!.position;
  final angle = atan2(toTarget.y, toTarget.x);
  final direction = Vector2(cos(angle), sin(angle));

  const dist = Tower.muzzleDistance;
  final muzzleX = _tower!.position.x + cos(angle) * dist;
  final muzzleY = _tower!.position.y + sin(angle) * dist;

  final bullet = Projectile(
    direction: direction,
    target: null,        // 直飞不追踪
    homingStrength: 0,
    speed: 500,
    damage: bm.burnDps > 0 ? bm.burnDps : 5, // 火焰弹带灼烧伤害
  );
  bullet.position = Vector2(muzzleX, muzzleY);
  add(bullet);
}
```

- [ ] **Step 6: 修改 fireRate 和 drone**

`_fireTimer` 的比较值改用 BuffManager：

```dart
// 在 update() 中：
_fireTimer += dt;
final effectiveInterval = fireInterval * (_buffManager?.fireRateMultiplier ?? 1.0);
if (_fireTimer >= effectiveInterval) {
  _fireTimer = 0;
  _fireBullet();
}
```

无人机射击：

```dart
// _fireDroneBullet() 改为：
void _fireDroneBullet() {
  if (_drone == null || _buffManager == null) return;
  final toTarget = _pointerPosition - _drone!.position;
  if (toTarget.length < 1) return;
  final dir = toTarget.normalized();

  void launch() {
    final bullet = DroneBullet(direction: dir);
    bullet.position = _drone!.position.clone();
    add(bullet);
  }

  launch();
  final bm = _buffManager!;
  if (bm.droneDoubleShot) {
    // 双发略微偏移方向
    final angledDir = Vector2(
      cos(atan2(dir.y, dir.x) + 0.15),
      sin(atan2(dir.y, dir.x) + 0.15),
    );
    final bullet2 = DroneBullet(direction: angledDir);
    bullet2.position = _drone!.position.clone();
    add(bullet2);
  }
}

// update 中的 drone 冷却：
final droneCd = _buffManager?.droneCooldown ?? droneFireCooldown;
_droneFireTimer += dt;
if (_droneFireTimer >= droneCd) {
  _droneFireTimer = 0;
  _fireDroneBullet();
}
```

- [ ] **Step 7: 索敌范围改用 BuffManager**

```dart
double get rangePercent => _buffManager?.rangePercent ?? 0.80;
```

`rangePercent` 字段改为 getter，自动从 BuffManager 读取。

- [ ] **Step 8: 修改 HudData 构建**

在 `_notifyHud()` 中：

```dart
void _notifyHud() {
  hudNotifier.value = HudData(
    hp: _hp, maxHp: maxHp,
    exp: _exp, expToNext: expToNextLevel, level: _level,
    wave: _wave, maxWave: maxWave,
    waveProgress: (_waveTimer / waveDuration).clamp(0.0, 1.0),
    gameWon: _gameWon, gameOver: _gameOver,
    isFinalWave: _wave == maxWave,
    paused: _paused,
    buffState: _buffState,
    buffChoices: _buffChoices,
    buffStash: _buffStash.map((s) => s.choices).toList(),
    activeBuffs: Map.from(_buffManager?.allLevels ?? {}),
  );
}
```

- [ ] **Step 9: 碰撞系统 — 命中触发**

修改 `_checkCollisions()` 中普通子弹的命中处理：

```dart
// 在 for (final bullet in bullets) 的碰撞命中处：
if (bullet.toRect().overlaps(enemy.toRect())) {
  double dmg = bullet.damage;
  
  // 连锁闪电：命中时弹射
  _tryChainLightning(bullet.position, enemy, dmg);
  
  // 灼烧
  _tryApplyBurning(enemy);
  
  // 冰霜减速
  _tryApplyFrostSlow(enemy);
  
  if (enemy is Enemy) enemy.takeDamage(dmg);
  if (enemy is EliteEnemy) enemy.takeDamage(dmg);

  add(HitFlash(at: bullet.position.clone()));
  bullet.removeFromParent();
  if (_enemyIsDead(enemy)) _onEnemyKilled(enemy);
  break;
}
```

新增方法：

```dart
void _tryChainLightning(Vector2 hitPos, PositionComponent originEnemy, double baseDmg) {
  final bm = _buffManager!;
  if (bm.chainCount == 0) return;

  final chainDmg = baseDmg * bm.chainDamageRatio;
  final used = <PositionComponent>{originEnemy};
  if (!bm.chainRepeatTarget) used.add(originEnemy);

  PositionComponent? current = originEnemy;
  for (int i = 0; i < bm.chainCount; i++) {
    // 找最近的未命中敌人
    PositionComponent? nearest;
    double nearestDist = double.infinity;
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      if (used.contains(e)) continue;
      final d = e.position.distanceTo(current!.position);
      if (d < nearestDist) { nearestDist = d; nearest = e; }
    }
    if (nearest == null) break;

    // 弹射伤害
    if (nearest is Enemy) nearest.takeDamage(chainDmg);
    if (nearest is EliteEnemy) nearest.takeDamage(chainDmg);
    add(HitFlash(at: nearest.position.clone()));

    // 连锁电也可触发灼烧/减速
    _tryApplyBurning(nearest);
    _tryApplyFrostSlow(nearest);

    if (_enemyIsDead(nearest)) _onEnemyKilled(nearest);
    used.add(nearest);
    current = nearest;
  }
}

void _tryApplyBurning(PositionComponent enemy) {
  final bm = _buffManager!;
  if (bm.burnDps <= 0) return;

  final comp = enemy as Component;
  var burning = comp.firstChild<Burning>();
  if (burning != null) {
    if (bm.emberEchoStack) {
      burning.stackCount++;
    }
    burning.refresh(bm.burnDuration); // refresh
  } else {
    comp.add(Burning(dps: bm.burnDps, duration: bm.burnDuration));
  }
}

void _tryApplyFrostSlow(PositionComponent enemy) {
  final bm = _buffManager!;
  if (bm.frostSlowFactor <= 0) return;

  final comp = enemy as Component;
  var slowed = comp.firstChild<Slowed>();
  if (slowed != null) {
    slowed.refresh(2.0);
  } else {
    comp.add(Slowed(factor: bm.frostSlowFactor, duration: 2.0));
  }

  // 冰冻判定：减速因子 ≥80%（frostShot Lv.3 + frostAura）
  double totalSlow = bm.frostSlowFactor;
  if (bm.frostAura) totalSlow += bm.frostAuraSlow;
  if (totalSlow >= 0.80 && bm.frostShotFreeze) {
    var frozen = comp.firstChild<Frozen>();
    if (frozen != null) {
      frozen.refresh(1.0);
    } else {
      comp.add(Frozen(duration: 1.0));
    }
  }
}
```

另外修改无人机子弹命中时：

```dart
// 在 for (final bullet in droneBullets) 中命中后添加：
if (bullet.tryHit(enemy)) {
  // 暗影标记
  _tryApplyShadowMark(enemy);
  
  add(HitFlash(at: bullet.position.clone()));
  if (_enemyIsDead(enemy)) _onEnemyKilled(enemy);
}
```

```dart
void _tryApplyShadowMark(PositionComponent enemy) {
  final bm = _buffManager!;
  if (!bm.has(BuffId.shadowMark)) return;

  final comp = enemy as Component;
  var mark = comp.firstChild<Marked>();
  if (mark != null) {
    mark.refresh(bm.shadowMarkDuration);
  } else {
    comp.add(Marked(damageMultiplier: 1.0 + bm.shadowMarkDamageBonus, duration: bm.shadowMarkDuration));
  }
}
```

- [ ] **Step 10: 击杀触发**

修改 `_onEnemyKilled`：

```dart
void _onEnemyKilled(PositionComponent enemy) {
  final bm = _buffManager!;
  
  add(DeathExplosion(at: enemy.position.clone()));

  // 灼烧死亡爆炸
  if (bm.scorchingShotExplosion) {
    final burn = (enemy as Component).firstChild<Burning>();
    if (burn != null) {
      _spreadBurningToNearby(enemy, bm.burnDps, bm.burnDuration, 100);
    }
  }

  // 余烬余波
  if (bm.emberEchoLevel > 0) {
    final burn = (enemy as Component).firstChild<Burning>();
    if (burn != null) {
      _spreadBurningToNearby(enemy, bm.burnDps, bm.burnDuration, bm.emberEchoRadius);
    }
  }

  // 冰霜新星（仅精英死亡触发）
  if (enemy is EliteEnemy && bm.frostNovaLevel > 0) {
    _triggerFrostNova(enemy, bm.frostNovaRadius, bm.frostNovaFreezeDuration);
  }

  // EMP
  if (bm.empLevel > 0) {
    _triggerEmp(enemy, bm.empRadius);
  }

  // 嗜血渴望
  if (bm.bloodthirstLevel > 0) {
    _tryBloodthirstHeal();
  }

  // 暗影标记扩散
  if (bm.shadowMarkSpread) {
    final mark = (enemy as Component).firstChild<Marked>();
    if (mark != null) {
      _spreadMarkToNearby(enemy, bm.shadowMarkDuration,
          1.0 + bm.shadowMarkDamageBonus, bm.shadowMarkSpreadRadius);
    }
  }

  // 冰霜新星链
  if (bm.frostNovaChain) {
    final frozen = (enemy as Component).firstChild<Frozen>();
    if (frozen != null) {
      _triggerFrostNova(enemy, bm.frostNovaRadius * 0.6, bm.frostNovaFreezeDuration * 0.6);
    }
  }

  // EXP
  int expGain = 10;
  if (enemy is Enemy) expGain = enemy.expValue;
  if (enemy is EliteEnemy) expGain = enemy.expValue;
  _exp += expGain;
  _notifyHud();

  enemy.removeFromParent();
}

// ─── 效果辅助方法 ───

void _spreadBurningToNearby(PositionComponent origin, double dps, double dur, double radius) {
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final dist = e.position.distanceTo(origin.position);
    if (dist <= radius) {
      final comp = e as Component;
      var burning = comp.firstChild<Burning>();
      if (burning != null) {
        if (_buffManager!.emberEchoStack) burning.stackCount++;
        burning.refresh(dur);
      } else {
        comp.add(Burning(dps: dps, duration: dur));
      }
    }
  }
}

void _triggerFrostNova(PositionComponent origin, double radius, double freezeDur) {
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final dist = e.position.distanceTo(origin.position);
    if (dist <= radius) {
      final comp = e as Component;
      var frozen = comp.firstChild<Frozen>();
      if (frozen != null) {
        frozen.refresh(freezeDur);
      } else {
        comp.add(Frozen(duration: freezeDur));
      }
    }
  }
}

void _triggerEmp(PositionComponent origin, double radius) {
  // 消除震荡波
  for (final elite in children.whereType<EliteEnemy>()) {
    if (elite.position.distanceTo(origin.position) <= radius) {
      if (elite.shockwaveActive) {
        elite.cancelShockwave();
      }
      // EMP 惩罚：震荡波 CD +3
      if (_buffManager!.empShockCdPenalty) {
        elite.applyShockCdPenalty(_buffManager!.empShockCdPenaltyAmount);
      }
    }
  }
}

void _tryBloodthirstHeal() {
  final bm = _buffManager!;
  if (Random().nextDouble() >= bm.bloodthirstChance) return;
  final healAmount = (maxHp * bm.bloodthirstHealPercent).round();
  _hp = (_hp + healAmount).clamp(0, maxHp);
  if (bm.bloodthirstRage) {
    bm.triggerBloodRage();
  }
}

void _spreadMarkToNearby(PositionComponent origin, double dur, double mult, double radius) {
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final dist = e.position.distanceTo(origin.position);
    if (dist <= radius) {
      final comp = e as Component;
      var mark = comp.firstChild<Marked>();
      if (mark != null) {
        mark.refresh(dur);
      } else {
        comp.add(Marked(damageMultiplier: mult, duration: dur));
      }
    }
  }
}
```

- [ ] **Step 11: 极寒光环 + 恐惧之触 — 每帧判定**

在 `update()` 的 `_autoAimAtNearestEnemy()` 后添加：

```dart
// 极寒光环
if (_buffManager?.frostAura == true && _tower != null) {
  _applyFrostAura();
}

// 恐惧之触（仅对刚进入范围的敌人触发一次）
if (_buffManager?.fearTouchLevel != null && _buffManager!.fearTouchLevel > 0) {
  _checkFearTouch();
}
```

新增方法：

```dart
void _applyFrostAura() {
  final bm = _buffManager!;
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final dist = e.position.distanceTo(_tower!.position);
    if (dist <= bm.frostAuraRadius) {
      final comp = e as Component;
      var slowed = comp.firstChild<Slowed>();
      if (slowed != null) {
        slowed.refresh(0.5); // 光环持续刷新
      } else {
        comp.add(Slowed(factor: bm.frostAuraSlow, duration: 0.5));
      }
    }
  }
}

final Set<int> _fearedEnemies = {};

void _checkFearTouch() {
  final bm = _buffManager!;
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final id = e.hashCode;
    // 只在敌人刚进入范围时判定一次
    if (!_fearedEnemies.contains(id) && isInRange(e is Enemy ? e : e as EliteEnemy)) {
      _fearedEnemies.add(id);
      if (Random().nextDouble() < bm.fearTouchChance) {
        (e as Component).add(Feared(duration: bm.fearTouchDuration));
      }
    }
  }
  // 清理已离开或死亡的
  _fearedEnemies.removeWhere((id) {
    for (final e in enemies) {
      if (e.hashCode == id && !_enemyIsDead(e)) return false;
    }
    return true;
  });

  // 恐惧传染
  if (bm.fearTouchSpread) {
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      if ((e as Component).firstChild<Feared>() == null) continue;
      for (final other in enemies) {
        if (_enemyIsDead(other)) continue;
        if (e.hashCode == other.hashCode) continue;
        if ((other as Component).firstChild<Feared>() != null) continue;
        if (other.position.distanceTo(e.position) < 40) {
          other.add(Feared(duration: bm.fearTouchDuration));
        }
      }
    }
  }
}
```

- [ ] **Step 12: 静电场 + 虚空裂隙 — 周期性**

在 `update()` 中添加：

```dart
// 静电场
if (_buffManager?.staticFieldLevel != null && _buffManager!.staticFieldLevel > 0) {
  _updateStaticField(dt);
}

// 虚空裂隙（每波初生成）
if (_buffManager?.voidRiftLevel != null && _buffManager!.voidRiftLevel > 0) {
  _updateVoidRift(dt);
}
```

```dart
void _updateStaticField(double dt) {
  final bm = _buffManager!;
  _staticFieldTimer += dt;
  if (_staticFieldTimer >= bm.staticFieldInterval) {
    _staticFieldTimer = 0;
    final rng = Random();
    for (int i = 0; i < bm.staticFieldCount; i++) {
      final x = size.x * 0.15 + rng.nextDouble() * size.x * 0.7;
      final y = size.y * 0.1 + rng.nextDouble() * size.y * 0.5;
      final center = Vector2(x, y);
      // 对范围内敌人造成伤害
      for (final e in enemies) {
        if (_enemyIsDead(e)) continue;
        if (e.position.distanceTo(center) <= bm.staticFieldRadius) {
          if (e is Enemy) e.takeDamage(bm.staticFieldDamage);
          if (e is EliteEnemy) e.takeDamage(bm.staticFieldDamage);
          add(HitFlash(at: e.position.clone()));
          if (_enemyIsDead(e)) _onEnemyKilled(e);
        }
      }
    }
  }
}

// 虚空裂隙由 BuffManager 管理（以 Component 形式生成）
void _updateVoidRift(double dt) {
  if (!_voidRiftSpawnedThisWave) {
    _voidRiftSpawnedThisWave = true;
    final bm = _buffManager!;
    final rng = Random();
    final x = size.x * 0.25 + rng.nextDouble() * size.x * 0.5;
    final y = size.y * 0.3 + rng.nextDouble() * size.y * 0.3;
    final rift = VoidRift(
      dps: bm.voidRiftDps,
      duration: bm.voidRiftDuration,
      radius: bm.voidRiftRadius,
      pullStrength: bm.voidRiftPull ? bm.voidRiftPullStrength : 0,
    );
    rift.position = Vector2(x, y);
    add(rift);
  }
}

// 新波次重置裂隙标记
void _advanceWave() {
  // ... existing ...
  _voidRiftSpawnedThisWave = false;
  _shieldApplied = false;
  _fearedEnemies.clear();
  if (_buffManager?.frostAuraShield == true) {
    _buffManager!.addWaveShield();
  }
}
```

- [ ] **Step 13: 护盾逻辑**

在 `_onEnemyReachedBottom` 中：

```dart
void _onEnemyReachedBottom(PositionComponent enemy) {
  // 护盾抵消
  if (_buffManager != null && _buffManager!.consumeShield()) {
    enemy.removeFromParent();
    _notifyHud();
    return;
  }
  _hp -= 5;
  _notifyHud();
  enemy.removeFromParent();
  if (_hp <= 0) {
    _hp = 0;
    _gameOver = true;
    _notifyHud();
  }
}
```

- [ ] **Step 14: 灼烧伤害结算**

在 `update()` 中添加灼烧 DPS 结算：

```dart
// 灼烧伤害结算
if (_buffManager?.burnDps != null && _buffManager!.burnDps > 0) {
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final burning = (e as Component).firstChild<Burning>();
    if (burning != null && !burning.isExpired) {
      final dps = burning.dps * burning.stackCount;
      if (e is Enemy) e.takeDamage(dps * dt);
      if (e is EliteEnemy) e.takeDamage(dps * dt);
      if (_enemyIsDead(e)) _onEnemyKilled(e);
    }
  }
}
```

- [ ] **Step 15: voidRift 组件**

创建 `lib/game/buffs/status_effects/void_rift.dart`：

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 虚空裂隙 — 持续对范围内敌人造成伤害
class VoidRift extends PositionComponent {
  final double dps;
  final double radius;
  final double pullStrength;
  double _elapsed = 0;
  final double duration;

  VoidRift({
    required this.dps,
    required this.duration,
    this.radius = 60,
    this.pullStrength = 0,
  }) : super(size: Vector2(radius * 2, radius * 2), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
      return;
    }

    // DPS 由 game.update 统一结算，这里仅做视觉效果 + 吸引
    // 吸引逻辑也由 game 处理（需要访问 enemies）
  }

  @override
  void render(Canvas canvas) {
    final progress = 1.0 - (_elapsed / duration);
    final paint = Paint()
      ..color = const Color(0xFFAB47BC).withValues(alpha: 0.25 * progress)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFAB47BC).withValues(alpha: 0.6 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, radius * (0.4 + 0.6 * (1 - progress)), paint);
    canvas.drawCircle(Offset.zero, radius * (0.4 + 0.6 * (1 - progress)), stroke);
  }
}
```

在 `update()` 中添加裂隙伤害和吸引：

```dart
// 虚空裂隙伤害 + 吸引
for (final rift in children.whereType<VoidRift>()) {
  for (final e in enemies) {
    if (_enemyIsDead(e)) continue;
    final dist = e.position.distanceTo(rift.position);
    if (dist <= rift.radius) {
      if (e is Enemy) e.takeDamage(rift.dps * dt);
      if (e is EliteEnemy) e.takeDamage(rift.dps * dt);
      if (_enemyIsDead(e)) _onEnemyKilled(e);
      // 吸引
      if (rift.pullStrength > 0) {
        final toRift = rift.position - e.position;
        if (toRift.length > 1) {
          e.position += toRift.normalized() * rift.pullStrength * dt;
        }
      }
    }
  }
}
```

- [ ] **Step 16: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/game/defend_the_tower_game.dart
```

---

### Task 10: BuffCardOverlay — 卡片弹窗 Widget

**Files:**
- Create: `lib/screens/widgets/buff_card_overlay.dart`

- [ ] **Step 1: 创建卡片弹窗 Widget**

```dart
import 'package:flutter/material.dart';
import '../../game/buffs/buff_registry.dart';

class BuffCardOverlay extends StatelessWidget {
  final List<BuffId> choices;
  final Map<BuffId, int> currentLevels;
  final void Function(BuffId id) onSelected;
  final VoidCallback onSkip;

  const BuffCardOverlay({
    super.key,
    required this.choices,
    required this.currentLevels,
    required this.onSelected,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '⬆ LEVEL UP! ⬆',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < choices.length; i++) ...[
              _buildCard(context, choices[i]),
              if (i < choices.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: onSkip,
              child: const Text(
                '跳过本次 →',
                style: TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, BuffId id) {
    final meta = BuffRegistry.data[id]!;
    final currentLv = currentLevels[id] ?? 0;
    final nextLv = currentLv + 1;
    final levelMeta = meta.level(nextLv);
    final color = Color(BuffRegistry.elementColor(meta.element));

    String levelLabel;
    if (currentLv == 0) {
      levelLabel = 'NEW';
    } else if (nextLv >= meta.maxLevel) {
      levelLabel = 'MAX';
    } else {
      levelLabel = 'Lv.$currentLv→$nextLv';
    }

    return GestureDetector(
      onTap: () => onSelected(id),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3340),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(meta.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        meta.name,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          levelLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    levelMeta.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/screens/widgets/buff_card_overlay.dart
```

---

### Task 11: BuffStashBar — 暂存槽 Widget

**Files:**
- Create: `lib/screens/widgets/buff_stash_bar.dart`

- [ ] **Step 1: 创建暂存槽 Widget**

```dart
import 'package:flutter/material.dart';
import '../../game/buffs/buff_registry.dart';

class BuffStashBar extends StatelessWidget {
  final List<List<BuffId>> stash;
  final Map<BuffId, int> activeBuffs;
  final void Function(int index) onTap;

  const BuffStashBar({
    super.key,
    required this.stash,
    required this.activeBuffs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? 4 : 0),
            child: GestureDetector(
              onTap: i < stash.length ? () => onTap(i) : null,
              child: _buildSlot(i),
            ),
          ),
      ],
    );
  }

  Widget _buildSlot(int index) {
    final hasEntry = index < stash.length;

    if (!hasEntry) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            // dashed border: use dotted_border package or custom paint
          ),
        ),
        child: Center(
          child: Text(
            '○',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.15),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // 取该组第一张卡的图标作为槽位 icon
    final firstId = stash[index].first;
    final meta = BuffRegistry.data[firstId]!;
    final color = Color(BuffRegistry.elementColor(meta.element));

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Center(
        child: Text(meta.icon, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/screens/widgets/buff_stash_bar.dart
```

---

### Task 12: 改造 GameScreen — 对接 UI

**Files:**
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: 添加 Buff 覆盖层和暂存槽到 GameScreen**

修改 `_GameScreenState`：

```dart
class _GameScreenState extends State<GameScreen> {
  late final DefendTheTowerGame _game;

  @override
  void initState() {
    super.initState();
    _game = DefendTheTowerGame();
    _game.onBuffSelectionChanged = _onBuffStateChanged;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _onBuffStateChanged() {
    setState(() {});
  }

  // ...
}
```

在 `build()` 的 Stack 中添加 buff overlay 和 stash bar：

```dart
// 在游戏画布之后、HUD 之前：
// Buff 选择覆盖层
if (_game.buffNotifier.value?.buffState == 1) {
  Positioned.fill(
    child: BuffCardOverlay(
      choices: _game.buffNotifier.value!.buffChoices!,
      currentLevels: _game.buffManager?.allLevels ?? {},
      onSelected: (id) => _game.selectBuff(id),
      onSkip: () => _game.skipBuff(),
    ),
  ),
}

// 暂存槽（左上角）
Positioned(
  top: 40,
  left: 4,
  child: SafeArea(
    child: BuffStashBar(
      stash: _game.buffNotifier.value?.buffStash ?? [],
      activeBuffs: _game.buffManager?.allLevels ?? {},
      onTap: (index) => _game.selectFromStash(index),
    ),
  ),
),
```

Hmm, I'm using `_game.buffNotifier` which I haven't defined yet. Let me use `hudNotifier` instead since HudData now has buff fields. Or better, keep it simple and just reference game directly with `_game.hudNotifier.value`.

Actually let me simplify — use the existing `hudNotifier`:

```dart
// Buff 选择覆盖层
if (_game.hudNotifier.value.buffState == 1 && _game.hudNotifier.value.buffChoices != null) {
  Positioned.fill(
    child: BuffCardOverlay(
      choices: _game.hudNotifier.value.buffChoices!,
      currentLevels: _game.hudNotifier.value.activeBuffs,
      onSelected: (id) => _game.selectBuff(id),
      onSkip: () => _game.skipBuff(),
    ),
  ),
}

// 暂存槽
Positioned(
  top: 40,
  left: 0,
  child: SafeArea(
    child: BuffStashBar(
      stash: _game.hudNotifier.value.buffStash,
      activeBuffs: _game.hudNotifier.value.activeBuffs,
      onTap: (index) => _game.selectFromStash(index),
    ),
  ),
),
```

完整修改 game_screen.dart。需要改动 `build()` 方法：

在 Stack children 中，`GameWidget` 之后，`_GameHud` 之前插入：

```dart
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
        ),
      );
    }
    return const SizedBox.shrink();
  },
),

// 暂存槽
Builder(
  builder: (ctx) {
    final data = _game.hudNotifier.value;
    if (data.buffStash.isNotEmpty || data.activeBuffs.isNotEmpty) {
      return Positioned(
        top: 40,
        left: 0,
        child: SafeArea(
          child: BuffStashBar(
            stash: data.buffStash,
            activeBuffs: data.activeBuffs,
            onTap: (index) => _game.selectFromStash(index),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  },
),
```

- [ ] **Step 2: 添加 import**

```dart
import 'widgets/buff_card_overlay.dart';
import 'widgets/buff_stash_bar.dart';
import '../game/buffs/buff_registry.dart';
```

- [ ] **Step 3: 验证编译**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/screens/game_screen.dart
```

---

### Task 13: 编译验证全项目

- [ ] **Step 1: 全项目静态分析**

```bash
cd "D:\新建文件夹\defend_the_tower" && dart analyze lib/
```

修复所有分析错误。

---

### Task 14: 运行时测试

- [ ] **Step 1: 启动应用验证**

```bash
cd "D:\新建文件夹\defend_the_tower" && flutter run -d chrome
```

- 验证升级时弹出 3 张卡片
- 验证选择卡片后 buff 生效
- 验证跳过进入暂存槽
- 验证暂存槽 FIFO 淘汰
- 验证同名叠加升级
