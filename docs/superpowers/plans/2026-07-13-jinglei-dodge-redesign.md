# 惊雷闪避重设计实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将惊雷纯横向位移闪避替换为弧线冲刺 + 残影 + 粒子拖尾 + 1.5s 冷却的华丽闪避系统。

**Architecture:** 所有改动集中在 `jing_lei_enemy.dart` 单文件内。添加状态机（IDLE/DODGING/COOLDOWN）、贝塞尔弧线路径、残影采样列表、粒子列表。`render()` 内直接绘制残影和粒子，不创建额外 Component。`takeDamage()` 在冲刺期间免疫。

**Tech Stack:** Dart 3.x, Flame 1.26.1, `dart:ui` Canvas, `dart:math`

## Global Constraints

- 坐标约定：y=0 顶部，y=size.y 底部，高度从底部向上计算
- 所有游戏实体使用 `Anchor.center`
- `update()` 必须调用 `super.update(dt)`
- `render()` 必须调用 `super.render(canvas)`
- 避免在 `update()`/`render()` 中创建新对象（复用字段）
- 运行验证：`flutter analyze lib/` 零警告

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/game/components/jing_lei_enemy.dart` | **全部改动** — 状态机、弧线冲刺、残影、粒子、无敌、冷却 |
| `lib/game/components/enemy.dart` | **不改动** — 基类已支持所需 hook |
| `lib/game/defend_the_tower_game.dart` | **不改动** — 闪避在 enemy.update 内自主运行 |

---

### Task 1: 添加闪避状态机和数据结构

**文件:**
- 修改: `lib/game/components/jing_lei_enemy.dart`

**接口:**
- 消费: 现有 `JingLeiEnemy` 类、`Enemy` 基类
- 产出:
  - `enum _DodgeState { idle, dodging, cooldown }`
  - `_DodgeState _dodgeState = _DodgeState.idle`
  - `double _dodgeTimer = 0` — 冲刺/冷却通用计时器
  - `double _cooldownDuration = 1.5` — 冷却时长常量
  - `double _dodgeDuration = 0.18` — 冲刺时长常量
  - `Vector2 _dodgeStartPos` — 冲刺起点
  - `Vector2 _dodgeControlPoint` — 贝塞尔控制点
  - `Vector2 _dodgeEndPos` — 贝塞尔终点
  - `Vector2 _dodgeDirection` — 冲刺方向向量（用于粒子后向）
  - `class _Afterimage { Vector2 position; double age; }` — 残影数据
  - `List<_Afterimage> _afterimages = []`
  - `class _DodgeParticle { Vector2 pos; Vector2 vel; double life; double size; }` — 粒子数据
  - `List<_DodgeParticle> _particles = []`
  - `Random _rng` — 粒子随机数（复用）
  - `double _scaleBounce = 1.0` — 缩放微弹

- [ ] **Step 1: 在 jing_lei_enemy.dart 顶部添加枚举和内部类**

在文件开头（class JingLeiEnemy 之前）添加：

```dart
/// 闪避状态机
enum _DodgeState { idle, dodging, cooldown }

/// 残影采样数据
class _Afterimage {
  final Vector2 position;
  double age;
  _Afterimage({required this.position, this.age = 0});
}

/// 冲刺粒子
class _DodgeParticle {
  final Vector2 pos;
  final Vector2 vel;
  double life;
  final double size;
  _DodgeParticle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
  });
}
```

- [ ] **Step 2: 在 JingLeiEnemy 类中添加所有新字段**

在现有的 `_speedBonus` 字段下方，替换旧的闪避相关常量（保留 `_dodgeDetectRadius`、`_dodgeThreshold`）：

```dart
  // ─── 闪避状态机 ───
  _DodgeState _dodgeState = _DodgeState.idle;
  double _dodgeTimer = 0;
  static const double _dodgeDuration = 0.18;
  static const double _cooldownDuration = 1.5;

  // ─── 弧线冲刺参数 ───
  Vector2 _dodgeStartPos = Vector2.zero();
  Vector2 _dodgeControlPoint = Vector2.zero();
  Vector2 _dodgeEndPos = Vector2.zero();
  Vector2 _dodgeDirection = Vector2.zero(); // 冲刺方向，用于粒子后向

  // ─── 残影 ───
  final List<_Afterimage> _afterimages = [];
  static const double _afterimageSampleInterval = 0.04;
  static const int _maxAfterimages = 3;
  double _afterimageSampleAccum = 0;

  // ─── 粒子 ───
  final List<_DodgeParticle> _particles = [];
  final Random _rng = Random();
  static const double _particleEmitRate = 30; // 每秒粒子数
  double _particleEmitAccum = 0;

  // ─── 视觉效果 ───
  double _scaleBounce = 1.0;
```

保留原有的：
```dart
  static const double _dodgeDetectRadius = 120.0;
  static const double _dodgeThreshold = 38.0;
```

删除旧字段：
- `static const double _dodgeSpeed = 90.0;` — 不再需要（替换为弧线冲刺）

- [ ] **Step 3: 运行 dart analyze 验证**

```bash
cd D:\新建文件夹\defend_the_tower && dart analyze lib/game/components/jing_lei_enemy.dart
```

预期：新增字段无语法错误。（`_rng` 字段类型 `Random` 需要 `import 'dart:math';` — 已存在）

- [ ] **Step 4: 提交**

```bash
git add lib/game/components/jing_lei_enemy.dart
git commit -m "feat(jinglei): add dodge state machine and data structures"
```

---

### Task 2: 实现弧线冲刺路径计算和 easeOut 插值

**文件:**
- 修改: `lib/game/components/jing_lei_enemy.dart`

**接口:**
- 消费: Task 1 中的 `_DodgeState`、计时器、贝塞尔控制点/终点字段
- 产出: `_startDodge(Vector2 threatDirection)` 方法、`_updateDodging(double dt)` 方法、`_easeOut(double t)` 辅助

- [ ] **Step 1: 添加 easeOut 辅助方法和 _startDodge 方法**

在 `JingLeiEnemy` 类中添加：

```dart
  /// easeOut 缓动函数（先快后慢）
  double _easeOut(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
  }

  /// 启动弧线冲刺
  /// [evadeDir] — 垂直子弹方向的单位向量（已归一化，方向已选远离子弹）
  void _startDodge(Vector2 evadeDir) {
    _dodgeState = _DodgeState.dodging;
    _dodgeTimer = 0;
    _dodgeStartPos = position.clone();
    _dodgeDirection = evadeDir.clone();

    // 控制点：起点 + evadeDir * 60px
    _dodgeControlPoint = _dodgeStartPos + evadeDir * 60.0;

    // 终点：起点 + evadeDir * 80px
    _dodgeEndPos = _dodgeStartPos + evadeDir * 80.0;

    // 清空残影和粒子
    _afterimages.clear();
    _afterimageSampleAccum = 0;
    _particles.clear();
    _particleEmitAccum = 0;

    // 重置缩放
    _scaleBounce = 1.0;
  }

  /// 每帧更新冲刺逻辑
  void _updateDodging(double dt) {
    _dodgeTimer += dt;

    final t = (_dodgeTimer / _dodgeDuration).clamp(0.0, 1.0);
    final easedT = _easeOut(t);

    // 二次贝塞尔曲线插值：B(t) = (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
    final oneMinusT = 1.0 - easedT;
    final a = oneMinusT * oneMinusT;
    final b = 2 * oneMinusT * easedT;
    final c = easedT * easedT;

    position.x = a * _dodgeStartPos.x + b * _dodgeControlPoint.x + c * _dodgeEndPos.x;
    position.y = a * _dodgeStartPos.y + b * _dodgeControlPoint.y + c * _dodgeEndPos.y;

    // 缩放微弹：0→0.1s 膨胀到 1.15，0.1→0.18s 缩回 1.0
    if (t < 0.55) {
      // 0 → 0.1s (~55% of 0.18s): 膨胀
      _scaleBounce = 1.0 + (t / 0.55) * 0.15;
    } else {
      // 0.1 → 0.18s: 缩回
      _scaleBounce = 1.15 - ((t - 0.55) / 0.45) * 0.15;
    }

    // 采样残影
    _afterimageSampleAccum += dt;
    if (_afterimageSampleAccum >= _afterimageSampleInterval &&
        _afterimages.length < _maxAfterimages) {
      _afterimageSampleAccum = 0;
      _afterimages.add(_Afterimage(position: position.clone()));
    }

    // 发射粒子
    _particleEmitAccum += dt;
    while (_particleEmitAccum >= 1.0 / _particleEmitRate) {
      _particleEmitAccum -= 1.0 / _particleEmitRate;
      _emitDodgeParticle();
    }

    // 冲刺结束 → 进入冷却
    if (_dodgeTimer >= _dodgeDuration) {
      _dodgeState = _DodgeState.cooldown;
      _dodgeTimer = 0;
      _scaleBounce = 1.0;
    }
  }
```

- [ ] **Step 2: 修改 _dodgeBullets 方法，接入状态机**

将旧的 `_dodgeBullets` 方法替换为：

```dart
  void _dodgeBullets(double dt) {
    final g = findGame();
    if (g == null) return;

    // 更新残影年龄
    for (final a in _afterimages) {
      a.age += dt;
    }
    _afterimages.removeWhere((a) => a.age > 0.2);

    // 更新粒子
    for (final p in _particles) {
      p.pos.add(p.vel * dt);
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    // 冷却中：计时
    if (_dodgeState == _DodgeState.cooldown) {
      _dodgeTimer += dt;
      if (_dodgeTimer >= _cooldownDuration) {
        _dodgeState = _DodgeState.idle;
        _dodgeTimer = 0;
      }
      return;
    }

    // 冲刺中：继续弧线运动
    if (_dodgeState == _DodgeState.dodging) {
      _updateDodging(dt);
      return;
    }

    // IDLE 状态：检测威胁
    Vector2 bestDodgeDir = Vector2.zero();
    double closestMiss = double.infinity;

    for (final c in g.children) {
      Vector2 bulletPos, bulletVel;
      if (c is Projectile) {
        bulletPos = c.position;
        bulletVel = c.velocity;
      } else if (c is DroneBullet) {
        bulletPos = c.position;
        bulletVel = c.direction * c.speed;
      } else {
        continue;
      }

      final toSelf = position - bulletPos;
      final dist = toSelf.length;
      if (dist > _dodgeDetectRadius) continue;

      final dot = toSelf.dot(bulletVel);
      if (dot < 0) continue;

      final t = dot / bulletVel.dot(bulletVel);
      if (t > 0.5) continue;

      final predicted = bulletPos + bulletVel * t;
      final missDist = (position - predicted).length;
      if (missDist > _dodgeThreshold) continue;

      // 垂直于子弹方向的闪避向量
      final perp = Vector2(-bulletVel.y, bulletVel.x)..normalize();
      if (perp.dot(position - predicted) < 0) {
        perp.negate();
      }

      if (missDist < closestMiss) {
        closestMiss = missDist;
        bestDodgeDir = perp;
      }
    }

    if (bestDodgeDir.length2 > 0.0001) {
      _startDodge(bestDodgeDir);
    }
  }
```

- [ ] **Step 3: 删除旧的 emit 粒子方法占位，添加 _emitDodgeParticle**

```dart
  void _emitDodgeParticle() {
    // 后向扇形：冲刺反方向 ±60°
    final baseAngle = atan2(_dodgeDirection.y, _dodgeDirection.x) + 3.14159; // 反向
    final spread = (_rng.nextDouble() - 0.5) * (3.14159 / 3); // ±60°
    final angle = baseAngle + spread;
    final speed = 40.0 + _rng.nextDouble() * 80.0; // 40–120 px/s
    final life = 0.2 + _rng.nextDouble() * 0.1; // 0.2–0.3s
    final size = 2.0 + _rng.nextDouble() * 2.0; // 2–4px

    _particles.add(_DodgeParticle(
      pos: position.clone(),
      vel: Vector2(cos(angle), sin(angle)) * speed,
      life: life,
      size: size,
    ));
  }
```

- [ ] **Step 4: 更新 import**

确保文件顶部已导入 `dart:math`（`atan2`、`cos`、`sin` 需要）— 已存在。

- [ ] **Step 5: 运行 dart analyze 验证**

```bash
cd D:\新建文件夹\defend_the_tower && dart analyze lib/game/components/jing_lei_enemy.dart
```

预期：零警告零错误。

- [ ] **Step 6: 提交**

```bash
git add lib/game/components/jing_lei_enemy.dart
git commit -m "feat(jinglei): implement arc dash with bezier curve and easeOut interpolation"
```

---

### Task 3: 实现残影和粒子渲染

**文件:**
- 修改: `lib/game/components/jing_lei_enemy.dart`

**接口:**
- 消费: Task 1 的 `_Afterimage`、`_DodgeParticle`，Task 2 的 `_scaleBounce`
- 产出: 覆写 `render()` 方法绘制残影和粒子

- [ ] **Step 1: 覆写 render 方法，添加残影渲染**

在 `JingLeiEnemy` 类中，在现有 `onLoad` 后面添加：

```dart
  @override
  void render(Canvas canvas) {
    // ── 绘制粒子（在本体之前，粒子在本体下方）──
    _renderParticles(canvas);

    // ── 绘制残影（在本体之前，残影在本体下方）──
    _renderAfterimages(canvas);

    // ── 绘制本体（带冲刺缩放和紫色覆盖）──
    canvas.save();
    if (_scaleBounce != 1.0) {
      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(_scaleBounce, _scaleBounce);
      canvas.translate(-size.x / 2, -size.y / 2);
    }
    super.render(canvas);
    canvas.restore();

    // ── 冲刺紫色覆盖 ──
    if (_dodgeState == _DodgeState.dodging) {
      final overlay = Paint()
        ..color = Color.fromRGBO(160, 120, 255, 0.25);
      canvas.drawRect(size.toRect(), overlay);
    }
  }
```

- [ ] **Step 2: 添加 _renderAfterimages 方法**

```dart
  void _renderAfterimages(Canvas canvas) {
    if (_afterimages.isEmpty || frames == null || frames!.isEmpty) return;
    final sprite = frames![currentFrame];

    for (final a in _afterimages) {
      // 透明度曲线：0→0.05s 淡入到 0.35，0.05→0.2s 淡出到 0
      double alpha;
      if (a.age < 0.05) {
        alpha = (a.age / 0.05) * 0.35;
      } else {
        alpha = 0.35 * (1.0 - (a.age - 0.05) / 0.15);
      }
      alpha = alpha.clamp(0.0, 0.35);
      if (alpha <= 0.01) continue;

      // 使用 saveLayer 做淡紫色混合
      canvas.saveLayer(size.toRect(), Paint());
      sprite.render(
        canvas,
        size: size,
        overridePaint: Paint()
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(180, 140, 255, alpha),
            BlendMode.srcATop,
          ),
      );
      canvas.restore();
    }
  }
```

- [ ] **Step 3: 添加 _renderParticles 方法**

```dart
  /// 粒子画笔（复用，避免每帧创建）
  final Paint _particlePaint = Paint()
    ..style = PaintingStyle.fill;

  void _renderParticles(Canvas canvas) {
    if (_particles.isEmpty) return;

    for (final p in _particles) {
      final alpha = (p.life / 0.3).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      // 柔光粒子：中心淡紫 → 边缘透明
      final r = p.size / 2;
      final rect = Rect.fromCenter(
        center: Offset(p.pos.x, p.pos.y),
        width: p.size,
        height: p.size,
      );

      _particlePaint
        ..shader = Gradient.radial(
          Offset(p.pos.x, p.pos.y),
          r,
          [
            Color.fromRGBO(200, 160, 255, alpha),
            Color.fromRGBO(140, 100, 220, alpha * 0.3),
            Color.fromRGBO(100, 60, 200, 0),
          ],
          [0.0, 0.3, 1.0],
        );

      canvas.drawOval(rect, _particlePaint);
    }
  }
```

**注意**: `Gradient.radial` 使用全局坐标（`Offset(p.pos.x, p.pos.y)`），因为 canvas 尚未 translate 到组件原点。`super.render(canvas)` 由 Flame 处理 translate。

- [ ] **Step 4: 修复残影渲染坐标**

残影的位置 `a.position` 是世界坐标，但 `sprite.render()` 在组件 render 上下文中 draw 到 (0,0) 位置。需要在绘制残影时手动 translate。修正 `_renderAfterimages`：

```dart
  void _renderAfterimages(Canvas canvas) {
    if (_afterimages.isEmpty || frames == null || frames!.isEmpty) return;
    final sprite = frames![currentFrame];

    for (final a in _afterimages) {
      double alpha;
      if (a.age < 0.05) {
        alpha = (a.age / 0.05) * 0.35;
      } else {
        alpha = 0.35 * (1.0 - (a.age - 0.05) / 0.15);
      }
      alpha = alpha.clamp(0.0, 0.35);
      if (alpha <= 0.01) continue;

      // 残影绘制在组件的世界位置 → 需要计算相对偏移
      final localPos = a.position - position; // 转为相对于当前组件位置的偏移

      canvas.save();
      canvas.translate(localPos.x, localPos.y);
      canvas.saveLayer(size.toRect(), Paint());
      sprite.render(
        canvas,
        size: size,
        overridePaint: Paint()
          ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(180, 140, 255, alpha),
            BlendMode.srcATop,
          ),
      );
      canvas.restore();
      canvas.restore();
    }
  }
```

同样，粒子位置 `p.pos` 也是世界坐标，需要调整：

```dart
  void _renderParticles(Canvas canvas) {
    if (_particles.isEmpty) return;

    for (final p in _particles) {
      final alpha = (p.life / 0.3).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final r = p.size / 2;
      // 转为相对于组件原点的 local 坐标
      final localPos = p.pos - position;
      final localOffset = Offset(localPos.x, localPos.y);

      _particlePaint
        ..shader = Gradient.radial(
          localOffset,
          r,
          [
            Color.fromRGBO(200, 160, 255, alpha),
            Color.fromRGBO(140, 100, 220, alpha * 0.3),
            Color.fromRGBO(100, 60, 200, 0),
          ],
          [0.0, 0.3, 1.0],
        );

      canvas.drawCircle(localOffset, r, _particlePaint);
    }
  }
```

- [ ] **Step 5: 运行 dart analyze 验证**

```bash
cd D:\新建文件夹\defend_the_tower && dart analyze lib/game/components/jing_lei_enemy.dart
```

预期：零警告零错误。

- [ ] **Step 6: 提交**

```bash
git add lib/game/components/jing_lei_enemy.dart
git commit -m "feat(jinglei): add afterimage and particle rendering"
```

---

### Task 4: 实现冲刺期间无敌

**文件:**
- 修改: `lib/game/components/jing_lei_enemy.dart`

**接口:**
- 消费: `_dodgeState` 状态机字段
- 产出: 覆写 `takeDamage`，冲刺中直接返回

- [ ] **Step 1: 修改 takeDamage 覆写**

在 `JingLeiEnemy` 类中，将现有的 `takeDamage` 方法：

```dart
  @override
  void takeDamage(double damage) {
    if (isFinalForm) damage *= 0.5;
    super.takeDamage(damage);
  }
```

改为：

```dart
  @override
  void takeDamage(double damage) {
    // 冲刺期间无敌
    if (_dodgeState == _DodgeState.dodging) return;
    // 最终形态 50% 减伤
    if (isFinalForm) damage *= 0.5;
    super.takeDamage(damage);
  }
```

- [ ] **Step 2: 确认 update 中旧闪避逻辑已被替换**

检查 `update` 方法，确保：

```dart
  @override
  void update(double dt) {
    super.update(dt);
    if (!isFinalForm) {
      _chainTimer += dt;
    } else {
      firstChild<Slowed>()?.removeFromParent();
    }
    // 冻结/恐惧时不闪避（但允许完成正在进行的冲刺）
    if (!isFrozen && !isFeared) {
      _dodgeBullets(dt);
    } else if (_dodgeState == _DodgeState.dodging) {
      // 被冻结/恐惧时完成当前冲刺
      _updateDodging(dt);
    }
  }
```

- [ ] **Step 3: 运行 dart analyze + 检查**

```bash
cd D:\新建文件夹\defend_the_tower && dart analyze lib/
```

预期：零警告零错误。

- [ ] **Step 4: 提交**

```bash
git add lib/game/components/jing_lei_enemy.dart
git commit -m "feat(jinglei): add invincibility during dodge dash"
```

---

### Task 5: 清理和最终调整

**文件:**
- 修改: `lib/game/components/jing_lei_enemy.dart`

**接口:**
- 消费: 所有前序任务的产出
- 产出: 干净的最终文件，无冗余代码、无调试残留

- [ ] **Step 1: 删除旧的闪避相关代码**

确认以下内容已被删除或替换：
- `static const double _dodgeSpeed = 90.0;` — 已删除（Task 1）
- 旧 `_dodgeBullets` 中的横向位移逻辑 — 已替换（Task 2）
- 所有 💨 dodge 指示器逻辑 — 已在前次会话移除

- [ ] **Step 2: 确保 _afterimages 在 update 中年龄更新**

在 `_dodgeBullets` 开头已经处理残影年龄（Task 2 Step 2）。确认 `_updateDodging` 中不重复处理残影年龄 — 两个路径都需更新。修正方案：

将残影和粒子年龄更新移到 `update` 方法开头（在 `_dodgeBullets(dt)` 之前）：

```dart
  @override
  void update(double dt) {
    super.update(dt);
    if (!isFinalForm) {
      _chainTimer += dt;
    } else {
      firstChild<Slowed>()?.removeFromParent();
    }

    // 始终更新残影年龄和粒子（无论状态）
    for (final a in _afterimages) {
      a.age += dt;
    }
    _afterimages.removeWhere((a) => a.age > 0.2);
    for (final p in _particles) {
      p.pos.add(p.vel * dt);
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    if (!isFrozen && !isFeared) {
      _dodgeBullets(dt);
    } else if (_dodgeState == _DodgeState.dodging) {
      _updateDodging(dt);
    }
  }
```

同时从 `_dodgeBullets` 开头删除那两段残影/粒子更新（避免重复）。

- [ ] **Step 3: 添加 export 导入确保 image 可用**

resolved: `dart:ui` 中的 `Color`、`ColorFilter`、`BlendMode`、`Gradient`、`Offset`、`Canvas`、`Paint`、`Rect`、`PaintingStyle` 需要在文件顶部导入。当前已有 `import 'dart:math';`，需要确认 `dart:ui` 导入。

查看现有导入：
```dart
import 'dart:math';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
```

`package:flame/components.dart` 会 re-export `dart:ui` 的核心类型（`Canvas`、`Paint`、`Color` 等），无需显式导入。

- [ ] **Step 4: 最终 dart analyze**

```bash
cd D:\新建文件夹\defend_the_tower && dart analyze lib/
```

预期：零错误零警告。

- [ ] **Step 5: 提交**

```bash
git add lib/game/components/jing_lei_enemy.dart
git commit -m "chore(jinglei): cleanup old dodge code, finalize new dodge system"
```

---

### Task 6: 运行游戏，验证视觉效果

**文件:**
- 无代码改动

- [ ] **Step 1: 运行游戏**

```bash
cd D:\新建文件夹\defend_the_tower && flutter run
```

- [ ] **Step 2: 验证点**

1. 第 1 波惊雷出现后，炮塔子弹射向惊雷时，观察是否触发弧线冲刺
2. 冲刺是否有淡紫色残影和粒子拖尾
3. 冲刺期间是否有紫色覆盖和缩放微弹
4. 冷却 1.5 秒期间，子弹命中是否正常扣血（不无敌）
5. 冷却结束后是否能再次触发冲刺
6. 冻结/恐惧时是否不触发新闪避
7. `dart analyze` 零警告

- [ ] **Step 3: 如有视觉问题，微调参数后提交最终版本**

调整项参考：
- 冲刺太快/太慢 → 改 `_dodgeDuration`
- 残影太多/太少 → 改 `_afterimageSampleInterval` 或 `_maxAfterimages`
- 粒子太密/太稀 → 改 `_particleEmitRate`
- 冲刺距离太远/太近 → 改控制点 60px 和终点 80px
- 紫色太深/太淡 → 改 RGB 和 alpha

- [ ] **Step 4: 最终提交**

```bash
git add lib/game/components/jing_lei_enemy.dart
git commit -m "feat(jinglei): final arc dash dodge with afterimages and particles"
```
