# 塔防+肉鸽游戏设计文档

## 概述
使用 Flutter + Flame 引擎，创建竖屏塔防游戏。参考"向僵尸开炮"的核心玩法：怪物从屏幕顶部出现向下移动，玩家在底部防御，通过拖拽瞄准射击，结合波次系统和波间技能卡选择（肉鸽元素）。

## 技术栈
- Flutter 3.41.4 / Dart 3.11.1
- Flame 游戏引擎 (flame: ^1.x)
- 目标平台：Web / Windows / Mobile

## 核心玩法循环
战斗（击杀敌人获得金币）→ 波次结束 → 选技能卡（3选1）→ 下一波（更强敌人）

## 功能点

### 1. 项目搭建 + 游戏画布
- 添加 flame 依赖到 pubspec.yaml
- 创建 FlameGame 主类
- 显示空白游戏画布

### 2. 防御塔
- 底部居中显示防御塔
- 使用 PositionComponent 渲染

### 3. 敌人
- 从屏幕顶部随机位置生成
- 向下匀速移动
- 到达底部扣除玩家血量
- 被击杀掉落金币

### 4. 半自动射击
- 玩家按住塔拖拽：显示瞄准线
- 松手：发射子弹沿瞄准方向飞行
- 子弹碰撞敌人造成伤害
- 敌人血量归零 → 死亡 → 掉落金币

### 5. 技能系统
- 3个技能：火球(AOE伤害)、冰冻(减速)、闪电(连锁伤害)
- 每个技能有冷却时间
- 底部技能按钮，点击释放
- 技能可升级（通过选卡）

### 6. 波次系统 + HUD
- 10波递增难度
- 顶部显示：当前波次、血量、金币
- 每波敌人数量/血量递增
- 血量归零 → 游戏结束

### 7. 肉鸽选卡界面
- 波间暂停游戏
- 显示3张随机技能卡
- 玩家选择一张（消耗金币或免费）
- 技能卡效果：升级现有技能、获得新技能、属性加成

## 文件结构
```
lib/
  main.dart
  game_config.dart
  game/
    defend_the_tower_game.dart
    components/
      tower.dart
      enemy.dart
      projectile.dart
    managers/
      wave_manager.dart
      skill_manager.dart
    overlays/
      game_hud.dart
      skill_bar.dart
      skill_select.dart
```

## 数据结构
- GameConfig: 常量（塔攻击力、敌人生成间隔、金币掉落等）
- 敌人: position, hp, speed, goldValue, type
- 子弹: position, direction, speed, damage, type
- 技能: name, cooldown, damage, level, type
- 波次: waveNumber, enemyCount, enemyHpMultiplier
