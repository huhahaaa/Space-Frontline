# 塔防+肉鸽游戏 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使用 Flutter + Flame 构建竖屏塔防游戏，含半自动射击、技能系统、波次系统和肉鸽选卡

**Architecture:** FlameGame = World(游戏实体) + Overlays(UI层)。使用 PositionComponent 管理游戏对象，通过 update 循环驱动游戏逻辑，碰撞检测使用简单的矩形重叠

**Tech Stack:** Flutter 3.41.4 / Dart 3.11.1 / Flame 1.x

---

## 教学前置说明
- 每个 Step 解释"这段代码是做什么的"
- 新手友好：解释 Dart 关键字、Flame 概念
- 每完成一个 Task 都可以运行看到效果

---

### Task 1: 搭建项目 + 显示游戏画布

**目标：** 添加 Flame 依赖，创建游戏主类，看到蓝色游戏画布

**文件：**
- 修改: `pubspec.yaml` — 添加 flame 依赖
- 修改: `lib/main.dart` — 替换为游戏入口
- 创建: `lib/game/defend_the_tower_game.dart` — FlameGame 主类

- [ ] **Step 1: 添加 Flame 依赖**

编辑 `pubspec.yaml`，在 dependencies 下添加 flame：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.26.1    # 新增这一行
```

**解释：** `flame` 是 Flutter 的游戏引擎，提供游戏循环、组件系统、碰撞检测等功能

- [ ] **Step 2: 安装依赖**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter pub get
```

- [ ] **Step 3: 创建游戏主类文件**

创建 `lib/game/defend_the_tower_game.dart`：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// 游戏主类 - 整个游戏的核心
/// FlameGame 是 Flame 提供的基类，管理游戏循环和组件树
class DefendTheTowerGame extends FlameGame {
  DefendTheTowerGame() {
    // 设置游戏画布背景色为深蓝灰
    backgroundColor = const Color(0xFF1A1A2E);
  }

  @override
  Future<void> onLoad() async {
    // onLoad 在游戏启动时调用一次，常用于加载资源
    // 目前什么都不做，后续添加初始化逻辑
  }

  @override
  void update(double dt) {
    // update 每帧调用一次，dt 是距离上一帧的时间（秒）
    // super.update(dt) 会更新所有子组件
    super.update(dt);
  }
}
```

**解释：**
- `FlameGame` — Flame 的核心类，管理游戏循环（update 每帧执行）和组件系统
- `backgroundColor` — 游戏画布的背景颜色
- `onLoad()` — 异步初始化方法，游戏启动时调用
- `update(double dt)` — 每帧 60 次左右，`dt` 是帧间隔时间
- `super.update(dt)` — 必须调用，让 Flame 更新所有添加到游戏的组件

- [ ] **Step 4: 修改 main.dart 为游戏入口**

替换 `lib/main.dart` 全部内容：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/defend_the_tower_game.dart';

void main() {
  // 1. 创建游戏实例
  final game = DefendTheTowerGame();

  // 2. 用 GameWidget 把游戏嵌入 Flutter 界面
  // GameWidget 是 Flame 提供的 Widget，负责渲染游戏
  runApp(
    MaterialApp(
      home: Scaffold(
        body: GameWidget(game: game),
      ),
    ),
  );
}
```

**解释：**
- `GameWidget(game: game)` — Flame 提供的 Widget，把游戏对象变成屏幕上可见的东西
- 它自动处理渲染、手势、游戏循环

- [ ] **Step 5: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：** 看到一个深蓝灰色的全屏窗口（游戏画布）

**验证：** 窗口标题 "defend_the_tower"，背景为深蓝灰色 (#1A1A2E)

---

### Task 2: 放置防御塔

**目标：** 在屏幕底部中央显示一个防御塔

**文件：**
- 创建: `lib/game/components/tower.dart`
- 修改: `lib/game/defend_the_tower_game.dart` — 添加塔到世界

- [ ] **Step 1: 创建 Tower 组件**

创建 `lib/game/components/tower.dart`：

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 防御塔组件 - 玩家的防御单位
/// PositionComponent 是 Flame 的基类，带 x,y 坐标和宽高
class Tower extends PositionComponent {
  Tower({required this.onFireBullet})
      : super(
          size: Vector2(50, 50),   // 宽50, 高50（虚拟像素）
          anchor: Anchor.center,    // 坐标 (x,y) 指向组件中心
        );

  // 回调函数：塔发射子弹时调用，参数是方向角度
  final void Function(double angle) onFireBullet;

  @override
  Future<void> onLoad() async {
    // position 在添加到游戏后由游戏设置
    // 这里暂时为空，后续可以加载图片
  }

  @override
  void render(Canvas canvas) {
    // 用 Canvas 绘制塔的外观
    // 目前用基础形状代替（不用图片资源）

    // 画塔身（矩形）
    canvas.drawRect(
      Rect.fromLTWH(-20, -20, 40, 40),   // 以锚点为中心
      Paint()..color = const Color(0xFF4A90D9),  // 蓝色
    );

    // 画炮口指示器（圆形）
    canvas.drawCircle(
      const Offset(0, -8),                // 稍微偏上
      6,
      Paint()..color = const Color(0xFFFF6B6B),  // 红色
    );
  }

  /// 向指定角度发射子弹
  void shoot(double angle) {
    onFireBullet(angle);
  }
}
```

**解释：**
- `PositionComponent` — Flame 的基础组件，有 x,y 坐标和 width/height
- `size: Vector2(50, 50)` — 组件的宽和高（独立于屏幕像素的游戏单位）
- `anchor: Anchor.center` — 坐标定位方式，center 表示坐标指向组件中心
- `render(Canvas canvas)` — Flutter 底层绘制 API，每帧调用
- 目前用矩形 + 圆形代替塔的外观，后面可以替换为图片

- [ ] **Step 2: 把塔添加到游戏中**

修改 `lib/game/defend_the_tower_game.dart`：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'components/tower.dart';   // 新增导入

class DefendTheTowerGame extends FlameGame {
  DefendTheTowerGame() {
    backgroundColor = const Color(0xFF1A1A2E);
  }

  @override
  Future<void> onLoad() async {
    // 在屏幕底部中央放置防御塔
    // size 是画布大小（在添加到 Widget 后才会被设置）
    // onLoad 时 size 已经可用（因为 GameWidget 已经 attach）
  }

  @override
  void onMount() {
    super.onMount();
    // onMount 在 GameWidget 挂载后调用，此时 size 已知
    _spawnTower();
  }

  void _spawnTower() {
    final tower = Tower(
      onFireBullet: (angle) {
        // TODO: 后续实现子弹发射
      },
    );

    // 设置塔的位置：屏幕底部中央
    tower.position = Vector2(size.x / 2, size.y - 60);

    // 将塔添加到游戏世界
    add(tower);
  }

  @override
  void update(double dt) {
    super.update(dt);
  }
}
```

**解释：**
- `onMount()` — 组件挂载（显示到屏幕）时调用，此时 `size` 属性可用
- `size.x` — 画布宽度，`size.y` — 画布高度
- `size.y - 60` — 距离底部 60 像素
- `add(tower)` — 把组件添加到游戏世界，Flame 会自动管理它的 update 和 render

- [ ] **Step 3: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：** 深蓝灰背景，底部中央有一个蓝色方块 + 红色圆点（炮口）

---

### Task 3: 生成敌人

**目标：** 敌人从顶部随机位置出现，向下匀速移动

**文件：**
- 创建: `lib/game/components/enemy.dart`
- 修改: `lib/game/defend_the_tower_game.dart` — 添加敌人生成逻辑

- [ ] **Step 1: 创建 Enemy 组件**

创建 `lib/game/components/enemy.dart`：

```dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 敌人组件 - 从顶部向下移动
class Enemy extends PositionComponent {
  Enemy()
      : super(
          size: Vector2(40, 40),
          anchor: Anchor.center,
        );

  // 移动速度（每秒移动的像素数）
  static const double speed = 80.0;

  // 血量
  double hp = 3.0;

  // 最大血量
  double get maxHp => 3.0;

  // 是否已死亡
  bool get isDead => hp <= 0;

  @override
  Future<void> onLoad() async {}

  @override
  void update(double dt) {
    super.update(dt);
    // 每帧向下移动 speed * dt 像素
    // dt 是帧间隔，确保不同帧率下速度一致
    position.y += speed * dt;
  }

  @override
  void render(Canvas canvas) {
    // 画敌人身体（红色方块）
    canvas.drawRect(
      Rect.fromLTWH(-15, -15, 30, 30),
      Paint()..color = const Color(0xFFFF4444),
    );

    // 画血条背景（灰色）
    canvas.drawRect(
      Rect.fromLTWH(-15, -22, 30, 4),
      Paint()..color = const Color(0xFF666666),
    );

    // 画血条（绿色）
    final hpPercent = hp / maxHp;
    canvas.drawRect(
      Rect.fromLTWH(-15, -22, 30 * hpPercent, 4),
      Paint()..color = const Color(0xFF44FF44),
    );
  }

  /// 受到伤害
  void takeDamage(double damage) {
    hp -= damage;
  }
}
```

**解释：**
- `speed = 80.0` — 敌人移动速度，单位是游戏像素/秒
- `position.y += speed * dt` — 乘以 dt 确保移动与帧率无关
- `hp` — 敌人血量，被子弹击中时减少
- `takeDamage()` — 外部调用，减少血量
- 血条显示在敌人上方

- [ ] **Step 2: 在游戏中添加敌人生成逻辑**

修改 `lib/game/defend_the_tower_game.dart`：

```dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'components/tower.dart';
import 'components/enemy.dart';   // 新增导入

class DefendTheTowerGame extends FlameGame {
  DefendTheTowerGame() {
    backgroundColor = const Color(0xFF1A1A2E);
  }

  // 敌人生成计时器
  double _enemySpawnTimer = 0;
  static const double enemySpawnInterval = 1.5; // 每1.5秒生成一个敌人

  @override
  void onMount() {
    super.onMount();
    _spawnTower();
  }

  void _spawnTower() {
    final tower = Tower(
      onFireBullet: (angle) {
        // TODO
      },
    );
    tower.position = Vector2(size.x / 2, size.y - 60);
    add(tower);
  }

  void _spawnEnemy() {
    final rng = Random();
    final enemy = Enemy();

    // 在屏幕顶部随机 x 位置生成，y 从屏幕上方外面开始
    // 确保敌人在屏幕范围内（留出边距）
    final marginX = 40.0;
    enemy.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -20.0,  // 从屏幕上方外面出生
    );

    add(enemy);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 每 enemySpawnInterval 秒生成一个敌人
    _enemySpawnTimer += dt;
    if (_enemySpawnTimer >= enemySpawnInterval) {
      _enemySpawnTimer = 0;
      _spawnEnemy();
    }
  }
}
```

**解释：**
- `_enemySpawnTimer` — 计时器，累计时间
- `enemySpawnInterval = 1.5` — 每 1.5 秒生成一个敌人
- `Random().nextDouble()` — 生成 0.0 ~ 1.0 之间的随机数，用于随机 x 位置
- 敌人生成在 y=-20 处（屏幕上方外面），向下移动进入屏幕

- [ ] **Step 3: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：** 塔在底部，红方块敌人从顶部随机位置不断向下掉落，带着绿色血条

---

### Task 4: 拖拽瞄准 + 发射子弹

**目标：** 玩家按住拖拽显示瞄准线，松手发射子弹，子弹碰撞消灭敌人

**文件：**
- 创建: `lib/game/components/projectile.dart`
- 修改: `lib/game/components/tower.dart` — 添加拖拽检测
- 修改: `lib/game/defend_the_tower_game.dart` — 添加子弹发射和碰撞检测

- [ ] **Step 1: 创建 Projectile 组件**

创建 `lib/game/components/projectile.dart`：

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 子弹组件 - 沿指定方向飞行
class Projectile extends PositionComponent {
  Projectile({
    required this.direction,  // 飞行方向（归一化向量）
    this.damage = 1.0,
    this.speed = 400.0,
  }) : super(
          size: Vector2(8, 8),
          anchor: Anchor.center,
        );

  final Vector2 direction;  // 方向向量（长度为1）
  final double damage;       // 伤害值
  final double speed;        // 飞行速度

  // 子弹存活时间（秒），防止飞出屏幕的子弹永久存在
  double _lifetime = 0;
  static const double maxLifetime = 3.0;

  @override
  void update(double dt) {
    super.update(dt);

    // 沿方向移动
    position += direction * speed * dt;

    // 超时自动销毁
    _lifetime += dt;
    if (_lifetime > maxLifetime) {
      removeFromParent();  // 从游戏中移除
    }
  }

  @override
  void render(Canvas canvas) {
    // 画黄色圆形子弹
    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()..color = const Color(0xFFFFD700),
    );
  }
}
```

**解释：**
- `direction` — 归一化向量（长度为1），表示飞行方向
- `position += direction * speed * dt` — 沿方向匀速移动
- `_lifetime` — 存活时间，超时自动删除（性能优化）
- `removeFromParent()` — 从游戏世界移除自己

- [ ] **Step 2: 修改 Tower — 添加拖拽瞄准**

替换 `lib/game/components/tower.dart` 全部内容：

```dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class Tower extends PositionComponent with DragCallbacks {
  Tower({required this.onFireBullet})
      : super(
          size: Vector2(60, 60),
          anchor: Anchor.center,
        );

  final void Function(double angle) onFireBullet;

  // 是否正在拖拽（瞄准中）
  bool _isDragging = false;

  // 瞄准方向角度（弧度）
  double _aimAngle = -pi / 2;  // 默认向上

  @override
  Future<void> onLoad() async {}

  // 拖拽开始
  @override
  void onDragStart(DragStartEvent event) {
    _isDragging = true;
  }

  // 拖拽更新（计算瞄准方向）
  @override
  void onDragUpdate(DragUpdateEvent event) {
    // 瞄准方向：从塔的位置指向拖拽手指位置的反方向
    // 拖拽位置在本地坐标系中
    final localPos = event.localPosition;
    _aimAngle = atan2(localPos.y, localPos.x) + pi; // 反向（远离手指）
  }

  // 拖拽结束（松手）：发射子弹
  @override
  void onDragEnd(DragEndEvent event) {
    _isDragging = false;
    onFireBullet(_aimAngle);
  }

  @override
  void render(Canvas canvas) {
    // 画塔身
    canvas.drawRect(
      Rect.fromLTWH(-22, -22, 44, 44),
      Paint()..color = const Color(0xFF4A90D9),
    );

    // 画炮口指示器（指向瞄准方向）
    canvas.save();
    canvas.translate(0, 0);
    canvas.rotate(_aimAngle);   // 旋转到瞄准方向
    canvas.drawRect(
      Rect.fromLTWH(0, -4, 18, 8),  // 从中心向右的炮管
      Paint()..color = const Color(0xFFFF6B6B),
    );
    canvas.restore();

    // 瞄准时画瞄准线
    if (_isDragging) {
      final lineEnd = Vector2(cos(_aimAngle), sin(_aimAngle)) * 100;
      canvas.drawLine(
        Offset.zero,
        Offset(lineEnd.x, lineEnd.y),
        Paint()
          ..color = const Color(0x88FFD700)
          ..strokeWidth = 2,
      );
    }
  }
}
```

**解释：**
- `with DragCallbacks` — 混入 Flame 的拖拽事件支持
- `onDragStart` — 手指按下时触发
- `onDragUpdate` — 手指移动时触发，计算瞄准方向
  - `atan2(y, x)` 计算从塔指向手指的角度，+π 得到反向（子弹飞离手指方向）
- `onDragEnd` — 松手时触发，发射子弹
- `canvas.rotate(_aimAngle)` — 旋转画布，让炮管指向瞄准方向
- 瞄准线：拖拽时显示黄色虚线指示方向

- [ ] **Step 3: 修改游戏主类 — 添加子弹发射和碰撞检测**

替换 `lib/game/defend_the_tower_game.dart` 全部内容：

```dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'components/tower.dart';
import 'components/enemy.dart';
import 'components/projectile.dart';

class DefendTheTowerGame extends FlameGame {
  DefendTheTowerGame() {
    backgroundColor = const Color(0xFF1A1A2E);
  }

  double _enemySpawnTimer = 0;
  static const double enemySpawnInterval = 1.5;

  @override
  void onMount() {
    super.onMount();
    _spawnTower();
  }

  void _spawnTower() {
    final tower = Tower(
      onFireBullet: (angle) {
        _fireBullet(angle);
      },
    );
    tower.position = Vector2(size.x / 2, size.y - 60);
    add(tower);
  }

  /// 发射子弹
  void _fireBullet(double angle) {
    // 计算方向向量（长度为1）
    final direction = Vector2(cos(angle), sin(angle));

    final bullet = Projectile(direction: direction);

    // 子弹从塔的位置出发
    bullet.position = Vector2(size.x / 2, size.y - 60);

    add(bullet);
  }

  void _spawnEnemy() {
    final rng = Random();
    final enemy = Enemy();
    final marginX = 40.0;
    enemy.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -20.0,
    );
    add(enemy);
  }

  /// 碰撞检测：检查所有子弹和所有敌人
  void _checkCollisions() {
    // 获取所有敌人和子弹
    final enemies = children.whereType<Enemy>().toList();
    final bullets = children.whereType<Projectile>().toList();

    for (final bullet in bullets) {
      for (final enemy in enemies) {
        // 简单的矩形碰撞检测
        if (bullet.toRect().overlaps(enemy.toRect())) {
          // 敌人受伤
          enemy.takeDamage(bullet.damage);

          // 命中后移除子弹
          bullet.removeFromParent();

          // 如果敌人死亡，移除敌人
          if (enemy.isDead) {
            enemy.removeFromParent();
          }

          // 一颗子弹只命中一个敌人
          break;
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 敌人生成
    _enemySpawnTimer += dt;
    if (_enemySpawnTimer >= enemySpawnInterval) {
      _enemySpawnTimer = 0;
      _spawnEnemy();
    }

    // 碰撞检测
    _checkCollisions();
  }
}
```

**解释：**
- `children.whereType<Enemy>()` — 从游戏组件树中筛选所有 Enemy 实例
- `bullet.toRect()` — 获取子弹的矩形边界
- `.overlaps()` — 检查两个矩形是否重叠（内置碰撞检测）
- `break` — 一颗子弹命中一个敌人后跳出循环（不过穿）
- `removeFromParent()` — 从游戏世界移除

- [ ] **Step 4: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：** 
- 按住塔拖拽：出现黄色瞄准线，炮管跟随旋转
- 松手：黄色子弹沿瞄准方向飞出
- 子弹命中红方块敌人：血条减少，命中3次后敌人消失

---

### Task 5: 技能系统 + 底部按钮

**目标：** 底部显示3个技能按钮，点击释放特殊技能

**文件：**
- 创建: `lib/game/managers/skill_manager.dart`
- 创建: `lib/game/overlays/skill_bar.dart`
- 修改: `lib/game/defend_the_tower_game.dart` — 集成技能
- 修改: `lib/main.dart` — 注册覆盖层

- [ ] **Step 1: 创建技能管理器**

创建 `lib/game/managers/skill_manager.dart`：

```dart
/// 技能数据定义
class SkillData {
  final String name;
  final String icon;      // emoji图标
  final double cooldown;  // 冷却时间（秒）
  final double damage;
  final int level;
  final String type;      // 'fireball', 'freeze', 'lightning'

  const SkillData({
    required this.name,
    required this.icon,
    required this.cooldown,
    required this.damage,
    this.level = 1,
    required this.type,
  });

  /// 升级后返回新的 SkillData
  SkillData levelUp() {
    return SkillData(
      name: name,
      icon: icon,
      cooldown: cooldown * 0.85,  // 升级减冷却
      damage: damage * 1.5,        // 升级加伤害
      level: level + 1,
      type: type,
    );
  }

  /// 冷却剩余百分比 (0-1)
  double cooldownPercent(double elapsed) {
    if (cooldown <= 0) return 1.0;
    return (elapsed / cooldown).clamp(0.0, 1.0);
  }
}

/// 技能管理器 — 管理3个技能的冷却和升级
class SkillManager {
  // 3个初始技能
  final List<SkillData> skills = [
    const SkillData(name: '火球术', icon: '🔥', cooldown: 3.0, damage: 3.0, type: 'fireball'),
    const SkillData(name: '冰冻术', icon: '❄️', cooldown: 5.0, damage: 1.0, type: 'freeze'),
    const SkillData(name: '闪电链', icon: '⚡', cooldown: 4.0, damage: 2.0, type: 'lightning'),
  ];

  // 每个技能的冷却计时器（记录已冷却的时间）
  final List<double> _cooldownTimers = [99, 99, 99]; // 初始设为就绪

  /// 尝试使用技能，返回是否可以释放
  bool useSkill(int index) {
    if (index < 0 || index >= skills.length) return false;
    if (_cooldownTimers[index] < skills[index].cooldown) return false;

    _cooldownTimers[index] = 0; // 重置冷却
    return true;
  }

  /// 每帧更新冷却计时器
  void update(double dt) {
    for (int i = 0; i < _cooldownTimers.length; i++) {
      _cooldownTimers[i] += dt;
    }
  }

  /// 获取技能冷却进度 (0-1, 1=就绪)
  double getCooldownPercent(int index) {
    if (index < 0 || index >= skills.length) return 0;
    return skills[index].cooldownPercent(_cooldownTimers[index]);
  }

  /// 升级指定技能
  void upgradeSkill(int index) {
    if (index < 0 || index >= skills.length) return;
    skills[index] = skills[index].levelUp();
  }

  /// 获取所有技能数据
  SkillData getSkill(int index) => skills[index];
}
```

**解释：**
- `SkillData` — 不可变数据类，描述一个技能
- `levelUp()` — 返回升级后的新 SkillData（原对象不变）
- `_cooldownTimers` — 记录每个技能从上次释放到现在的时间
- `useSkill()` — 检查冷却→重置冷却→返回是否成功
- `getCooldownPercent()` — 用于 UI 显示冷却进度

- [ ] **Step 2: 创建底部技能栏 Overlay**

创建 `lib/game/overlays/skill_bar.dart`：

```dart
import 'package:flutter/material.dart';
import '../managers/skill_manager.dart';

/// 底部技能栏 — 覆盖在游戏画布上方的 Flutter Widget
/// 使用 Overlay 而不是 Flame 组件，可以方便使用 Flutter Widget
class SkillBar extends StatelessWidget {
  final SkillManager skillManager;
  final void Function(int index) onSkillUse;

  const SkillBar({
    super.key,
    required this.skillManager,
    required this.onSkillUse,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final skill = skillManager.getSkill(index);
              final cooldown = skillManager.getCooldownPercent(index);
              final isReady = cooldown >= 1.0;

              return GestureDetector(
                onTap: isReady
                    ? () => onSkillUse(index)
                    : null, // 冷却中不可点击
                child: Container(
                  width: 80,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isReady
                        ? Colors.blueGrey.withAlpha(150)
                        : Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isReady ? Colors.yellowAccent : Colors.grey,
                      width: isReady ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 技能图标和名称
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(skill.icon, style: const TextStyle(fontSize: 24)),
                          Text(
                            skill.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: isReady ? Colors.white : Colors.grey,
                            ),
                          ),
                          Text(
                            'Lv.${skill.level}',
                            style: const TextStyle(fontSize: 8, color: Colors.amber),
                          ),
                        ],
                      ),
                      // 冷却遮罩（从底部向上）
                      if (!isReady)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 70 * (1 - cooldown),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
```

**解释：**
- `Overlay` — Flame 概念，Flutter Widget 层覆盖在游戏上
- `SafeArea` — 避免被手机刘海/底部指示条遮挡
- `GestureDetector` — 检测点击，冷却中不响应
- 冷却遮罩：黑色半透明从底部向上收缩，显示冷却进度
- `isReady` — 冷却就绪时边框变金色

- [ ] **Step 3: 更新游戏主类 — 集成技能**

修改 `lib/game/defend_the_tower_game.dart`，关键改动：

```dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'components/tower.dart';
import 'components/enemy.dart';
import 'components/projectile.dart';
import 'managers/skill_manager.dart';

class DefendTheTowerGame extends FlameGame {
  DefendTheTowerGame() {
    backgroundColor = const Color(0xFF1A1A2E);
  }

  double _enemySpawnTimer = 0;
  static const double enemySpawnInterval = 1.5;

  // 技能管理器
  final SkillManager skillManager = SkillManager();

  // 存储敌人列表的引用（用于技能效果）
  List<Enemy> get enemies => children.whereType<Enemy>().toList();

  // 获取塔的位置（用于技能释放）
  Vector2 get towerPosition => Vector2(size.x / 2, size.y - 60);

  @override
  void onMount() {
    super.onMount();
    _spawnTower();
  }

  void _spawnTower() {
    final tower = Tower(
      onFireBullet: (angle) {
        _fireBullet(angle);
      },
    );
    tower.position = towerPosition;
    add(tower);
  }

  void _fireBullet(double angle) {
    final direction = Vector2(cos(angle), sin(angle));
    final bullet = Projectile(direction: direction);
    bullet.position = towerPosition;
    add(bullet);
  }

  void _spawnEnemy() {
    final rng = Random();
    final enemy = Enemy();
    final marginX = 40.0;
    enemy.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -20.0,
    );
    add(enemy);
  }

  /// 使用技能（被 UI 按钮调用）
  void useSkill(int skillIndex) {
    if (!skillManager.useSkill(skillIndex)) return; // 冷却中

    final skill = skillManager.getSkill(skillIndex);

    switch (skill.type) {
      case 'fireball':
        // 火球术：向前方扇形发射多个火球
        _castFireball(skill.damage);
        break;
      case 'freeze':
        // 冰冻术：减速所有敌人
        _castFreeze(skill.damage);
        break;
      case 'lightning':
        // 闪电链：连锁伤害最近3个敌人
        _castLightning(skill.damage);
        break;
    }
  }

  void _castFireball(double damage) {
    // 发射5个火球，扇形分布
    for (int i = -2; i <= 2; i++) {
      final angle = -pi / 2 + i * 0.2; // 扇形角度
      final direction = Vector2(cos(angle), sin(angle));
      final bullet = Projectile(
        direction: direction,
        damage: damage,
        speed: 350,
      );
      bullet.position = towerPosition;
      add(bullet);
    }
  }

  void _castFreeze(double damage) {
    // 对所有敌人造成伤害并减速
    for (final enemy in enemies) {
      enemy.takeDamage(damage);
      enemy.slow(2.0); // 减速2秒
    }
  }

  void _castLightning(double damage) {
    // 伤害最近的3个敌人
    final alive = enemies.where((e) => !e.isDead).toList();
    // 按y坐标排序（越靠近塔的越优先）
    alive.sort((a, b) => b.position.y.compareTo(a.position.y));
    for (int i = 0; i < alive.length && i < 3; i++) {
      alive[i].takeDamage(damage);
    }
  }

  void _checkCollisions() {
    final bullets = children.whereType<Projectile>().toList();

    for (final bullet in bullets) {
      for (final enemy in enemies) {
        if (bullet.toRect().overlaps(enemy.toRect())) {
          enemy.takeDamage(bullet.damage);
          bullet.removeFromParent();
          if (enemy.isDead) {
            enemy.removeFromParent();
          }
          break;
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 更新技能冷却
    skillManager.update(dt);

    // 敌人生成
    _enemySpawnTimer += dt;
    if (_enemySpawnTimer >= enemySpawnInterval) {
      _enemySpawnTimer = 0;
      _spawnEnemy();
    }

    _checkCollisions();
  }
}
```

**新增内容解释：**
- `skillManager` — 管理3个技能的冷却和升级
- `useSkill(int index)` — 被UI按钮调用，根据type执行不同技能
- `_castFireball` — 扇形发射5个火球
- `_castFreeze` — 所有敌人受伤+减速（Enemy需要新增slow方法）
- `_castLightning` — 攻击最近的3个敌人

- [ ] **Step 3.5: 给 Enemy 添加减速方法**

修改 `lib/game/components/enemy.dart`，添加 slow 方法：

在 Enemy 类中添加以下字段和方法：

```dart
// 在字段区域添加：
double _originalSpeed = speed;
double _slowTimer = 0;

// 添加 getter（可选，获取当前减速状态）
bool get isSlowed => _slowTimer > 0;

// 添加方法：
/// 减速指定秒数
void slow(double duration) {
  _slowTimer = duration;
}

// 修改 update 方法：
@override
void update(double dt) {
  super.update(dt);

  // 减速逻辑
  if (_slowTimer > 0) {
    _slowTimer -= dt;
    position.y += speed * 0.3 * dt;  // 减速到30%
  } else {
    position.y += speed * dt;
  }
}
```

- [ ] **Step 4: 修改 main.dart — 注册 skill_bar overlay**

替换 `lib/main.dart` 全部内容：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/defend_the_tower_game.dart';
import 'game/overlays/skill_bar.dart';

void main() {
  final game = DefendTheTowerGame();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // 游戏画布
            GameWidget(game: game),

            // 底部技能栏覆盖层
            SkillBar(
              skillManager: game.skillManager,
              onSkillUse: (index) => game.useSkill(index),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**解释：**
- `Stack` — Flutter 布局，让游戏和按钮叠加显示
- `GameWidget` — 渲染 Flame 游戏
- `SkillBar` — 底部技能按钮，点击调用 `game.useSkill()`

- [ ] **Step 5: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：**
- 底部3个技能按钮，点击释放技能
- 火球：扇形子弹
- 冰冻：敌人变慢+受到伤害
- 闪电：攻击最近的3个敌人
- 冷却中按钮显示黑色遮罩，就绪后金色边框

---

### Task 6: 波次系统 + 顶部HUD

**目标：** 10波递增，顶部显示信息，血量/金币系统

**文件：**
- 创建: `lib/game/managers/wave_manager.dart`
- 创建: `lib/game/overlays/game_hud.dart`
- 修改: `lib/game/defend_the_tower_game.dart` — 集成波次
- 修改: `lib/main.dart` — 添加HUD

- [ ] **Step 1: 创建波次管理器**

创建 `lib/game/managers/wave_manager.dart`：

```dart
/// 波次管理器 — 控制敌人波次
class WaveManager {
  // 当前波次（0 = 未开始）
  int currentWave = 0;

  // 总波数
  static const int totalWaves = 10;

  // 本波已生成敌人数
  int _spawnedCount = 0;

  // 本波总敌人数
  int get enemiesThisWave => 5 + currentWave * 2;

  // 本波剩余敌人数
  int _killedCount = 0;
  int get remainingEnemies => enemiesThisWave - _spawnedCount;
  int get aliveEnemies => _spawnedCount - _killedCount;

  // 生成间隔（秒）
  double _spawnTimer = 0;
  double get spawnInterval => (1.5 - currentWave * 0.1).clamp(0.4, 1.5);

  // 本波是否完成
  bool isWaveComplete() {
    return _spawnedCount >= enemiesThisWave && aliveEnemies <= 0;
  }

  // 是否所有波次完成
  bool get allWavesComplete => currentWave >= totalWaves && isWaveComplete();

  // 开始下一波
  void startNextWave() {
    currentWave++;
    _spawnedCount = 0;
    _killedCount = 0;
    _spawnTimer = 0;
  }

  // 检查是否该生成下一个敌人
  bool shouldSpawnEnemy(double dt) {
    _spawnTimer += dt;
    if (_spawnTimer >= spawnInterval && _spawnedCount < enemiesThisWave) {
      _spawnTimer = 0;
      _spawnedCount++;
      return true;
    }
    return false;
  }

  // 敌人被击杀时调用
  void onEnemyKilled() {
    _killedCount++;
  }

  // 获取当前波次的敌人血量倍率
  double get hpMultiplier => 1.0 + (currentWave - 1) * 0.3;

  // 获取当前波次的敌人速度倍率
  double get speedMultiplier => 1.0 + (currentWave - 1) * 0.1;
}
```

**解释：**
- `currentWave` — 当前是第几波
- `enemiesThisWave` — 每波敌人数量随波次递增
- `spawnInterval` — 生成间隔随波次递减（越来越快）
- `hpMultiplier` / `speedMultiplier` — 敌人强度随波次递增
- `isWaveComplete()` — 本波敌人都生成完且都死了才算完成

- [ ] **Step 2: 创建顶部 HUD**

创建 `lib/game/overlays/game_hud.dart`：

```dart
import 'package:flutter/material.dart';

/// 顶部游戏信息栏（血量、波次、金币）
class GameHud extends StatelessWidget {
  final int wave;
  final int hp;
  final int maxHp;
  final int gold;

  const GameHud({
    super.key,
    required this.wave,
    required this.hp,
    required this.maxHp,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 波次
              _buildInfoBox('🌊', '第$wave波', Colors.cyanAccent),

              // 血量
              _buildInfoBox('❤️', '$hp/$maxHp', Colors.redAccent),

              // 金币
              _buildInfoBox('💰', '$gold', Colors.amberAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
```

**解释：**
- `Positioned` — 在 Stack 中定位到顶部
- `SafeArea` — 避免系统状态栏遮挡
- `_buildInfoBox` — 统一的圆角半透明信息卡片
- 三个信息：波次、血量、金币

- [ ] **Step 3: 更新游戏主类 — 集成波次和金币**

替换 `lib/game/defend_the_tower_game.dart` 全部内容：

```dart
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'components/tower.dart';
import 'components/enemy.dart';
import 'components/projectile.dart';
import 'managers/skill_manager.dart';
import 'managers/wave_manager.dart';

class DefendTheTowerGame extends FlameGame {
  DefendTheTowerGame() {
    backgroundColor = const Color(0xFF1A1A2E);
  }

  // ─── 游戏状态 ───
  int hp = 20;
  int get maxHp => 50;
  int gold = 200;

  // ─── 管理器 ───
  final SkillManager skillManager = SkillManager();
  final WaveManager waveManager = WaveManager();

  // ─── 标记 ───
  bool isPaused = false;      // 选卡时暂停
  bool isGameOver = false;
  bool isVictory = false;

  // 便捷访问
  List<Enemy> get enemies => children.whereType<Enemy>().toList();
  Vector2 get towerPosition => Vector2(size.x / 2, size.y - 60);

  @override
  void onMount() {
    super.onMount();
    _spawnTower();
    waveManager.startNextWave(); // 开始第1波
  }

  void _spawnTower() {
    final tower = Tower(
      onFireBullet: (angle) => _fireBullet(angle),
    );
    tower.position = towerPosition;
    add(tower);
  }

  void _fireBullet(double angle) {
    final direction = Vector2(cos(angle), sin(angle));
    final bullet = Projectile(direction: direction);
    bullet.position = towerPosition;
    add(bullet);
  }

  void _spawnEnemy() {
    final rng = Random();
    final enemy = Enemy(
      hpMultiplier: waveManager.hpMultiplier,
      speedMultiplier: waveManager.speedMultiplier,
    );
    final marginX = 40.0;
    enemy.position = Vector2(
      marginX + rng.nextDouble() * (size.x - marginX * 2),
      -20.0,
    );
    add(enemy);
  }

  /// 敌人被击杀
  void onEnemyKilled(Enemy enemy) {
    gold += enemy.goldValue;
    waveManager.onEnemyKilled();
  }

  /// 敌人到达底部
  void onEnemyReachedBottom(Enemy enemy) {
    hp -= 5;
    enemy.removeFromParent();
    if (hp <= 0) {
      hp = 0;
      isGameOver = true;
    }
  }

  /// 使用技能
  void useSkill(int skillIndex) {
    if (isPaused || isGameOver) return;
    if (!skillManager.useSkill(skillIndex)) return;

    final skill = skillManager.getSkill(skillIndex);
    switch (skill.type) {
      case 'fireball':
        _castFireball(skill.damage);
        break;
      case 'freeze':
        _castFreeze(skill.damage);
        break;
      case 'lightning':
        _castLightning(skill.damage);
        break;
    }
  }

  void _castFireball(double damage) {
    for (int i = -2; i <= 2; i++) {
      final angle = -pi / 2 + i * 0.2;
      final direction = Vector2(cos(angle), sin(angle));
      final bullet = Projectile(direction: direction, damage: damage, speed: 350);
      bullet.position = towerPosition;
      add(bullet);
    }
  }

  void _castFreeze(double damage) {
    for (final enemy in enemies) {
      enemy.takeDamage(damage);
      enemy.slow(2.0);
    }
  }

  void _castLightning(double damage) {
    final alive = enemies.where((e) => !e.isDead).toList();
    alive.sort((a, b) => b.position.y.compareTo(a.position.y));
    for (int i = 0; i < alive.length && i < 3; i++) {
      alive[i].takeDamage(damage);
    }
  }

  void _checkCollisions() {
    final bullets = children.whereType<Projectile>().toList();
    for (final bullet in bullets) {
      for (final enemy in enemies) {
        if (bullet.toRect().overlaps(enemy.toRect())) {
          enemy.takeDamage(bullet.damage);
          bullet.removeFromParent();
          if (enemy.isDead) {
            onEnemyKilled(enemy);
            enemy.removeFromParent();
          }
          break;
        }
      }
    }
  }

  void _checkEnemiesOffScreen() {
    for (final enemy in enemies) {
      if (enemy.position.y > size.y + 20) {
        onEnemyReachedBottom(enemy);
      }
    }
  }

  @override
  void update(double dt) {
    if (isPaused || isGameOver || isVictory) return;
    super.update(dt);

    // 更新技能冷却
    skillManager.update(dt);

    // 检查波次完成
    if (waveManager.isWaveComplete()) {
      if (waveManager.allWavesComplete) {
        isVictory = true;
        return;
      }
      // 波次完成，暂停并显示选卡
      isPaused = true;
      // TODO: Task 7 添加选卡界面
    }

    // 敌人生成
    if (waveManager.shouldSpawnEnemy(dt)) {
      _spawnEnemy();
    }

    _checkCollisions();
    _checkEnemiesOffScreen();
  }
}
```

**解释：**
- `hp` / `gold` — 游戏核心资源
- `waveManager` — 管理波次逻辑
- `isPaused` — 选卡时设为 true，阻止游戏更新
- `onEnemyKilled()` — 击杀回调，加金币
- `onEnemyReachedBottom()` — 敌人到达底部，扣血
- Enemy 构造函数新增 `hpMultiplier` 和 `speedMultiplier` 参数

- [ ] **Step 3.5: 更新 Enemy 接受波次参数**

修改 `lib/game/components/enemy.dart` 的构造函数：

```dart
class Enemy extends PositionComponent {
  Enemy({double hpMultiplier = 1.0, double speedMultiplier = 1.0})
      : super(size: Vector2(40, 40), anchor: Anchor.center) {
    hp = maxHp * hpMultiplier;
    _originalSpeed = speed * speedMultiplier;
  }

  // ... 其余代码不变

  // 击杀金币
  int goldValue = 10;
}
```

同时在 Enemy 的 update 方法中，用 `_originalSpeed` 替代 `speed` 作为基础速度。

- [ ] **Step 4: 更新 main.dart — 添加 HUD**

替换 `lib/main.dart` 全部内容：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/defend_the_tower_game.dart';
import 'game/overlays/skill_bar.dart';
import 'game/overlays/game_hud.dart';

void main() {
  final game = DefendTheTowerGame();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // 游戏画布
            GameWidget(game: game),

            // 顶部信息栏
            GameHud(
              wave: game.waveManager.currentWave,
              hp: game.hp,
              maxHp: game.maxHp,
              gold: game.gold,
            ),

            // 底部技能栏
            SkillBar(
              skillManager: game.skillManager,
              onSkillUse: (index) => game.useSkill(index),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**问题：** 这里的 HUD 是静态的（不会随游戏状态更新）。Task 7 会通过 `overlay` 机制解决这个问题。

- [ ] **Step 5: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：** 顶部显示波次/血量/金币，敌人生成速度加快，金币增加，敌人到达底部扣血

---

### Task 7: 肉鸽选卡界面

**目标：** 波间暂停，显示3张技能卡选择，更新HUD为实时刷新

**文件：**
- 创建: `lib/game/overlays/skill_select.dart`
- 修改: `lib/game/defend_the_tower_game.dart` — 触发选卡
- 修改: `lib/main.dart` — 改为实时HUD

- [ ] **Step 1: 创建选卡界面**

创建 `lib/game/overlays/skill_select.dart`：

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../managers/skill_manager.dart';

/// 技能升级选项（肉鸽卡片）
class SkillOption {
  final String title;
  final String description;
  final String icon;
  final int cost;
  final int? skillIndex;    // 升级指定技能（null = 新效果）

  const SkillOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.cost,
    this.skillIndex,
  });
}

/// 生成3个随机选项
List<SkillOption> generateOptions(List<SkillData> currentSkills, int gold) {
  final rng = Random();
  final options = <SkillOption>[];

  // 选项1：升级火球术
  final fb = currentSkills[0];
  options.add(SkillOption(
    title: '🔥 强化${fb.name}',
    description: '伤害 ${fb.damage.toStringAsFixed(1)}→${(fb.damage*1.5).toStringAsFixed(1)}，冷却-15%',
    icon: '🔥',
    cost: 30 + fb.level * 20,
    skillIndex: 0,
  ));

  // 选项2：升级冰冻术
  final fr = currentSkills[1];
  options.add(SkillOption(
    title: '❄️ 强化${fr.name}',
    description: '伤害 ${fr.damage.toStringAsFixed(1)}→${(fr.damage*1.5).toStringAsFixed(1)}，冷却-15%',
    icon: '❄️',
    cost: 30 + fr.level * 20,
    skillIndex: 1,
  ));

  // 选项3：升级闪电链
  final lt = currentSkills[2];
  options.add(SkillOption(
    title: '⚡ 强化${lt.name}',
    description: '伤害 ${lt.damage.toStringAsFixed(1)}→${(lt.damage*1.5).toStringAsFixed(1)}，冷却-15%',
    icon: '⚡',
    cost: 30 + lt.level * 20,
    skillIndex: 2,
  ));

  options.shuffle();
  return options.take(3).toList(); // 3选1
}

/// 选卡覆盖层
class SkillSelectOverlay extends StatelessWidget {
  final List<SkillOption> options;
  final int gold;
  final void Function(SkillOption option) onSelect;

  const SkillSelectOverlay({
    super.key,
    required this.options,
    required this.gold,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎴 选择强化',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💰 金币：$gold',
              style: const TextStyle(color: Colors.amber, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ...options.map((option) => _buildCard(context, option)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, SkillOption option) {
    final canAfford = gold >= option.cost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
      child: GestureDetector(
        onTap: canAfford
            ? () => onSelect(option)
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canAfford
                ? Colors.blueGrey.withAlpha(200)
                : Colors.grey.withAlpha(100),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canAfford ? Colors.yellowAccent : Colors.grey,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(option.icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        color: canAfford ? Colors.white : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: TextStyle(
                        color: canAfford ? Colors.white70 : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '💰${option.cost}',
                style: TextStyle(
                  color: canAfford ? Colors.amber : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**解释：**
- `SkillOption` — 一张技能卡的数据
- `generateOptions()` — 生成3个随机选项（目前是3个技能的升级版）
- `SkillSelectOverlay` — 全屏半透明遮罩 + 3张卡片
- `canAfford` — 金币够不够，不够的卡片灰色不可点

- [ ] **Step 2: 更新游戏主类 — 触发选卡**

在 `lib/game/defend_the_tower_game.dart` 中添加：

```dart
import 'overlays/skill_select.dart'; // 新增导入

// 在类中添加：
// 当前选卡选项（需要是状态变量用于UI）
List<SkillOption>? _skillOptions;

// 存储一个异步 completer（用于等待选择）
// 简单做法：直接在回调中处理

/// 显示选卡界面
void _showSkillSelect() {
  _skillOptions = generateOptions(skillManager.skills, gold);
  overlays.add('skill_select'); // 添加覆盖层
}

/// 选卡回调
void onSkillSelected(SkillOption option) {
  // 扣金币
  gold -= option.cost;

  // 应用升级
  if (option.skillIndex != null) {
    skillManager.upgradeSkill(option.skillIndex!);
  }

  // 关闭选卡界面
  overlays.remove('skill_select');

  // 开始下一波
  waveManager.startNextWave();
  isPaused = false;
}
```

在 update 方法中，之前的 TODO 注释位置替换为：

```dart
if (waveManager.isWaveComplete()) {
  if (waveManager.allWavesComplete) {
    isVictory = true;
    return;
  }
  isPaused = true;
  _showSkillSelect();  // 替换原来的 TODO
}
```

- [ ] **Step 3: 重构 main.dart — 实时 HUD + 注册选卡 overlay**

替换 `lib/main.dart` 全部内容：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/defend_the_tower_game.dart';
import 'game/overlays/skill_bar.dart';
import 'game/overlays/game_hud.dart';
import 'game/overlays/skill_select.dart';

void main() {
  final game = DefendTheTowerGame();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // 游戏画布
            GameWidget(game: game),

            // 顶部信息栏（实时刷新：使用 overlay 内置机制）
            // 先用简单的 StreamBuilder 替代
            _GameHudUpdater(game: game),

            // 底部技能栏
            SkillBar(
              skillManager: game.skillManager,
              onSkillUse: (index) => game.useSkill(index),
            ),

            // 选卡界面（条件显示）
            _SkillSelectOverlayWrapper(game: game),
          ],
        ),
      ),
    ),
  );
}

/// 实时更新 HUD 的包装器
class _GameHudUpdater extends StatelessWidget {
  final DefendTheTowerGame game;
  const _GameHudUpdater({required this.game});

  @override
  Widget build(BuildContext context) {
    // 简单方案：在 update 循环中通过 ValueNotifier 刷新
    // 这里暂时使用游戏初始值，后续通过 Flame overlay 优化
    return GameHud(
      wave: game.waveManager.currentWave,
      hp: game.hp,
      maxHp: game.maxHp,
      gold: game.gold,
    );
  }
}

/// 选卡界面包装器（条件渲染）
class _SkillSelectOverlayWrapper extends StatelessWidget {
  final DefendTheTowerGame game;
  const _SkillSelectOverlayWrapper({required this.game});

  @override
  Widget build(BuildContext context) {
    // 简化：这里用 overlay 机制由 Game 控制显示
    // 真正的覆盖层显示在 Flame 的 overlays 系统中
    return const SizedBox.shrink();
  }
}
```

**注意：** 由于 HUD 需要实时刷新，最简单的做法是使用 `GameWidget.overlayBuilderMap`。

- [ ] **Step 3.5: 正确的 overlay 方案**

替换 `lib/main.dart` 为最终版本：

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/defend_the_tower_game.dart';
import 'game/overlays/skill_bar.dart';
import 'game/overlays/game_hud.dart';
import 'game/overlays/skill_select.dart';
import 'game/managers/skill_manager.dart';

void main() {
  final game = DefendTheTowerGame();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: GameWidget<DefendTheTowerGame>(
          game: game,
          // Flame overlay 系统：游戏通过 overlays.add/remove 控制显示
          overlayBuilderMap: {
            'skill_select': (context, game) {
              final options = (game as DefendTheTowerGame).skillOptions;
              if (options == null) return const SizedBox.shrink();
              return SkillSelectOverlay(
                options: options,
                gold: game.gold,
                onSelect: (option) => game.onSkillSelected(option),
              );
            },
          },
        ),
      ),
    ),
  );
}
```

然后在 GameWidget 上叠加 HUD 和 SkillBar（用 Stack）：

```dart
void main() {
  final game = DefendTheTowerGame();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // 游戏层（含 flame overlay）
            GameWidget<DefendTheTowerGame>(
              game: game,
              overlayBuilderMap: {
                'skill_select': (context, game) {
                  final options = (game as DefendTheTowerGame).skillOptions;
                  if (options == null) return const SizedBox.shrink();
                  return SkillSelectOverlay(
                    options: options,
                    gold: game.gold,
                    onSelect: (option) => game.onSkillSelected(option),
                  );
                },
              },
            ),

            // 顶部 HUD
            _GameHudUpdater(game: game),

            // 底部技能栏
            _SkillBarUpdater(game: game),
          ],
        ),
      ),
    ),
  );
}

/// 使用 ValueListenableBuilder 实时更新 HUD
class _GameHudUpdater extends StatelessWidget {
  final DefendTheTowerGame game;
  const _GameHudUpdater({required this.game});

  @override
  Widget build(BuildContext context) {
    return GameHud(
      wave: game.waveManager.currentWave,
      hp: game.hp,
      maxHp: game.maxHp,
      gold: game.gold,
    );
  }
}

class _SkillBarUpdater extends StatelessWidget {
  final DefendTheTowerGame game;
  const _SkillBarUpdater({required this.game});

  @override
  Widget build(BuildContext context) {
    return SkillBar(
      skillManager: game.skillManager,
      onSkillUse: (index) => game.useSkill(index),
    );
  }
}
```

并在游戏类中添加 `skillOptions` getter：

```dart
// 在 DefendTheTowerGame 类中添加：
List<SkillOption>? get skillOptions => _skillOptions;
```

- [ ] **Step 4: HUD 实时刷新方案**

由于 `_GameHudUpdater` 是静态的，需要改为实时刷新。最简单方案：

创建 `lib/game/overlays/game_hud.dart` 的新版本，接收 `ValueNotifier`：

```dart
import 'package:flutter/material.dart';

class GameHud extends StatelessWidget {
  final ValueNotifier<HudData> hudData;

  const GameHud({super.key, required this.hudData});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder<HudData>(
            valueListenable: hudData,
            builder: (context, data, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoBox('🌊', '第${data.wave}波', Colors.cyanAccent),
                  _buildInfoBox('❤️', '${data.hp}/${data.maxHp}', Colors.redAccent),
                  _buildInfoBox('💰', '${data.gold}', Colors.amberAccent),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// HUD 数据
class HudData {
  final int wave;
  final int hp;
  final int maxHp;
  final int gold;

  const HudData({
    required this.wave,
    required this.hp,
    required this.maxHp,
    required this.gold,
  });
}
```

在 `DefendTheTowerGame` 中添加：

```dart
final ValueNotifier<HudData> hudNotifier = ValueNotifier(
  const HudData(wave: 0, hp: 20, maxHp: 50, gold: 200),
);
```

在 `update` 方法末尾添加：

```dart
// 刷新 HUD
hudNotifier.value = HudData(
  wave: waveManager.currentWave,
  hp: hp,
  maxHp: maxHp,
  gold: gold,
);
```

在 `main.dart` 中使用：

```dart
_GameHudUpdater(game: game)  →  GameHud(hudData: game.hudNotifier)
```

- [ ] **Step 5: 运行验证效果**

```bash
cd "D:/新建文件夹/defend_the_tower" && flutter run -d windows
```

**预期效果：**
- 顶部 HUD 实时刷新波次/血量/金币
- 清完一波敌人后弹出选卡界面
- 选择一张卡→扣金币→升级技能→下一波开始
- 10波通关 → 胜利
- 血量归零 → 失败

---

## 总结

| Task | 核心学习点 |
|------|-----------|
| 1 | Flame 项目搭建, FlameGame, pubspec 配置 |
| 2 | PositionComponent, render, onLoad, onMount |
| 3 | update 循环, dt, 随机生成, 组件生命周期 |
| 4 | DragCallbacks, 碰撞检测, Vector2 方向 |
| 5 | Overlay, SkillManager, 技能冷却 |
| 6 | WaveManager, 游戏状态管理, hp/gold 系统 |
| 7 | overlayBuilderMap, ValueNotifier, 波间选择 |
