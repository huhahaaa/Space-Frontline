import 'dart:math';
import 'package:flame/components.dart';
import 'buff_registry.dart';

/// 运行时 Buff 状态管理器，作为 Component 挂载在 Flame 世界中
class BuffManager extends Component {
  final Map<BuffId, int> _levels = {};

  /// 测试用：限定只刷哪些元素的 buff（null = 全部）
  Set<Element>? debugElementFilter;

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

  // ─── 随机生成候选卡（可限定元素、不填满已满级 buff）───
  List<BuffId> generateChoices({int count = 3}) {
    final rng = Random();
    final filter = debugElementFilter;
    final available = <BuffId>[];
    for (final id in BuffId.values) {
      final meta = BuffRegistry.data[id]!;
      if (levelOf(id) >= meta.maxLevel) continue;
      if (filter != null && !filter.contains(meta.element)) continue;
      // 无人机过载：至少需要 1 台无人机才出现
      if (id == BuffId.droneOverload && droneCount == 0) continue;
      available.add(id);
    }
    available.shuffle(rng);
    return available.take(count).toList();
  }

  // ═══════════════════════════════════════════
  // 通用系
  // ═══════════════════════════════════════════

  double get fireRateMultiplier {
    return switch (levelOf(BuffId.rapidFire)) {
      1 => 0.78, 2 => 0.62, 3 => 0.48, _ => 1.0,
    };
  }
  bool get rapidFireDoubleShot => levelOf(BuffId.rapidFire) >= 3;
  double get rapidFireDoubleChance => 0.15;

  double get damageMultiplier {
    double m = 1.0;
    final lv = levelOf(BuffId.powerShot);
    if (lv >= 1) m *= 1.30; // Lv.1：+30%
    if (lv >= 2) m *= 1.50; // Lv.2：在原有基础上再+50%（1.95）
    if (lv >= 3) m *= 1.70; // Lv.3：在原有基础上再+70%（3.315）
    return m;
  }
  double get powerShotEliteBonus => levelOf(BuffId.powerShot) >= 3 ? 0.20 : 0.0;

  /// 索敌比：底部多少比例是索敌区
  double get rangePercent {
    return switch (levelOf(BuffId.eagleEye)) {
      1 => 1.0, _ => 0.85,
    };
  }
  double get eagleEyeHomingBonus => levelOf(BuffId.eagleEye) >= 1 ? 0.30 : 0.0;

  double get droneCooldownMultiplier {
    return switch (levelOf(BuffId.droneOverload)) {
      1 => 0.70, 2 => 0.50, 3 => 0.50, _ => 1.0,
    };
  }
  bool get droneDoubleShot => levelOf(BuffId.droneOverload) >= 3;

  int get splitCount => switch (levelOf(BuffId.splitShot)) { 1 => 2, 2 => 3, 3 => 3, _ => 0 };
  double get splitDamagePercent => 0.5;
  bool get splitInheritsBuffs => levelOf(BuffId.splitShot) >= 3;
  bool get splitIsBurnSource => levelOf(BuffId.splitShot) >= 3;

  // ═══════════════════════════════════════════
  // 火焰系
  // ═══════════════════════════════════════════

  double get burnDps {
    return switch (levelOf(BuffId.scorchingShot)) {
      1 => 1.0, 2 => 1.6, 3 => 2.5, _ => 0,
    };
  }
  double get burnDuration => 3.0;
  bool get scorchingShotExplosion => levelOf(BuffId.scorchingShot) >= 3;

  int get fireStormLevel => levelOf(BuffId.fireStorm);
  double get fireStormRadius => fireStormLevel >= 2 ? 117 : 90;
  double get fireStormPullStrength => 115;
  double get fireStormDuration => fireStormLevel >= 2 ? 7.5 : 5.0;
  bool get fireStormDoubleSpawn => fireStormLevel >= 3;

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
  double get chainDamage {
    return switch (levelOf(BuffId.chainLightning)) {
      1 => 0.60, 2 => 0.60, 3 => 1.0, _ => 0,
    };
  }
  double get chainSlowPercent {
    return levelOf(BuffId.chainLightning) >= 3 ? 0.30 : 0;
  }

  int get staticFieldLevel => levelOf(BuffId.staticField);
  double get staticFieldInterval => staticFieldLevel >= 2 ? 3.5 : 5.0;
  double get staticFieldDamage => 20;
  double get staticFieldRadius => 70;
  int get staticFieldCount => staticFieldLevel >= 3 ? 2 : 1;

  int get empLevel => levelOf(BuffId.emp);
  double get empRadius => empLevel >= 2 ? 150 : 100;
  double get empSlowDuration => empLevel >= 2 ? 3.0 : 2.0;
  bool get empShock => empLevel >= 3;

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

  // ═══════════════════════════════════════════
  // 机械系
  // ═══════════════════════════════════════════

  int get droneCount => levelOf(BuffId.droneExpansion);

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
