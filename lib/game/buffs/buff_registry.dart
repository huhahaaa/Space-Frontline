/// Buff 标识枚举
enum BuffId {
  rapidFire, powerShot, eagleEye, droneOverload, splitShot,
  scorchingShot, fireStorm, emberEcho,
  frostShot, frostNova, frostAura,
  chainLightning, staticField, emp,
  bloodthirst, shadowMark, fearTouch, voidRift,
  droneExpansion,
}

/// 元素分类
enum Element { universal, fire, ice, lightning, shadow, mechanical }

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
        BuffLevelMeta(description: '攻击间隔 -22%', params: {'rate': 0.22}),
        BuffLevelMeta(description: '攻击间隔 -38%', params: {'rate': 0.38}),
        BuffLevelMeta(description: '攻击间隔 -52% · 15%概率双发', params: {'rate': 0.52, 'doubleChance': 0.15}),
      ],
    ),
    BuffId.powerShot: BuffMeta(
      id: BuffId.powerShot, name: '强化弹头', icon: '💥',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '子弹伤害 +30%', params: {'dmg': 0.30}),
        BuffLevelMeta(description: '子弹伤害 +50%（乘算 → ×1.95）', params: {'dmg': 0.50}),
        BuffLevelMeta(description: '子弹伤害 +70%（乘算 → ×3.32）· 对精英额外+20%', params: {'dmg': 0.70, 'eliteBonus': 0.20}),
      ],
    ),
    BuffId.eagleEye: BuffMeta(
      id: BuffId.eagleEye, name: '鹰眼', icon: '👁️',
      element: Element.universal,
      maxLevel: 1,
      levels: [
        BuffLevelMeta(description: '全屏索敌 · 子弹追踪强度 +30%', params: {'rangePct': 1.0, 'homingBonus': 0.30}),
      ],
    ),
    BuffId.droneOverload: BuffMeta(
      id: BuffId.droneOverload, name: '无人机过载', icon: '🚁',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '无人机射速 +30%', params: {'rate': 0.70}),
        BuffLevelMeta(description: '无人机射速 +50%', params: {'rate': 0.50}),
        BuffLevelMeta(description: '无人机射速 +50% · 双发', params: {'rate': 0.50, 'doubleShot': 1.0}),
      ],
    ),
    BuffId.splitShot: BuffMeta(
      id: BuffId.splitShot, name: '分裂弹', icon: '💥',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '命中分裂 2 颗小子弹（½伤害·无命中Buff）', params: {'count': 2, 'dmgPct': 0.5}),
        BuffLevelMeta(description: '命中分裂 3 颗小子弹（½伤害·无命中Buff）', params: {'count': 3, 'dmgPct': 0.5}),
        BuffLevelMeta(description: '分裂 3 颗 · 继承命中Buff · 可叠加灼烧（½层）', params: {'count': 3, 'dmgPct': 0.5, 'inheritBuffs': 1.0}),
      ],
    ),
    // ═══ 火焰系 ═══
    BuffId.scorchingShot: BuffMeta(
      id: BuffId.scorchingShot, name: '灼热弹头', icon: '🔥',
      element: Element.fire,
      levels: [
        BuffLevelMeta(description: '命中施加1层灼烧（1.0/秒）· 同源不叠加', params: {'stacks': 1.0, 'dur': 3.0}),
        BuffLevelMeta(description: '灼烧提升至1.6层（1.6/秒）', params: {'stacks': 1.6, 'dur': 3.0}),
        BuffLevelMeta(description: '灼烧提升至2.5层（2.5/秒）· 死亡时范围爆破伤害', params: {'stacks': 2.5, 'dur': 3.0, 'explode': 1.0}),
      ],
    ),
    BuffId.fireStorm: BuffMeta(
      id: BuffId.fireStorm, name: '火焰风暴', icon: '🌪️',
      element: Element.fire,
      levels: [
        BuffLevelMeta(description: '每10秒生成火焰风暴 · 持续5秒 · 吸引+易燃', params: {'radius': 90, 'pull': 115, 'dur': 5.0}),
        BuffLevelMeta(description: '范围+30% · 持续7.5秒', params: {'radius': 117, 'pull': 115, 'dur': 7.5}),
        BuffLevelMeta(description: '同时生成2个火焰风暴', params: {'radius': 117, 'pull': 115, 'dur': 7.5, 'double': 1.0}),
      ],
    ),
    BuffId.emberEcho: BuffMeta(
      id: BuffId.emberEcho, name: '余烬余波', icon: '✨',
      element: Element.fire,
      levels: [
        BuffLevelMeta(description: '击杀敌人施加0.5层灼烧（异源可叠加）', params: {'radius': 100}),
        BuffLevelMeta(description: '击杀敌人 · 范围+30%', params: {'radius': 130}),
        BuffLevelMeta(description: '击杀敌人 · 同源也可叠加', params: {'radius': 130, 'selfStack': 1.0}),
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
        BuffLevelMeta(description: '命中弹射 1 次 · 0.6 伤害', params: {'chain': 1, 'dmg': 0.60}),
        BuffLevelMeta(description: '命中弹射 2 次 · 0.6 伤害', params: {'chain': 2, 'dmg': 0.60}),
        BuffLevelMeta(description: '弹射 2 次 · 伤害 1.0 · 被链命中敌人额外减速 30%', params: {'chain': 2, 'dmg': 1.0, 'slowPct': 0.30}),
      ],
    ),
    BuffId.staticField: BuffMeta(
      id: BuffId.staticField, name: '静电场', icon: '🌩️',
      element: Element.lightning,
      levels: [
        BuffLevelMeta(description: '每 5 秒随机落雷 · 范围 20 伤害', params: {'interval': 5, 'dmg': 20, 'radius': 70}),
        BuffLevelMeta(description: '每 3.5 秒落雷', params: {'interval': 3.5, 'dmg': 20, 'radius': 70}),
        BuffLevelMeta(description: '双雷同时落下', params: {'interval': 3.5, 'dmg': 20, 'radius': 70, 'doubleStrike': 1.0}),
      ],
    ),
    BuffId.emp: BuffMeta(
      id: BuffId.emp, name: '电磁脉冲', icon: '💫',
      element: Element.lightning,
      levels: [
        BuffLevelMeta(description: '击杀释放金色震荡波 · 减速50%持续2秒', params: {'radius': 100, 'slow': 0.5, 'dur': 2.0}),
        BuffLevelMeta(description: '范围+50% · 减速持续3秒', params: {'radius': 150, 'slow': 0.5, 'dur': 3.0}),
        BuffLevelMeta(description: '附加 3 秒感电 · 每秒 2 电击伤害', params: {'radius': 150, 'slow': 0.5, 'dur': 3.0, 'shock': 1.0}),
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
    // ═══ 机械系 ═══
    BuffId.droneExpansion: BuffMeta(
      id: BuffId.droneExpansion, name: '无人机扩充', icon: '🛩️',
      element: Element.universal,
      levels: [
        BuffLevelMeta(description: '无人机数量 +1', params: {}),
        BuffLevelMeta(description: '无人机数量 +1（共 2 台）', params: {}),
        BuffLevelMeta(description: '无人机数量 +1（共 3 台）', params: {}),
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
    Element.mechanical => 0xFF90CAF9,
  };
}
