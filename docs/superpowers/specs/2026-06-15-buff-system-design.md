# Buff 选择系统设计

**日期**: 2026-06-15  
**状态**: 已确认

---

## 1. 概述

每次升级触发三选一 buff 卡片弹窗，游戏暂停。支持跳过暂存（最多 3 组，FIFO），同名 buff 叠加升级（Lv.1→Lv.3，Lv.3 封顶退池）。

---

## 2. Buff 池（18 个，5 系）

### ⚙️ 通用系 — 基础属性提升 (5)

| Buff | Lv.1 | Lv.2 | Lv.3 |
|------|------|------|------|
| **急速射击** | 攻击间隔 -15% | 间隔 -25% | 间隔 -35% + 10%概率双发 |
| **强化弹头** | 子弹伤害 +30% | 伤害 +50% | 伤害 +70% + 对精英额外+20% |
| **鹰眼** | 索敌区 80%→90% | 索敌区 100%（全屏） | 全屏 + 追踪强度 +30% |
| **无人机过载** | 无人机冷却 -1.5s（5→3.5s） | 冷却 -2.5s（→2.5s） | 双无人机弹（同时两发） |
| **弹幕扩充** | 每第5发追加一弹 | 每第4发 | 每第3发 + 第三发也追加 |

### 🔥 火焰系 — DOT + 扩散 (3)

| Buff | Lv.1 | Lv.2 | Lv.3 |
|------|------|------|------|
| **灼热弹头** | 命中点燃，3秒内每秒5伤害 | 每秒8伤害 | 每秒12 + 死亡爆炸灼烧附近 |
| **火焰风暴** | 每第7发追加火焰弹（范围灼烧） | 每第5发 | 双火焰弹 |
| **余烬余波** | 击杀灼烧敌人→周围灼烧 | 范围+30% | 灼烧可多层叠加 |

### ❄️ 冰霜系 — 减速 + 控制 (3)

| Buff | Lv.1 | Lv.2 | Lv.3 |
|------|------|------|------|
| **冰霜弹头** | 命中减速30%，2秒 | 减速50% | 减速≥80%时冻结1秒 |
| **冰霜新星** | 精英死亡触发冰爆，冻结0.8秒 | 范围+40%，冻结1.2秒 | 被冻敌人死亡也触发小冰爆 |
| **极寒光环** | 塔周围减速15% | 减速25% | 每波获得1层护盾 |

### ⚡ 雷电系 — 连锁 + 爆发 (3)

| Buff | Lv.1 | Lv.2 | Lv.3 |
|------|------|------|------|
| **连锁闪电** | 命中弹射1次，60%伤害 | 弹射2次 | 弹射可重复命中同目标 |
| **静电场** | 每10秒随机落雷，范围30伤害 | 每7秒 | 双雷同时 |
| **电磁脉冲** | 击杀释放EMP消除震荡波 | 范围+50% | 被EMP命中的精英震荡波CD+3秒 |

### 🌑 暗影系 — 条件触发 + 高回报 (4)

| Buff | Lv.1 | Lv.2 | Lv.3 |
|------|------|------|------|
| **嗜血渴望** | 击杀5%概率回复5%HP | 概率10% | 概率15% + 触发后3秒伤害+20% |
| **暗影标记** | 无人机命中标记3秒，塔对该目标+40%伤害 | +60%伤害 | 标记死亡时传染附近 |
| **恐惧之触** | 敌人进索敌区15%概率恐惧1.5秒（反向跑） | 概率25% | 恐惧碰撞传染 |
| **虚空裂隙** | 每波1个裂隙5秒，每秒8伤害 | 每秒12 | 裂隙拉向中心 |

---

## 3. 数据结构

### BuffId 枚举

```dart
enum BuffId {
  rapidFire, powerShot, eagleEye, droneOverload, barrageExpand,
  scorchingShot, fireStorm, emberEcho,
  frostShot, frostNova, frostAura,
  chainLightning, staticField, emp,
  bloodthirst, shadowMark, fearTouch, voidRift,
}
```

### 注册表（静态只读）

```dart
class BuffRegistry {
  static const data = <BuffId, BuffMeta>{ ... };
}
// 每个 BuffMeta 包含: name, icon(emoji), element, maxLevel=3, levels: Map<int, BuffLevel>
// 每个 BuffLevel 包含: params(Map<String, double>), description(String)
```

### 运行时状态

```dart
// BuffManager 组件内
Map<BuffId, int> _levels = {};   // buff → 当前等级
```

---

## 4. 卡片弹窗 UI

### 布局（竖屏从上到下）

- 半透明黑遮罩 `Colors.black54`
- 顶部 "⬆ LEVEL UP! ⬆" 提示文字
- 3 张卡片竖排，间距 12px
- 底部 "跳过本次 →" 文字按钮
- 不可点空白区取消

### 单张卡片

- 背景 `Color(0xFF1A3340)`，圆角 12px
- 左侧 emoji 图标（24px），居中
- 顶部：名称 + 右上等级标签（NEW / Lv.1→2 / Lv.3 MAX 灰显）
- 下方：一行描述文本
- 选中时：元素色边框发光 + InkWell 涟漪
- 尺寸：屏幕宽度的 85%，高度约 80px

### 元素色映射

| 元素 | 颜色 |
|------|------|
| 通用 | `0xFFB0BEC5` (蓝灰) |
| 火焰 | `0xFFFF6D3F` (橙红) |
| 冰霜 | `0xFF64B5F6` (冰蓝) |
| 雷电 | `0xFFFFD740` (金黄) |
| 暗影 | `0xFFAB47BC` (紫) |

---

## 5. 暂存槽

### 位置与外观

- 游戏画面左上角，SafeArea 下方
- 3 个 40×40 竖排小方格，间距 4px
- 有 buff：填充满格 + 图标 + 元素色描边
- 空槽：灰色虚线边框
- 点击任意有内容的槽 → 暂停 → 弹出该组 3 张卡片重选

### FIFO 淘汰

- 满 3 格时新卡入队尾（③）
- 最老的（①）被顶掉销毁
- 被顶掉时播放小缩小消失动画（~200ms）

---

## 6. 暂停机制

`DefendTheTowerGame.update()` 顶部：

```dart
if (_paused || _gameWon || _gameOver) {
  _notifyHud();
  return;
}
```

触发链路：
1. `_exp >= expToNextLevel` → 升级
2. `_paused = true`
3. 通知 game_screen 弹出卡片 overlay
4. 玩家选择 → BuffManager.apply(id) → `_paused = false`
5. 玩家跳过 → 存入暂存槽 → `_paused = false`

---

## 7. Buff 生效架构

### BuffManager 组件

```dart
class BuffManager extends PositionComponent {
  // 查询接口
  int levelOf(BuffId id);
  bool has(BuffId id);
  
  // 派生属性
  double get damageMultiplier;
  double get fireRateMultiplier;
  // ...
  
  // 周期性效果（静电场、虚空裂隙）
  @override void update(double dt) { ... }
}
```

### 效果分发策略

| 类型 | 实现位置 |
|------|----------|
| 数值修正 | `_fireBullet()`, `_autoAimAtNearestEnemy()` 从 BuffManager 读系数 |
| 命中触发（灼烧/减速/标记） | `Projectile` 碰撞时查 BuffManager → 给 enemy 挂状态 Component |
| 击杀触发（嗜血/冰爆/EMP/余烬） | `_onEnemyKilled()` 查 BuffManager → 执行额外逻辑 |
| 周期性（静电场/虚空裂隙/火焰风暴） | BuffManager.update() 计时 → 生成独立 Component |
| 无人机修正 | `_fireDroneBullet()` 前查 droneOverload/barrageExpand |
| 索敌范围 | `isInRange()` 改用 `rangePercent` 从 BuffManager 读取 |

### 状态效果实现

每个元素状态作为独立 Component 挂在敌人身上：

```
灼烧 (Burning)    → enemy.add(Burning(dps, duration))
减速 (Slowed)     → enemy.add(Slowed(factor, duration))
冻结 (Frozen)     → enemy.add(Frozen(duration))
标记 (Marked)     → enemy.add(Marked(damageMultiplier, duration))
恐惧 (Feared)     → enemy.add(Feared(duration))
```

各 Component 的 `update()` 自行计时和移除。

---

## 8. 文件结构

```
lib/
├── game/
│   ├── buffs/
│   │   ├── buff_registry.dart      # BuffId 枚举 + 静态注册表
│   │   ├── buff_manager.dart       # 运行时 BuffManager 组件
│   │   ├── buff_card_data.dart     # BuffCardData（序列化用于暂存）
│   │   └── status_effects/         # 状态效果组件
│   │       ├── burning.dart
│   │       ├── slowed.dart
│   │       ├── frozen.dart
│   │       ├── marked.dart
│   │       └── feared.dart
│   ├── components/
│   │   └── ... (现有文件)
│   ├── defend_the_tower_game.dart
│   └── ...
├── screens/
│   ├── game_screen.dart            # 新增 _showBuffOverlay(), 暂存槽 UI
│   └── widgets/
│       ├── buff_card_overlay.dart  # 3 张卡片弹窗 Widget
│       └── buff_stash_bar.dart     # 暂存槽 Widget
└── main.dart
```

---

## 9. 实现顺序

1. `buff_registry.dart` — 枚举 + 注册表（纯数据，无依赖）
2. `buff_manager.dart` — BuffManager 组件骨架
3. `defend_the_tower_game.dart` — 集成暂停 + BuffManager
4. `buff_card_overlay.dart` — 卡片弹窗 UI
5. `buff_stash_bar.dart` — 暂存槽 UI
6. `game_screen.dart` — 对接 overlay + stash bar + HUD 更新
7. 逐个实现 buff 效果（按系推进，先通用→火焰→冰霜→雷电→暗影）
8. 状态效果组件（按需实现）
