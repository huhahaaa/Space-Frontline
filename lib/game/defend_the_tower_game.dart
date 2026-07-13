import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent, Element;
import 'components/tower.dart';
import 'components/wall.dart';
import 'components/enemy.dart';
import 'components/projectile.dart';

import 'components/effects.dart';
import 'components/damage_number.dart';
import 'components/lightning_chain.dart';
import 'components/lightning_strike.dart';
import 'components/elite_enemy.dart';
import 'components/nurse_enemy.dart';
import 'components/jing_lei_enemy.dart';
import 'components/drone.dart';
import 'components/drone_bullet.dart';
import 'components/fire_storm.dart';
import 'components/emp_wave.dart';
import 'buffs/buff_registry.dart';
import 'buffs/buff_manager.dart';
import 'talent_manager.dart';
import 'buffs/buff_card_data.dart';
import 'buffs/status_effects/burning.dart';
import 'buffs/status_effects/slowed.dart';
import 'buffs/status_effects/shocked.dart';
import 'buffs/status_effects/frozen.dart';
import 'buffs/status_effects/marked.dart';
import 'buffs/status_effects/feared.dart';
import 'buffs/status_effects/void_rift.dart';
import 'buffs/status_effects/purge_protected.dart';
import 'buffs/status_effects/burning_effect.dart';

class DefendTheTowerGame extends FlameGame with PointerMoveCallbacks, TapCallbacks {
  final String? _bgName;
  final bool _rotateBg;

  DefendTheTowerGame({
    String? backgroundName = 'Space Background_2.png',
    bool rotateBackground = false,
  })  : _bgName = backgroundName,
        _rotateBg = rotateBackground;

  // ─── 游戏状态 ───
  int _hp = 100;
  int get hp => _hp;
  int get maxHp => 100 + TalentManager.instance.bonusHp;
int _killCount = 0;
int get killCount => _killCount;
VoidCallback? onGameWon;

  int _exp = 0;
  int get exp => _exp;
  int _level = 1;
  int get level => _level;
  int get expToNextLevel => 50 + (_level - 1) * 30;

  final ValueNotifier<HudData> hudNotifier = ValueNotifier(
    const HudData(hp: 100, maxHp: 100, exp: 0, expToNext: 50, level: 1,
                  wave: 1, maxWave: 15, waveProgress: 1.0,
                  gameWon: false, gameOver: false, isFinalWave: false),
  );
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

  // ─── 暂停 ───
  bool _paused = false;
  bool get isPaused => _paused;

  // ─── Buff ───
  BuffManager? _buffManager;
  BuffManager? get buffManager => _buffManager;
  int _buffState = 0; // 0=idle, 1=selecting
  List<BuffId>? _buffChoices;
  final List<BuffCardSet> _buffStash = [];
  static const int maxStashSize = 3;
  double _staticFieldTimer = 999; // 选取后立即触发一次
  bool _voidRiftSpawnedThisWave = false;
  double _dotNumberTimer = 0;
  void Function()? onBuffSelectionChanged;
  final Set<int> _fearedEnemies = {};

  @override
  void onPointerMove(PointerMoveEvent event) {
    // 不再手动控制无人机
  }

  @override
  void onTapDown(TapDownEvent event) {
    // 不再手动控制无人机
  }

  // ─── 敌人生成 ───
  double _enemySpawnTimer = 0;
  double _eliteSpawnTimer = 0;
  double _nurseSpawnTimer = 0;
  double _jingLeiSpawnTimer = 0;
  static const double enemySpawnInterval = 2.2;

  // ─── 自动射击 ───
  double _fireTimer = 0;
  static const double fireInterval = 0.5;

  Tower? _tower;
  Wall? _wall;

  // ─── 无人机 ───
  final List<Drone> _drones = [];
  final List<double> _droneFireTimers = [];
  static const double droneFireCooldown = fireInterval * 3.0; // 基础射速 = 炮塔 ⅓

  // ─── 火焰风暴 ───
  double _fireStormTimer = fireStormSpawnInterval; // 首次立即触发
  static const double fireStormSpawnInterval = 10.0;

  /// 索敌范围（从 BuffManager 动态读取）
  double get rangePercent => _buffManager?.rangePercent ?? 0.80;
  double get rangeStartY => size.y * (1 - rangePercent);

  bool isInRange(Enemy enemy) => enemy.position.y >= rangeStartY;

  // ─── 波次系统 ───
  int _wave = 1;
  int get wave => _wave;
  static const int maxWave = 15;
  static const double waveDuration = 15.0;
  double _waveTimer = waveDuration;

  double _enemySpeedBonus = 1.0;
  double _enemyHpBonus = 1.0;
  double _spawnRateBonus = 1.0;
  double get currentSpawnInterval {
    final base = enemySpawnInterval / _spawnRateBonus;
    // 最后一波生成频率翻倍（间隔减半）
    if (_wave == maxWave && !_waveClearing) return base * 0.5;
    return base;
  }

  bool _gameWon = false;
  bool _gameOver = false;
  bool _waveClearing = false;
  bool get gameWon => _gameWon;
  bool get gameOver => _gameOver;

  List<PositionComponent> get enemies {
    final result = <PositionComponent>[];
    for (final c in children) {
      if ((c is Enemy || c is EliteEnemy) && !c.isRemoving) result.add(c as PositionComponent);
    }
    return result;
  }

  bool _enemyIsDead(PositionComponent c) {
    if (c is Enemy) return c.isDead;
    if (c is EliteEnemy) return c.isDead;
    return true;
  }

  List<PositionComponent> get enemiesInRange =>
      enemies.where((e) => !_enemyIsDead(e) && e.position.y >= rangeStartY).toList();

  SpriteComponent? _background;

  @override
  Color backgroundColor() => _bgName == null ? const Color(0x00000000) : const Color(0xFF0D1B2A);

  // ─── 背景 ───
  void _setupBackground() {
    if (_bgSprite == null) return;
    _background?.removeFromParent();
    if (_rotateBg) {
      _background = SpriteComponent(
        sprite: _bgSprite!,
        size: Vector2(size.y, size.x),
        anchor: Anchor.center,
        angle: pi / 2,
        priority: -100,
      );
      _background!.position = Vector2(size.x / 2, size.y / 2);
    } else {
      _background = SpriteComponent(
        sprite: _bgSprite!,
        size: size,
        anchor: Anchor.topLeft,
        priority: -100,
      );
    }
    add(_background!);
  }

  Sprite? _bgSprite;

  @override
  Future<void> onLoad() async {
    if (_bgName != null) {
      _bgSprite = await Sprite.load(_bgName);
    }
    _setupBackground();
    _spawnTower();
    _spawnWall();
    await LightningChain.preload();
    await LightningStrike.preload();
    await EmpWave.preload();
    _buffManager = BuffManager()
      ..debugElementFilter = {Element.universal, Element.fire, Element.lightning, Element.mechanical}; // 🔧 测试用
    add(_buffManager!);
    final tm = TalentManager.instance;
    tm.startGame();
    _hp = maxHp;
    _wall?.updateHp(_hp, maxHp);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _setupBackground();
    _repositionWall();
    _repositionTowerAndDrones();
    _updateEliteStopPositions();
  }

  void _updateEliteStopPositions() {
    final halfY = size.y * 0.5;
    for (final e in children.whereType<EliteEnemy>()) {
      e.stopY = halfY;
    }
  }

  void _repositionTowerAndDrones() {
    if (_tower == null) return;
    // 塔站在城墙上方
    final wallH = _wall?.size.y ?? 0;
    _tower!.position = Vector2(size.x / 2, size.y - wallH - 10);
    _layoutDrones();
  }

  /// 按无人机数量排列位置
  void _layoutDrones() {
    if (_tower == null) return;
    final towerPos = _tower!.position;
    // 分散排列：右、左、上中
    final offsets = [
      Vector2(size.x * 0.20, -5),
      Vector2(-size.x * 0.20, -5),
      Vector2(0, -size.y * 0.06),
    ];
    for (int i = 0; i < _drones.length && i < offsets.length; i++) {
      _drones[i].position = towerPos + offsets[i];
    }
  }

  /// 根据 Buff 等级同步无人机数量
  void _syncDroneCount() {
    final target = _buffManager?.droneCount ?? 0;
    while (_drones.length < target) {
      _spawnDrone();
    }
    // 不减少（buff等级不会下降）
  }

  // ─── 塔 ───
  void _spawnTower() {
    _tower = Tower();
    _repositionTowerAndDrones();
    add(_tower!);
  }

  void _spawnWall() {
    _wall = Wall();
    _wall!.updateHp(_hp, maxHp);
    _repositionWall();
    add(_wall!);
  }

  void _repositionWall() {
    if (_wall == null) return;
    _wall!.setScreenSize(size.x, size.y);
  }

  // ─── 无人机 ───
  void _spawnDrone() {
    if (_tower == null) return;
    final drone = Drone();
    _drones.add(drone);
    _droneFireTimers.add(0);
    add(drone);
    _layoutDrones();
  }

  void _fireDroneBulletFrom(Drone drone) {
    // 自瞄：找最近敌人作为射击方向
    final inRange = enemiesInRange;
    Vector2 dir;
    if (inRange.isNotEmpty) {
      PositionComponent? nearest;
      double nearestDist = double.infinity;
      for (final enemy in inRange) {
        final dist = enemy.position.distanceTo(drone.position);
        if (dist < nearestDist) {
          nearestDist = dist;
          nearest = enemy;
        }
      }
      if (nearest != null) {
        dir = (nearest.position - drone.position).normalized();
      } else {
        dir = Vector2(0, -1);
      }
    } else {
      dir = Vector2(0, -1); // 无敌人时默认朝上
    }

    void launch() {
      final bullet = DroneBullet(direction: dir);
      bullet.position = drone.position.clone();
      add(bullet);
    }

    launch();
    final bm = _buffManager;
    if (bm != null && bm.droneDoubleShot) {
      final angledDir = Vector2(
        cos(atan2(dir.y, dir.x) + 0.15),
        sin(atan2(dir.y, dir.x) + 0.15),
      );
      final bullet2 = DroneBullet(direction: angledDir);
      bullet2.position = drone.position.clone();
      add(bullet2);
    }
  }

  // ─── 射击 ───
  void _fireBullet() {
    if (_tower == null || _buffManager == null) return;

    final inRange = enemiesInRange;
    if (inRange.isEmpty) return;

    PositionComponent? target;
    double nearest = double.infinity;
    for (final enemy in inRange) {
      final d = enemy.position.distanceTo(_tower!.position);
      if (d < nearest) { nearest = d; target = enemy; }
    }
    if (target == null) return;

    final bm = _buffManager!;
    final baseDamage = 1.0;
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

    // 双发（急速射击 Lv.3）— 微角度偏移避免完全重叠
    if (bm.rapidFireDoubleShot && Random().nextDouble() < bm.rapidFireDoubleChance) {
      _launchBullet(finalDamage, target, angleOffset: 0.13);
    }
  }

  bool get _hasFireBuff {
    final bm = _buffManager;
    if (bm == null) return false;
    return bm.has(BuffId.scorchingShot) ||
        bm.has(BuffId.fireStorm) ||
        bm.has(BuffId.emberEcho);
  }

  void _launchBullet(double damage, PositionComponent target, {double angleOffset = 0}) {
    if (_tower == null || _buffManager == null) return;
    final bm = _buffManager!;
    final toTarget = target.position - _tower!.position;
    final angle = atan2(toTarget.y, toTarget.x) + angleOffset;
    final direction = Vector2(cos(angle), sin(angle));

    final homingBonus = bm.eagleEyeHomingBonus;
    const dist = Tower.muzzleDistance;
    final muzzleX = _tower!.position.x + cos(angle) * dist;
    final muzzleY = _tower!.position.y + sin(angle) * dist;

    final spriteName = _hasFireBuff ? 'bullet_03.png' : 'bullet_01.png';

    final bullet = Projectile(
      direction: direction,
      target: target,
      homingStrength: 0.12 + homingBonus,
      speed: 440,
      damage: damage,
      spriteName: spriteName,
    );
    bullet.position = Vector2(muzzleX, muzzleY);
    add(bullet);
  }

  // ─── 敌人 ───
  void _spawnEnemy() {
    final rng = Random();
    final enemy = Enemy(
      speedMultiplier: _enemySpeedBonus,
      hpMultiplier: _enemyHpBonus,
    );
    final marginX = size.x * 0.12;
    enemy.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -30.0,
    );
    add(enemy);
  }

  /// 在指定位置生成普通敌人（精英产怪用）
  void _spawnEnemyAt(Vector2 pos) {
    final enemy = Enemy(
      speedMultiplier: _enemySpeedBonus,
      hpMultiplier: _enemyHpBonus,
    );
    enemy.position = pos.clone();
    add(enemy);
  }

  void _spawnNurse() {
    final rng = Random();
    final nurse = NurseEnemy(
      speedMultiplier: _enemySpeedBonus,
      hpMultiplier: _enemyHpBonus,
    );
    final marginX = size.x * 0.12;
    nurse.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -30.0,
    );
    add(nurse);
  }

  void _spawnJingLei() {
    final rng = Random();
    final jl = JingLeiEnemy(
      speedMultiplier: _enemySpeedBonus,
      hpMultiplier: _enemyHpBonus,
    );
    final marginX = size.x * 0.12;
    jl.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -30.0,
    );
    add(jl);
  }

  void _spawnEliteEnemy() {
    final rng = Random();
    final elite = EliteEnemy(
      speedMultiplier: _enemySpeedBonus,
      hpMultiplier: _enemyHpBonus,
    );
    elite.stopY = size.y * 0.5;
    final marginX = size.x * 0.12;
    elite.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -60.0,
    );
    elite.minionSpawnInterval = currentSpawnInterval;
    elite.onSpawnMinion = () => _spawnEnemyAt(elite.position.clone());
    add(elite);
  }

  // ─── 碰撞 ───
  void _checkCollisions() {
    // 普通子弹
    final bullets = children.whereType<Projectile>().toList();
    for (final bullet in bullets) {
      if (_bulletHitsAnyShockwave(bullet.position)) {
        bullet.removeFromParent();
        continue;
      }

      for (final enemy in enemies) {
        if (_enemyIsDead(enemy)) continue;
        if (enemy == bullet.ignoreEnemy) continue;
        if (bullet.toRect().overlaps(enemy.toRect())) {
          double dmg = bullet.damage;

          // 命中 Buff（分裂弹 Lv.1-2 不触发）
          if (bullet.applyBuffs) {
            _tryChainLightning(bullet.position, enemy, dmg);
            _tryApplyBurning(enemy);
            if (_buffManager!.splitInheritsBuffs && _buffManager!.burnDps > 0) {
              _tryApplySplitBurning(enemy);
            }
            _tryApplyFrostSlow(enemy);
          }

          if (enemy is Enemy) enemy.takeDamage(dmg);
          if (enemy is EliteEnemy) enemy.takeDamage(dmg);

          add(HitFlash(at: enemy.position.clone()));
          add(DamageNumber(amount: dmg, at: enemy.position.clone(), color: Colors.white));

          // 分裂弹（仅原弹触发，分裂弹不再分裂）
          if (!bullet.isSplit) {
            final splitCount = _buffManager!.splitCount;
            if (splitCount > 0) {
              _spawnSplitBullets(bullet.position, enemy, dmg, splitCount);
            }
          }

          bullet.removeFromParent();
          if (_enemyIsDead(enemy)) _onEnemyKilled(enemy);
          break;
        }
      }
    }

    // 无人机穿透弹
    final droneBullets = children.whereType<DroneBullet>().toList();
    for (final bullet in droneBullets) {
      for (final enemy in enemies) {
        if (_enemyIsDead(enemy)) continue;
        if (bullet.tryHit(enemy)) {
          // 暗影标记
          _tryApplyShadowMark(enemy);

          add(HitFlash(at: enemy.position.clone()));
          add(DamageNumber(amount: DroneBullet.damage, at: enemy.position.clone(), color: Colors.white));
          if (_enemyIsDead(enemy)) _onEnemyKilled(enemy);
        }
      }
    }
  }

  // ─── 命中触发 ───

  void _tryChainLightning(Vector2 hitPos, PositionComponent originEnemy, double baseDmg) {
    final bm = _buffManager!;
    if (bm.chainCount == 0) return;

    final chainDmg = bm.chainDamage;
    final chainSlow = bm.chainSlowPercent;
    final used = <PositionComponent>{originEnemy};

    PositionComponent? current = originEnemy;
    for (int i = 0; i < bm.chainCount; i++) {
      PositionComponent? nearest;
      double nearestDist = double.infinity;
      for (final e in enemies) {
        if (_enemyIsDead(e)) continue;
        if (used.contains(e)) continue;
        final d = e.position.distanceTo(current!.position);
        if (d < nearestDist) { nearestDist = d; nearest = e; }
      }
      if (nearest == null) break;

      // 连锁闪电特效：从 current 到 nearest 建立链接
      add(LightningChain(from: current!.position.clone(), to: nearest.position.clone()));

      if (nearest is Enemy) nearest.takeDamage(chainDmg);
      if (nearest is EliteEnemy) nearest.takeDamage(chainDmg);
      add(HitFlash(at: nearest.position.clone()));
      add(DamageNumber(amount: chainDmg, at: nearest.position.clone(), color: const Color(0xFFFFD740), icon: '⚡'));

      _tryApplyBurning(nearest);
      _tryApplyFrostSlow(nearest);

      // Lv.3：被链命中的敌人额外减速 30%
      if (chainSlow > 0) {
        final comp = nearest as Component;
        var slowed = comp.firstChild<Slowed>();
        if (slowed != null) {
          slowed.refresh(2.0);
        } else {
          comp.add(Slowed(factor: chainSlow, duration: 2.0));
        }
      }

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
      // 同源覆盖，不叠加层数
      burning.apply(BurnSource.scorchingShot, bm.burnDps, bm.burnDuration);
    } else {
      final b = Burning(duration: bm.burnDuration);
      b.apply(BurnSource.scorchingShot, bm.burnDps, bm.burnDuration);
      comp.add(b);
      comp.add(BurningEffect());
    }
  }

  /// 分裂弹灼烧（Lv.3 — 新燃烧来源，½层数）
  void _tryApplySplitBurning(PositionComponent enemy) {
    final bm = _buffManager!;
    final stacks = bm.burnDps * 0.5;
    final comp = enemy as Component;
    var burning = comp.firstChild<Burning>();
    if (burning != null) {
      burning.apply(BurnSource.splitShot, stacks, bm.burnDuration);
    } else {
      final b = Burning(duration: bm.burnDuration);
      b.apply(BurnSource.splitShot, stacks, bm.burnDuration);
      comp.add(b);
      comp.add(BurningEffect());
    }
  }

  /// 分裂弹：在命中位置模拟"隐形炮塔"，发出 N 颗追踪小子弹
  /// 瞄准、追踪机制与炮塔主弹完全一致
  void _spawnSplitBullets(Vector2 origin, PositionComponent hitEnemy, double mainDamage, int count) {
    final bm = _buffManager!;
    final subDamage = mainDamage * bm.splitDamagePercent;
    final inheritBuffs = bm.splitInheritsBuffs;

    // 找附近存活的敌人（按距离排序），排除被分裂的源敌人
    final targets = enemies
        .where((e) => !_enemyIsDead(e) && e != hitEnemy)
        .toList();
    targets.sort((a, b) => a.position.distanceTo(origin).compareTo(b.position.distanceTo(origin)));

    for (int i = 0; i < count; i++) {
      final target = targets.isNotEmpty ? targets[i % targets.length] : null;
      Vector2 direction;
      if (target != null) {
        // 与 _launchBullet 完全相同的瞄准逻辑
        final toTarget = target.position - origin;
        final angle = atan2(toTarget.y, toTarget.x);
        direction = Vector2(cos(angle), sin(angle));
      } else {
        // 无目标时向外散射（往上方向）
        final a = (i - (count - 1) / 2) * 0.45;
        direction = Vector2(sin(a), -cos(a)).normalized();
      }

      final bullet = Projectile(
        direction: direction,
        target: target,
        homingStrength: 0.12,
        speed: 440,
        damage: subDamage,
        applyBuffs: inheritBuffs,
        visualScale: 0.8,
        isSplit: true,
        ignoreEnemy: hitEnemy,
      );
      bullet.position = origin.clone();
      add(bullet);
    }
  }

  void _tryApplyFrostSlow(PositionComponent enemy) {
    // 惊雷最终形态免疫减速
    if (enemy is JingLeiEnemy && enemy.immuneToCrowdControl) return;
    final bm = _buffManager!;
    if (bm.frostSlowFactor <= 0) return;

    final comp = enemy as Component;
    var slowed = comp.firstChild<Slowed>();
    if (slowed != null) {
      slowed.refresh(2.0);
    } else {
      comp.add(Slowed(factor: bm.frostSlowFactor, duration: 2.0));
    }

    // 冰冻判定
    double totalSlow = bm.frostSlowFactor;
    if (bm.frostAuraLevel > 0) totalSlow += bm.frostAuraSlow;
    if (totalSlow >= 0.80 && bm.frostShotFreeze) {
      var frozen = comp.firstChild<Frozen>();
      if (frozen != null) {
        frozen.refresh(1.0);
      } else {
        comp.add(Frozen(duration: 1.0));
      }
    }
  }

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

  void _checkEnemiesOffScreen() {
    for (final enemy in enemies) {
      if (enemy.position.y > size.y - 10) _onEnemyReachedBottom(enemy);
    }
  }

  // ─── 击杀事件 ───
  void _onEnemyKilled(PositionComponent enemy) {
    final bm = _buffManager!;

    add(DeathExplosion(at: enemy.position.clone()));

    // 灼烧死亡爆炸：燃烧敌人死亡时对周围造成直接伤害
    if (bm.scorchingShotExplosion) {
      final burn = (enemy as Component).firstChild<Burning>();
      if (burn != null) {
        for (final e in enemies) {
          if (_enemyIsDead(e) || e == enemy) continue;
          final dist = e.position.distanceTo(enemy.position);
          if (dist <= 100) {
            final explosionDmg = burn.dps * 3; // 基于灼烧层数的爆炸伤害
            if (e is Enemy) e.takeDamage(explosionDmg);
            if (e is EliteEnemy) e.takeDamage(explosionDmg);
            add(DamageNumber(amount: explosionDmg, at: e.position.clone(), color: const Color(0xFFFF6D3F), icon: '💥'));
            if (_enemyIsDead(e)) _onEnemyKilled(e);
          }
        }
      }
    }

    // 余烬余波：击杀任意敌人灼烧周围，固定传播 0.5 层
    if (bm.emberEchoLevel > 0) {
      _spreadBurningToNearby(enemy, BurnSource.emberEcho, 0.5, bm.burnDuration, bm.emberEchoRadius);
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

    int expGain = 10;
    if (enemy is Enemy) expGain = enemy.expValue;
    if (enemy is EliteEnemy) expGain = enemy.expValue;
    _exp += expGain;
    _notifyHud();

    _killCount++;
    enemy.removeFromParent();
  }

  // ─── 效果辅助 ───

  void _spreadBurningToNearby(PositionComponent origin, BurnSource source, double stacks, double dur, double radius) {
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      final dist = e.position.distanceTo(origin.position);
      if (dist <= radius) {
        final comp = e as Component;
        var burning = comp.firstChild<Burning>();
        if (burning != null) {
          // 余烬余波 Lv.3：同源可叠加
          if (source == BurnSource.emberEcho && _buffManager!.emberEchoStack) {
            burning.addStacks(source, stacks, dur);
          } else {
            burning.apply(source, stacks, dur);
          }
        } else {
          final b = Burning(duration: dur);
          b.apply(source, stacks, dur);
          comp.add(b);
          comp.add(BurningEffect());
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
    // 金色震荡波视觉
    final wave = EmpWave(maxRadius: radius);
    wave.position = origin.position.clone();
    add(wave);

    final bm = _buffManager!;
    final slowDuration = bm.empSlowDuration;
    final applyShock = bm.empShock;

    // 减速 + 感电所有范围内敌人
    for (final e in children.whereType<Enemy>()) {
      if (_enemyIsDead(e)) continue;
      if (e.position.distanceTo(origin.position) <= radius) {
        final comp = e as Component;
        var slowed = comp.firstChild<Slowed>();
        if (slowed != null) {
          slowed.refresh(slowDuration);
        } else {
          comp.add(Slowed(factor: 0.5, duration: slowDuration));
        }
        if (applyShock) {
          var shocked = comp.firstChild<Shocked>();
          if (shocked != null) {
            shocked.refresh(3.0);
          } else {
            comp.add(Shocked(dps: 2.0, duration: 3.0));
          }
        }
      }
    }

    for (final elite in children.whereType<EliteEnemy>()) {
      if (_enemyIsDead(elite)) continue;
      if (elite.position.distanceTo(origin.position) <= radius) {
        final comp = elite as Component;
        var slowed = comp.firstChild<Slowed>();
        if (slowed != null) {
          slowed.refresh(slowDuration);
        } else {
          comp.add(Slowed(factor: 0.5, duration: slowDuration));
        }
        if (applyShock) {
          var shocked = comp.firstChild<Shocked>();
          if (shocked != null) {
            shocked.refresh(3.0);
          } else {
            comp.add(Shocked(dps: 2.0, duration: 3.0));
          }
        }
      }
    }
  }

  void _tryBloodthirstHeal() {
    final bm = _buffManager!;
    if (Random().nextDouble() >= bm.bloodthirstChance) return;
    final healAmount = (maxHp * bm.bloodthirstHealPercent).round();
    _hp = (_hp + healAmount).clamp(0, maxHp);
    _wall?.updateHp(_hp, maxHp);
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

  // ─── 极寒光环 ───
  void _applyFrostAura() {
    final bm = _buffManager!;
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      final dist = e.position.distanceTo(_tower!.position);
      if (dist <= bm.frostAuraRadius) {
        final comp = e as Component;
        var slowed = comp.firstChild<Slowed>();
        if (slowed != null) {
          slowed.refresh(0.5);
        } else {
          comp.add(Slowed(factor: bm.frostAuraSlow, duration: 0.5));
        }
      }
    }
  }

  // ─── 恐惧之触 ───
  void _checkFearTouch() {
    final bm = _buffManager!;
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      final id = e.hashCode;
      if (!_fearedEnemies.contains(id) && e.position.y >= rangeStartY) {
        _fearedEnemies.add(id);
        if (Random().nextDouble() < bm.fearTouchChance) {
          (e as Component).add(Feared(duration: bm.fearTouchDuration));
        }
      }
    }
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

  // ─── 护士净化光环（每 2.5s 跳一次）───
  void _updateNurseAuras(double dt) {
    final nurses = children.whereType<NurseEnemy>().toList();
    if (nurses.isEmpty) return;

    final allEnemies = <PositionComponent>[];
    for (final c in children) {
      if ((c is Enemy || c is EliteEnemy) && !c.isRemoving) {
        allEnemies.add(c as PositionComponent);
      }
    }

    for (final nurse in nurses) {
      if (nurse.shouldPurgeTick()) {
        final heals = nurse.purgeTick(allEnemies);
        for (final h in heals) {
          add(DamageNumber.heal(amount: h.amount, at: h.target.position.clone()));
        }
      }
    }
  }

  // ─── 惊雷闪电链攻击 ───
  void _updateJingLeiAttacks() {
    final jingLeis = children.whereType<JingLeiEnemy>().toList();
    if (jingLeis.isEmpty) return;

    final allEnemies = <PositionComponent>[];
    for (final c in children) {
      if ((c is Enemy || c is EliteEnemy) && !c.isRemoving) {
        allEnemies.add(c as PositionComponent);
      }
    }

    for (final jl in jingLeis) {
      if (!jl.shouldChainAttack()) continue;

      final result = jl.tryChainAttack(allEnemies);
      if (result == null) continue;

      final target = result.target;
      final wasKilled = result.killed;

      // 闪电链视觉（由游戏侧添加，避免 findGame 竞态）
      add(LightningChain(
        from: jl.position.clone(),
        to: target.position.clone(),
      ));

      // 伤害数字
      add(HitFlash(at: target.position.clone()));
      add(DamageNumber(
        amount: JingLeiEnemy.chainDamage,
        at: target.position.clone(),
        color: const Color(0xFFFFD740),
        icon: '⚡',
      ));

      if (wasKilled) {
        jl.onFriendlyKilled();
        _onEnemyKilled(target);
      }
    }
  }

  // ─── 静电场 ───
  void _updateStaticField(double dt) {
    final bm = _buffManager!;
    _staticFieldTimer += dt;
    if (_staticFieldTimer >= bm.staticFieldInterval) {
      _staticFieldTimer = 0;
      final alive = enemies
          .where((e) => !_enemyIsDead(e) && e.position.y > size.y * 0.08)
          .toList();
      if (alive.isEmpty) return;
      final rng = Random();
      alive.shuffle(rng);
      final strikeCount = bm.staticFieldCount.clamp(1, alive.length);
      for (int i = 0; i < strikeCount; i++) {
        final target = alive[i];
        final center = target.position.clone();
        // 定住目标敌人（0.7s 后解除）
        target.add(Frozen(duration: 0.7));
        // 落雷视觉 + 延迟伤害
        add(LightningStrike(
          target: center,
          startY: 0,
          onStrike: () {
            for (final e in enemies) {
              if (_enemyIsDead(e)) continue;
              if (e.position.distanceTo(center) <= bm.staticFieldRadius) {
                if (e is Enemy) e.takeDamage(bm.staticFieldDamage);
                if (e is EliteEnemy) e.takeDamage(bm.staticFieldDamage);
                add(HitFlash(at: e.position.clone()));
                add(DamageNumber(amount: bm.staticFieldDamage, at: e.position.clone(), color: const Color(0xFFFFD740), icon: '⚡'));
                if (_enemyIsDead(e)) _onEnemyKilled(e);
              }
            }
          },
        ));
      }
    }
  }

  // ─── 虚空裂隙 ───
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

  // ─── 火焰风暴 ───
  void _spawnFireStorm() {
    final bm = _buffManager!;
    final rng = Random();
    final x = size.x * 0.15 + rng.nextDouble() * size.x * 0.7;
    final y = size.y * 0.15 + rng.nextDouble() * size.y * 0.55;
    final storm = FireStorm(
      radius: bm.fireStormRadius,
      pullStrength: bm.fireStormPullStrength,
      duration: bm.fireStormDuration,
    );
    storm.position = Vector2(x, y);
    add(storm);
  }

  void _updateFireStorms(double dt) {
    final storms = children.whereType<FireStorm>().toList();
    if (storms.isEmpty) return;

    // 重置所有敌人的易燃标记
    final enemies = children.whereType<Enemy>().toList();
    final elites = children.whereType<EliteEnemy>().toList();
    for (final e in enemies) {
      e.isFlammable = false;
    }
    for (final e in elites) {
      e.isFlammable = false;
    }

    // 构建全敌人列表（用于索敌，排除已死亡）
    final allEnemies = <PositionComponent>[
      ...enemies.where((e) => !_enemyIsDead(e)),
      ...elites.where((e) => !_enemyIsDead(e)),
    ];

    // 对每个风暴，索敌 + 吸引 + 易燃
    for (final storm in storms) {
      storm.seekTargets(allEnemies, dt);
      for (final e in enemies) {
        if (_enemyIsDead(e)) continue;
        final purged = e.firstChild<PurgeProtected>();
        final jlImmune = e is JingLeiEnemy && e.immuneToCrowdControl;
        final ccImmune = (purged != null && purged.isActive) || jlImmune;
        final dist = e.position.distanceTo(storm.position);
        if (dist < storm.radius && dist > 1) {
          if (!ccImmune) {
            final toStorm = storm.position - e.position;
            final strength = storm.pullStrength * (1 - dist / storm.radius);
            e.position += toStorm.normalized() * strength * dt;
          }
          if (!ccImmune) {
            e.isFlammable = true;
          }
        }
      }
      for (final e in elites) {
        if (_enemyIsDead(e)) continue;
        final purged = e.firstChild<PurgeProtected>();
        final dist = e.position.distanceTo(storm.position);
        if (dist < storm.radius && dist > 1) {
          if (purged == null || !purged.isActive) {
            final toStorm = storm.position - e.position;
            final strength = storm.pullStrength * (1 - dist / storm.radius);
            e.position += toStorm.normalized() * strength * dt;
          }
          if (purged == null || !purged.isActive) {
            e.isFlammable = true;
          }
        }
      }
    }
  }

  void _onEnemyReachedBottom(PositionComponent enemy) {
    final explosionPos = enemy.position.clone();
    // 护盾抵消
    if (_buffManager != null && _buffManager!.consumeShield()) {
      add(DeathExplosion(at: explosionPos));
      enemy.removeFromParent();
      _notifyHud();
      return;
    }
    add(DeathExplosion(at: explosionPos));
    final dmg = (enemy is JingLeiEnemy && enemy.isFinalForm) ? 10 : 5;
    _hp -= dmg;
    _wall?.updateHp(_hp, maxHp);
    _notifyHud();
    enemy.removeFromParent();
    if (_hp <= 0) {
      _hp = 0;
      _wall?.updateHp(_hp, maxHp);
      _gameOver = true;
      _notifyHud();
    }
  }

  void _autoAimAtNearestEnemy() {
    if (_tower == null) return;

    final inRange = enemiesInRange;
    if (inRange.isEmpty) {
      _tower!.aimAt(Vector2(_tower!.position.x, 0));
      return;
    }

    PositionComponent? nearest;
    double nearestDist = double.infinity;
    for (final enemy in inRange) {
      final dist = enemy.position.distanceTo(_tower!.position);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = enemy;
      }
    }

    if (nearest != null) _tower!.aimAt(nearest.position);
  }

  // ─── Buff 选择 ───
  void _triggerLevelUp() {
    _exp -= expToNextLevel;
    _level++;
    _paused = true;
    _buffState = 1;
    _buffChoices = _buffManager!.generateChoices(count: TalentManager.instance.buffChoiceCount);
    _notifyHud();
    onBuffSelectionChanged?.call();
  }

  void selectBuff(BuffId id) {
    _buffManager!.addLevel(id);
    _buffState = 0;
    _buffChoices = null;
    _paused = false;
    _notifyHud();
    onBuffSelectionChanged?.call();
  }

  void skipBuff() {
    if (_buffChoices == null) return;
    _buffStash.add(BuffCardSet(List.from(_buffChoices!)));
    if (_buffStash.length > maxStashSize) {
      _buffStash.removeAt(0);
    }
    _buffState = 0;
    _buffChoices = null;
    _paused = false;
    _notifyHud();
    onBuffSelectionChanged?.call();
  }

  void rerollBuffChoices() {
    final tm = TalentManager.instance;
    if (!tm.useReroll()) return;
    _buffChoices = _buffManager!.generateChoices(count: tm.buffChoiceCount);
    _notifyHud();
    onBuffSelectionChanged?.call();
  }

  void selectFromStash(int index) {
    if (index < 0 || index >= _buffStash.length) return;
    final cardSet = _buffStash.removeAt(index);
    _paused = true;
    _buffState = 1;
    _buffChoices = cardSet.choices;
    _notifyHud();
    onBuffSelectionChanged?.call();
  }

  // ─── 主循环 ───
  @override
  void update(double dt) {
    if (_gameWon || _gameOver) {
      super.update(0);
      _notifyHud();
      return;
    }
    if (_paused) {
      // 暂停：子组件传递 dt=0（冻结敌人/子弹移动），仅 HUD 刷新
      super.update(0);
      _notifyHud();
      return;
    }
    super.update(dt);

    // 检查升级触发
    if (_exp >= expToNextLevel && _buffState == 0) {
      _triggerLevelUp();
      // 升级后立即结算 buff 选择，后续 update 被 paused 拦截
      if (_paused) return;
    }

    // ① 塔自动瞄准
    _autoAimAtNearestEnemy();

    // ② 无人机：同步数量 + 自瞄 + 自动射击
    _syncDroneCount();
    final droneCd = droneFireCooldown * (_buffManager?.droneCooldownMultiplier ?? 1.0);
    for (int i = 0; i < _drones.length; i++) {
      final drone = _drones[i];
      // 自瞄最近敌人
      final inRange = enemiesInRange;
      if (inRange.isNotEmpty) {
        PositionComponent? nearest;
        double nearestDist = double.infinity;
        for (final enemy in inRange) {
          final dist = enemy.position.distanceTo(drone.position);
          if (dist < nearestDist) {
            nearestDist = dist;
            nearest = enemy;
          }
        }
        if (nearest != null) {
          drone.aimAt(nearest.position);
        } else {
          drone.aimAt(Vector2(drone.position.x, 0));
        }
      } else {
        drone.aimAt(Vector2(drone.position.x, 0));
      }
      // 射击计时
      _droneFireTimers[i] += dt;
      if (_droneFireTimers[i] >= droneCd) {
        _droneFireTimers[i] = 0;
        _fireDroneBulletFrom(drone);
      }
    }

    // ③ 自动射击
    _fireTimer += dt;
    final effectiveInterval = fireInterval * (_buffManager?.fireRateMultiplier ?? 1.0);
    if (_fireTimer >= effectiveInterval) {
      _fireTimer = 0;
      _fireBullet();
    }

    // ④ 波次计时
    _waveTimer -= dt;
    if (_waveTimer <= 0) _advanceWave();

    _notifyHud();

    // ④½ 同步精英产怪间隔（跟随波次频率）
    for (final elite in children.whereType<EliteEnemy>()) {
      elite.minionSpawnInterval = currentSpawnInterval / 0.3;
    }

    // ⑤ 敌人生成
    final stopSpawning = _waveClearing;
    if (!stopSpawning) {
      _enemySpawnTimer += dt;
      if (_enemySpawnTimer >= currentSpawnInterval) {
        _enemySpawnTimer = 0;
        _spawnEnemy();
      }
      if (_wave >= 2) {
        _eliteSpawnTimer += dt;
        if (_eliteSpawnTimer >= currentSpawnInterval * 4) {
          _eliteSpawnTimer = 0;
          _spawnEliteEnemy();
        }
      }
      // 惊雷：第 1 波就出现（测试）
      _jingLeiSpawnTimer += dt;
      if (_jingLeiSpawnTimer >= currentSpawnInterval * 6) {
        _jingLeiSpawnTimer = 0;
        _spawnJingLei();
      }
      // 护士：第 5 波后出现
      if (_wave >= 5) {
        _nurseSpawnTimer += dt;
        if (_nurseSpawnTimer >= currentSpawnInterval * 3) {
          _nurseSpawnTimer = 0;
          _spawnNurse();
        }
      }
    }

    // ⑥ 光环 / 恐惧
    if (_buffManager?.frostAuraLevel != null && _buffManager!.frostAuraLevel > 0 && _tower != null) {
      _applyFrostAura();
    }
    if (_buffManager?.fearTouchLevel != null && _buffManager!.fearTouchLevel > 0) {
      _checkFearTouch();
    }

    // ⑥½ 护士治疗光环
    _updateNurseAuras(dt);

    // ⑥¾ 惊雷闪电链攻击
    _updateJingLeiAttacks();

    // ⑦ 静电场
    if (_buffManager?.staticFieldLevel != null && _buffManager!.staticFieldLevel > 0) {
      _updateStaticField(dt);
    }

    // ⑧ 虚空裂隙
    if (_buffManager?.voidRiftLevel != null && _buffManager!.voidRiftLevel > 0) {
      _updateVoidRift(dt);
    }

    // ⑧½ 火焰风暴：定时生成 + 吸引敌人 + 施加易燃
    if (_buffManager?.fireStormLevel != null && _buffManager!.fireStormLevel > 0) {
      _fireStormTimer += dt;
      if (_fireStormTimer >= fireStormSpawnInterval) {
        _fireStormTimer = 0;
        _spawnFireStorm();
        if (_buffManager!.fireStormDoubleSpawn) {
          _spawnFireStorm();
        }
      }
      // 重置易燃标记 + 施加吸引力
      _updateFireStorms(dt);
    }

    // DOT 伤害数字计时器
    _dotNumberTimer += dt;
    final showDotNumber = _dotNumberTimer >= 0.4;

    // ⑨ 灼烧 DPS（处理所有燃烧敌人，包括传播燃烧）
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      final burning = (e as Component).firstChild<Burning>();
      if (burning != null && !burning.isExpired) {
        final flammable = (e is Enemy) ? e.isFlammable : (e is EliteEnemy) ? e.isFlammable : false;
        final dps = burning.dps * (flammable ? 2.0 : 1.0);
        if (e is Enemy) e.takeDamage(dps * dt);
        if (e is EliteEnemy) e.takeDamage(dps * dt);
        if (showDotNumber) {
          add(DamageNumber(amount: dps, at: e.position.clone(), color: const Color(0xFFFF6D3F), icon: '🔥'));
        }
        if (_enemyIsDead(e)) _onEnemyKilled(e);
      }
    }

    // ⑨½ 感电 DPS
    for (final e in enemies) {
      if (_enemyIsDead(e)) continue;
      final shocked = (e as Component).firstChild<Shocked>();
      if (shocked != null && !shocked.isExpired) {
        if (e is Enemy) e.takeDamage(shocked.dps * dt);
        if (e is EliteEnemy) e.takeDamage(shocked.dps * dt);
        if (showDotNumber) {
          add(DamageNumber(amount: shocked.dps, at: e.position.clone(), color: const Color(0xFFFFD740), icon: '⚡'));
        }
        if (_enemyIsDead(e)) _onEnemyKilled(e);
      }
    }

    // ⑩ 虚空裂隙伤害 + 吸引
    for (final rift in children.whereType<VoidRift>()) {
      for (final e in enemies) {
        if (_enemyIsDead(e)) continue;
        final dist = e.position.distanceTo(rift.position);
        if (dist <= rift.radius) {
          if (e is Enemy) e.takeDamage(rift.dps * dt);
          if (e is EliteEnemy) e.takeDamage(rift.dps * dt);
          if (showDotNumber) {
            add(DamageNumber(amount: rift.dps, at: e.position.clone(), color: const Color(0xFFAB47BC), icon: '🌑'));
          }
          if (_enemyIsDead(e)) _onEnemyKilled(e);
          if (rift.pullStrength > 0) {
            final toRift = rift.position - e.position;
            if (toRift.length > 1) {
              e.position += toRift.normalized() * rift.pullStrength * dt;
            }
          }
        }
      }
    }

    if (showDotNumber) _dotNumberTimer = 0;

    // ⑪ 碰撞
    _checkCollisions();
    _checkEnemiesOffScreen();

    // ⑫ 清场 → 胜利
    if (_waveClearing && enemies.isEmpty) {
      _gameWon = true;
      _notifyHud();
      onGameWon?.call();
    }
  }

  void _advanceWave() {
    if (_wave >= maxWave) {
      _waveTimer = 0;
      _waveClearing = true;
      _notifyHud();
      return;
    }
    _wave++;
    _exp += TalentManager.instance.bonusExpPerWave;
    _waveTimer = _wave == maxWave ? waveDuration * 2 : waveDuration;
    _enemyHpBonus += 0.25;
    _enemySpeedBonus += 0.08;
    _spawnRateBonus += 0.10;
    _voidRiftSpawnedThisWave = false;
    _fearedEnemies.clear();
    if (_buffManager?.frostAuraShield == true) {
      _buffManager!.addWaveShield();
    }
  }

  bool _bulletHitsAnyShockwave(Vector2 point) {
    final elites = children.whereType<EliteEnemy>()
        .where((e) => e.shockwaveActive);
    for (final e in elites) {
      if (e.isInsideShockwave(point)) return true;
    }
    return false;
  }
}

class HudData {
  final int hp; final int maxHp;
  final int exp; final int expToNext; final int level;
  final int wave; final int maxWave; final double waveProgress;
  final bool gameWon; final bool gameOver; final bool isFinalWave;
  final bool paused;
  final int buffState;
  final List<BuffId>? buffChoices;
  final List<List<BuffId>> buffStash;
  final Map<BuffId, int> activeBuffs;

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
