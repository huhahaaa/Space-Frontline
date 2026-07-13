# 天赋系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement meta-progression talent system with hexagonal grid UI, star-rating victory settlement, and four initial talents that persist via SharedPreferences.

**Architecture:** Singleton `TalentManager` wraps SharedPreferences for persistence and exposes talent effects as getters. Hex grid rendered via CustomPainter with GestureDetector nodes. Victory screen is a pure Flutter page receiving stats from the game. Game applies talent effects at startup and during wave advancement.

**Tech Stack:** Flutter 3.x, Flame 1.26.1, shared_preferences

## Global Constraints

- Use `camelCase` for variables, `PascalCase` for classes
- No `print()` — use `debugPrint()`
- Always type-annotate public APIs
- Use `const` constructors where possible
- Follow existing project patterns: `_MenuButton` style for buttons, `Color(0xFF1A3340)` card background
- Talent point balance: `SharedPreferences` key `talent_points`
- Unlocked talents: `SharedPreferences` key `talent_unlocked` (comma-separated TalentId indices)
- Level stars: `SharedPreferences` key `level_stars_{levelId}`
- Star rating: 满血=3星, 半血及以上=2星, 半血以下=1星, 失败=0
- Same level only grants difference on better rating
- Hex grid: axial coordinates, empty center, 12 nodes (6 ring 1 + 6 ring 2)
- 4 real talents: reinforcedArmor, expandedChoices, expDrain, freeReroll — single level each, cost 1 point
- Victory screen is an independent page (push replacement), not an overlay
- `shared_preferences` added to pubspec.yaml

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `pubspec.yaml` | Modify | Add `shared_preferences` dependency |
| `lib/game/talent_manager.dart` | **Create** | TalentId enum, TalentManager singleton, persistence, effects |
| `lib/screens/talent_page.dart` | **Create** | Hex grid talent page UI |
| `lib/screens/victory_screen.dart` | **Create** | Victory settlement page with star animation |
| `lib/screens/main_menu.dart` | Modify | Add "天赋" button |
| `lib/main.dart` | Modify | Add `/talent` and `/victory` routes |
| `lib/game/defend_the_tower_game.dart` | Modify | Apply talent effects, kill counter, victory callback, reroll logic |
| `lib/screens/game_screen.dart` | Modify | Remove gameWon overlay, add victory navigation listener |
| `lib/game/buffs/buff_manager.dart` | Modify | `generateChoices` accepts configurable count |
| `lib/screens/widgets/buff_card_overlay.dart` | Modify | Add reroll button |

---

### Task 1: Add shared_preferences Dependency

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `shared_preferences` package available for import

- [ ] **Step 1: Add dependency to pubspec.yaml**

```yaml
# In dependencies section, after flame:
  shared_preferences: ^2.2.0
```

- [ ] **Step 2: Install**

Run: `flutter pub get`
Expected: exits 0, no errors

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add shared_preferences dependency"
```

---

### Task 2: Create TalentManager

**Files:**
- Create: `lib/game/talent_manager.dart`

**Interfaces:**
- Produces:
  - `enum TalentId { reinforcedArmor, expandedChoices, expDrain, freeReroll }`
  - `class TalentManager` with static `TalentManager get instance`
  - `Future<void> init()` — load from SharedPreferences
  - `bool isUnlocked(TalentId id)`
  - `int get availablePoints`
  - `bool unlock(TalentId id)` — deduct 1 point, save
  - `int getStarsForLevel(String levelId)`
  - `Future<bool> setStarsForLevel(String levelId, int newStars)` — returns true if points earned
  - `int get bonusHp` — 20 if reinforcedArmor, else 0
  - `int get buffChoiceCount` — 4 if expandedChoices, else 3
  - `int get bonusExpPerWave` — 10 if expDrain, else 0
  - `int get freeRerollsPerGame` — 1 if freeReroll, else 0
  - `int _freeRerollsRemaining` — per-game counter
  - `void startGame()` — reset reroll counter
  - `bool useReroll()` — decrement and return true, or false if none left
  - `int get rerollsRemaining`

- [ ] **Step 1: Create `lib/game/talent_manager.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// 天赋标识枚举
enum TalentId {
  reinforcedArmor,   // 加固装甲：初始血量 +20
  expandedChoices,   // 选择扩充：buff 选择 3→4
  expDrain,          // 经验汲取：每波额外 +10 经验
  freeReroll,        // 重抽机会：每局 1 次免费重抽
}

/// 天赋管理器（单例）
class TalentManager {
  static TalentManager? _instance;
  static TalentManager get instance {
    _instance ??= TalentManager._();
    return _instance!;
  }

  TalentManager._();

  SharedPreferences? _prefs;
  int _availablePoints = 0;
  final Set<TalentId> _unlocked = {};

  // 每局重抽追踪（不持久化）
  int _freeRerollsRemaining = 0;

  // ─── 初始化 ───

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _availablePoints = _prefs!.getInt('talent_points') ?? 0;
    final unlockedStr = _prefs!.getString('talent_unlocked') ?? '';
    if (unlockedStr.isNotEmpty) {
      for (final s in unlockedStr.split(',')) {
        final idx = int.tryParse(s);
        if (idx != null && idx >= 0 && idx < TalentId.values.length) {
          _unlocked.add(TalentId.values[idx]);
        }
      }
    }
  }

  // ─── 查询 ───

  bool isUnlocked(TalentId id) => _unlocked.contains(id);
  int get availablePoints => _availablePoints;

  // ─── 解锁 ───

  bool unlock(TalentId id) {
    if (_availablePoints <= 0 || _unlocked.contains(id)) return false;
    _unlocked.add(id);
    _availablePoints--;
    _save();
    return true;
  }

  // ─── 星级结算 ───

  int getStarsForLevel(String levelId) {
    return _prefs?.getInt('level_stars_$levelId') ?? 0;
  }

  /// 尝试更新星级，返回本次获得的天赋点数
  Future<bool> setStarsForLevel(String levelId, int newStars) async {
    final oldStars = getStarsForLevel(levelId);
    if (newStars <= oldStars) return false;
    final earned = newStars - oldStars;
    await _prefs?.setInt('level_stars_$levelId', newStars);
    _availablePoints += earned;
    await _prefs?.setInt('talent_points', _availablePoints);
    return true;
  }

  // ─── 持久化 ───

  void _save() {
    _prefs?.setInt('talent_points', _availablePoints);
    final indices = _unlocked.map((e) => e.index.toString()).join(',');
    _prefs?.setString('talent_unlocked', indices);
  }

  // ═══════════════════════════════════════════
  // 天赋效果查询
  // ═══════════════════════════════════════════

  int get bonusHp => _unlocked.contains(TalentId.reinforcedArmor) ? 20 : 0;
  int get buffChoiceCount => _unlocked.contains(TalentId.expandedChoices) ? 4 : 3;
  int get bonusExpPerWave => _unlocked.contains(TalentId.expDrain) ? 10 : 0;
  int get freeRerollsPerGame => _unlocked.contains(TalentId.freeReroll) ? 1 : 0;

  // ─── 每局重抽 ───

  int get rerollsRemaining => _freeRerollsRemaining;

  void startGame() {
    _freeRerollsRemaining = freeRerollsPerGame;
  }

  bool useReroll() {
    if (_freeRerollsRemaining <= 0) return false;
    _freeRerollsRemaining--;
    return true;
  }
}
```

- [ ] **Step 2: Initialize TalentManager in main.dart**

In `lib/main.dart`, modify the `main()` function:

```dart
import 'game/talent_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TalentManager.instance.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DefendTheTowerApp());
}
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/game/talent_manager.dart lib/main.dart`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add lib/game/talent_manager.dart lib/main.dart
git commit -m "feat: add TalentManager with SharedPreferences persistence"
```

---

### Task 3: Create Talent Page (Hex Grid UI)

**Files:**
- Create: `lib/screens/talent_page.dart`

**Interfaces:**
- Consumes: `TalentManager.instance` — `availablePoints`, `isUnlocked(id)`, `unlock(id)`, `TalentId.values`
- Produces: `TalentPage` widget (pushed via `/talent` route)

- [ ] **Step 1: Create `lib/screens/talent_page.dart`**

```dart
import 'package:flutter/material.dart';
import '../game/talent_manager.dart';

class TalentPage extends StatefulWidget {
  const TalentPage({super.key});

  @override
  State<TalentPage> createState() => _TalentPageState();
}

class _TalentPageState extends State<TalentPage> {
  // ─── 节点定义 ───
  // axial 坐标 (q, r)，中心为 (0, 0) 空节点
  // 第一圈 6 个 + 第二圈 6 个 = 12 个
  static const _nodes = <_TalentNode>[
    // 第一圈（环绕中心）
    _TalentNode(0, -1, TalentId.reinforcedArmor, '加固装甲', '🛡️', '初始血量 +20'),
    _TalentNode(1, -1, TalentId.expandedChoices, '选择扩充', '📋', '升级时 buff 选择 3→4 张'),
    _TalentNode(1, 0, TalentId.expDrain, '经验汲取', '📊', '每波额外 +10 经验'),
    _TalentNode(0, 1, TalentId.freeReroll, '重抽机会', '🔄', '每局可免费重抽 buff 1 次'),
    _TalentNode(-1, 0, null, '???', '🔒', '暂未开放'),
    _TalentNode(-1, 1, null, '???', '🔒', '暂未开放'),
    // 第二圈（外围空壳）
    _TalentNode(0, -2, null, '???', '🔒', '暂未开放'),
    _TalentNode(2, -1, null, '???', '🔒', '暂未开放'),
    _TalentNode(2, 0, null, '???', '🔒', '暂未开放'),
    _TalentNode(0, 2, null, '???', '🔒', '暂未开放'),
    _TalentNode(-2, 1, null, '???', '🔒', '暂未开放'),
    _TalentNode(-2, 0, null, '???', '🔒', '暂未开放'),
  ];

  /// axial → 像素坐标（pointy-top 六边形）
  Offset _hexToPixel(int q, int r, double size) {
    final x = size * (3.0 / 2 * q);
    final y = size * (sqrt(3) / 2 * q + sqrt(3) * r);
    return Offset(x, y);
  }

  /// 判断两个六边形是否相邻
  bool _isAdjacent(int q1, int r1, int q2, int r2) {
    // 六边形相邻：axial 坐标差在 {(1,0),(1,-1),(0,-1),(-1,0),(-1,1),(0,1)}
    final dq = q1 - q2;
    final dr = r1 - r2;
    return (dq == 1 && dr == 0) ||
           (dq == 1 && dr == -1) ||
           (dq == 0 && dr == -1) ||
           (dq == -1 && dr == 0) ||
           (dq == -1 && dr == 1) ||
           (dq == 0 && dr == 1);
  }

  /// 节点是否可解锁（邻接已解锁节点 或 邻接中心）
  bool _canUnlock(_TalentNode node, Set<TalentId> unlocked) {
    // 第一圈节点（距中心相邻）默认可解锁
    final centerAdjacent = _isAdjacent(node.q, node.r, 0, 0);
    if (centerAdjacent) return true;
    // 检查是否有已解锁邻居
    for (final other in _nodes) {
      if (other.talentId == null) continue;
      if (!unlocked.contains(other.talentId)) continue;
      if (_isAdjacent(node.q, node.r, other.q, other.r)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tm = TalentManager.instance;
    final unlocked = <TalentId>{};
    for (final id in TalentId.values) {
      if (tm.isUnlocked(id)) unlocked.add(id);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '天赋',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // 天赋点余额
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3340),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x88FFD700)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '天赋点: ${tm.availablePoints}',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 提示文字
            const Text(
              '点击可解锁节点消耗 1 天赋点',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 16),
            // 六边形网格
            Expanded(
              child: Center(
                child: _buildHexGrid(unlocked, tm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHexGrid(Set<TalentId> unlocked, TalentManager tm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hexSize = 40.0; // 六边形外接圆半径
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _HexGridPainter(
            nodes: _nodes,
            hexSize: hexSize,
            unlocked: unlocked,
            talentManager: tm,
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                for (final node in _nodes)
                  Positioned(
                    left: constraints.maxWidth / 2 + _hexToPixel(node.q, node.r, hexSize).dx - hexSize,
                    top: constraints.maxHeight / 2 + _hexToPixel(node.q, node.r, hexSize).dy - hexSize,
                    child: GestureDetector(
                      onTap: () => _onNodeTap(context, node, unlocked, tm),
                      child: SizedBox(
                        width: hexSize * 2,
                        height: hexSize * 2,
                        child: Center(
                          child: _buildHexTile(node, unlocked, tm),
                        ),
                      ),
                    ),
                  ),
                // 中心空节点（装饰用）
                Positioned(
                  left: constraints.maxWidth / 2 - hexSize,
                  top: constraints.maxHeight / 2 - hexSize,
                  child: SizedBox(
                    width: hexSize * 2,
                    height: hexSize * 2,
                    child: Center(
                      child: Container(
                        width: hexSize * 1.2,
                        height: hexSize * 1.2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A3340).withAlpha(100),
                          border: Border.all(color: const Color(0x44FFFFFF)),
                        ),
                        child: const Center(
                          child: Text('⚙️', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHexTile(_TalentNode node, Set<TalentId> unlocked, TalentManager tm) {
    final isUnlocked = node.talentId != null && unlocked.contains(node.talentId);
    final canUnlock = node.talentId != null && !isUnlocked && _canUnlock(node, unlocked);
    final isPlaceholder = node.talentId == null;

    Color fillColor;
    Color borderColor;
    if (isUnlocked) {
      fillColor = const Color(0xFF2A5A4A);
      borderColor = const Color(0xFF44CC88);
    } else if (canUnlock && tm.availablePoints > 0) {
      fillColor = const Color(0xFF3A3A20);
      borderColor = const Color(0xFFFFD700);
    } else if (isPlaceholder) {
      fillColor = const Color(0xFF1A1A2A);
      borderColor = const Color(0x33FFFFFF);
    } else {
      fillColor = const Color(0xFF1A2A30);
      borderColor = const Color(0x44FFFFFF);
    }

    return Container(
      width: 68,
      height: 60,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle, // 简化：用圆形代替六边形裁剪
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(node.icon, style: const TextStyle(fontSize: 16)),
          if (isUnlocked || canUnlock)
            Text(
              node.name,
              style: TextStyle(
                color: isUnlocked ? Colors.white : const Color(0xFFFFD700),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              node.name,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  void _onNodeTap(BuildContext context, _TalentNode node, Set<TalentId> unlocked, TalentManager tm) {
    final isUnlocked = node.talentId != null && unlocked.contains(node.talentId);
    final isPlaceholder = node.talentId == null;
    final canUnlock = node.talentId != null && !isUnlocked && _canUnlock(node, unlocked);

    if (isUnlocked) {
      // 已解锁：显示效果说明
      _showInfo(context, node);
    } else if (canUnlock && tm.availablePoints > 0) {
      // 可解锁：确认弹窗
      _showUnlockConfirm(context, node, tm);
    } else if (isPlaceholder) {
      _showToast(context, '暂未开放');
    } else if (!canUnlock) {
      _showToast(context, '需先解锁相邻节点');
    } else {
      _showToast(context, '天赋点不足');
    }
  }

  void _showInfo(BuildContext context, _TalentNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A3340),
        title: Row(
          children: [
            Text(node.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(node.name, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(node.description, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showUnlockConfirm(BuildContext context, _TalentNode node, TalentManager tm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A3340),
        title: Row(
          children: [
            Text(node.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text('解锁 ${node.name}', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text(
              '消耗 ⭐ 1 天赋点',
              style: TextStyle(color: const Color(0xFFFFD700).withAlpha(200), fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              final ok = tm.unlock(node.talentId!);
              Navigator.pop(ctx);
              if (ok) {
                setState(() {});
                _showToast(context, '已解锁 ${node.name}！');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('确认解锁'),
          ),
        ],
      ),
    );
  }

  void _showToast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xCC1A3340),
      ),
    );
  }
}

/// 网格连线 Painter
class _HexGridPainter extends CustomPainter {
  final List<_TalentNode> nodes;
  final double hexSize;
  final Set<TalentId> unlocked;
  final TalentManager talentManager;

  _HexGridPainter({
    required this.nodes,
    required this.hexSize,
    required this.unlocked,
    required this.talentManager,
  });

  Offset _hexToPixel(int q, int r, double cx, double cy) {
    final x = hexSize * (3.0 / 2 * q);
    final y = hexSize * (sqrt(3) / 2 * q + sqrt(3) * r);
    return Offset(cx + x, cy + y);
  }

  bool _isAdjacent(int q1, int r1, int q2, int r2) {
    final dq = q1 - q2;
    final dr = r1 - r2;
    return (dq == 1 && dr == 0) ||
           (dq == 1 && dr == -1) ||
           (dq == 0 && dr == -1) ||
           (dq == -1 && dr == 0) ||
           (dq == -1 && dr == 1) ||
           (dq == 0 && dr == 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 画中心到第一圈的连线 + 节点间连线
    for (final node in nodes) {
      final nodePos = _hexToPixel(node.q, node.r, cx, cy);

      // 中心到第一圈节点
      if (_isAdjacent(node.q, node.r, 0, 0)) {
        final centerPos = Offset(cx, cy);
        paint.color = const Color(0x33FFFFFF);
        canvas.drawLine(centerPos, nodePos, paint);
      }

      // 节点到邻居连线
      for (final other in nodes) {
        if (other == node) continue;
        if (_isAdjacent(node.q, node.r, other.q, other.r)) {
          // 避免重复绘制
          if (node.q + node.r > other.q + other.r) continue;

          final otherPos = _hexToPixel(other.q, other.r, cx, cy);
          final bothUnlocked = node.talentId != null && unlocked.contains(node.talentId) &&
                               other.talentId != null && unlocked.contains(other.talentId);
          paint.color = bothUnlocked ? const Color(0x88FFD700) : const Color(0x22FFFFFF);
          canvas.drawLine(nodePos, otherPos, paint);
        }
      }
    }

    // 画中心圆
    final centerPaint = Paint()
      ..color = const Color(0xFF1A3340).withAlpha(80)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), hexSize * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter old) =>
      old.unlocked.length != unlocked.length;
}

class _TalentNode {
  final int q;
  final int r;
  final TalentId? talentId;
  final String name;
  final String icon;
  final String description;

  const _TalentNode(this.q, this.r, this.talentId, this.name, this.icon, this.description);
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/screens/talent_page.dart`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/talent_page.dart
git commit -m "feat: add talent page with hexagonal grid UI"
```

---

### Task 4: Add Talent Route + Main Menu Button

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/main_menu.dart`

**Interfaces:**
- Consumes: `TalentPage` widget
- Produces: `/talent` route available, "天赋" button on main menu

- [ ] **Step 1: Add talent route in main.dart**

In `lib/main.dart`, add import and route:

```dart
import 'screens/talent_page.dart';

// In routes map, add:
'/talent': (_) => const TalentPage(),
```

- [ ] **Step 2: Add talent button in main_menu.dart**

In `lib/screens/main_menu.dart`, add a third `_MenuButton` between "开始游戏" and "怪物图鉴":

```dart
const SizedBox(height: 16),
_MenuButton(
  icon: '⭐',
  label: '天赋',
  onTap: () => Navigator.pushNamed(context, '/talent'),
),
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/main.dart lib/screens/main_menu.dart`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/screens/main_menu.dart
git commit -m "feat: add talent route and main menu button"
```

---

### Task 5: Integrate Talent Effects into Game

**Files:**
- Modify: `lib/game/defend_the_tower_game.dart`
- Modify: `lib/game/buffs/buff_manager.dart`

**Interfaces:**
- Consumes: `TalentManager.instance` — `startGame()`, `bonusHp`, `buffChoiceCount`, `bonusExpPerWave`, `useReroll()`, `rerollsRemaining`
- Produces:
  - Game applies bonus HP at construction
  - `_advanceWave` adds bonus exp
  - `_triggerLevelUp` uses `buffChoiceCount`
  - `generateChoices` accepts configurable count parameter
  - `int _killCount` field with getter
  - `VoidCallback? onGameWon` callback
  - `void rerollBuffChoices()` method

- [ ] **Step 1: Modify BuffManager.generateChoices to accept configurable count**

In `lib/game/buffs/buff_manager.dart`, change the method signature:

```dart
List<BuffId> generateChoices({int count = 3}) {
```

(Already has this signature — no change needed.)

- [ ] **Step 2: Add talent imports and fields to game**

In `lib/game/defend_the_tower_game.dart`, add import:

```dart
import 'talent_manager.dart';
```

Add fields after `_hp`:

```dart
int _killCount = 0;
int get killCount => _killCount;
VoidCallback? onGameWon;
```

- [ ] **Step 3: Apply talent bonus HP in onLoad**

In `onLoad()`, after `_buffManager` setup, add:

```dart
final tm = TalentManager.instance;
tm.startGame();
_hp = maxHp + tm.bonusHp;
// Update maxHp display
```

Change the `maxHp` getter to:

```dart
int get maxHp => 100 + TalentManager.instance.bonusHp;
```

And the initial `_hp` declaration:

```dart
int _hp = 100; // bonus applied in onLoad
```

Update `_notifyHud` to use the dynamic `maxHp`:

```dart
// Already uses maxHp getter — verify this.
```

- [ ] **Step 4: Add kill counter and victory callback**

In `_onEnemyKilled`, add before `enemy.removeFromParent()`:

```dart
_killCount++;
```

In `update()`, where `_gameWon = true; _notifyHud();`, add:

```dart
_gameWon = true;
_notifyHud();
onGameWon?.call();
```

- [ ] **Step 5: Add bonus exp per wave**

In `_advanceWave()`, add after wave increment:

```dart
_exp += TalentManager.instance.bonusExpPerWave;
```

- [ ] **Step 6: Use talent buffChoiceCount for level ups**

In `_triggerLevelUp()`, change:

```dart
_buffChoices = _buffManager!.generateChoices(count: TalentManager.instance.buffChoiceCount);
```

- [ ] **Step 7: Add reroll method**

```dart
void rerollBuffChoices() {
  final tm = TalentManager.instance;
  if (!tm.useReroll()) return;
  _buffChoices = _buffManager!.generateChoices(count: tm.buffChoiceCount);
  _notifyHud();
  onBuffSelectionChanged?.call();
}
```

- [ ] **Step 8: Verify compilation**

Run: `flutter analyze lib/game/defend_the_tower_game.dart lib/game/buffs/buff_manager.dart`
Expected: no errors

- [ ] **Step 9: Commit**

```bash
git add lib/game/defend_the_tower_game.dart lib/game/buffs/buff_manager.dart
git commit -m "feat: integrate talent effects into game (bonus HP, exp, choice count, reroll)"
```

---

### Task 6: Create Victory Screen

**Files:**
- Create: `lib/screens/victory_screen.dart`

**Interfaces:**
- Consumes: `TalentManager.instance.setStarsForLevel(levelId, stars)`
- Produces: `VictoryScreen` widget accepting `({required int hp, required int maxHp, required int kills, required int wave, required String levelId})`

- [ ] **Step 1: Create `lib/screens/victory_screen.dart`**

```dart
import 'package:flutter/material.dart';
import '../game/talent_manager.dart';

class VictoryScreen extends StatefulWidget {
  final int hp;
  final int maxHp;
  final int kills;
  final int wave;
  final String levelId;

  const VictoryScreen({
    super.key,
    required this.hp,
    required this.maxHp,
    required this.kills,
    required this.wave,
    this.levelId = 'stage_1',
  });

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen> with SingleTickerProviderStateMixin {
  int _stars = 0;
  int _earnedPoints = 0;
  late AnimationController _starAnim;

  @override
  void initState() {
    super.initState();
    // 计算星级
    final hpPercent = widget.maxHp > 0 ? widget.hp / widget.maxHp : 0;
    if (hpPercent >= 1.0) {
      _stars = 3;
    } else if (hpPercent >= 0.5) {
      _stars = 2;
    } else {
      _stars = 1;
    }

    _starAnim = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _calculateAndSavePoints();
    _starAnim.forward();
  }

  Future<void> _calculateAndSavePoints() async {
    final oldStars = TalentManager.instance.getStarsForLevel(widget.levelId);
    if (_stars > oldStars) {
      // 逐星获得天赋点
      final earned = _stars - oldStars;
      await TalentManager.instance.setStarsForLevel(widget.levelId, _stars);
      if (mounted) setState(() => _earnedPoints = earned);
    }
  }

  @override
  void dispose() {
    _starAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hpPercent = widget.maxHp > 0 ? (widget.hp / widget.maxHp).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                '胜利！',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '成功抵御外星入侵',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // 星级动画
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StarWidget(
                    earned: _stars >= 1,
                    delay: 0,
                    animation: _starAnim,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  _StarWidget(
                    earned: _stars >= 2,
                    delay: 600,
                    animation: _starAnim,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  _StarWidget(
                    earned: _stars >= 3,
                    delay: 1200,
                    animation: _starAnim,
                    size: 48,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _starLabel,
                style: TextStyle(
                  color: _starColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 统计
              _StatRow(label: '剩余血量', value: '${widget.hp} / ${widget.maxHp}', color: hpPercent > 0.5 ? Colors.greenAccent : Colors.orangeAccent),
              _StatRow(label: '击杀数', value: '${widget.kills}'),
              _StatRow(label: '存活波数', value: '${widget.wave} / 15'),
              const SizedBox(height: 8),

              // 获得天赋点
              if (_earnedPoints > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3340),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x88FFD700)),
                  ),
                  child: Text(
                    '⭐ 获得 $_earnedPoints 天赋点',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              if (_earnedPoints == 0 && _stars > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '本关无新增天赋点（已达最高评价）',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A5A4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('返回主菜单', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _starLabel {
    return switch (_stars) {
      3 => '完美通关',
      2 => '表现不错',
      1 => '勉强过关',
      _ => '',
    };
  }

  Color get _starColor {
    return switch (_stars) {
      3 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      1 => const Color(0xFFCD7F32),
      _ => Colors.white,
    };
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StarWidget extends StatelessWidget {
  final bool earned;
  final int delay;
  final Animation<double> animation;
  final double size;

  const _StarWidget({
    required this.earned,
    required this.delay,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final start = delay / 1800.0;
    final end = (start + 0.3).clamp(0.0, 1.0);
    final t = animation.value.clamp(start, end);
    final scale = ((t - start) / (end - start)).clamp(0.0, 1.0);

    return Transform.scale(
      scale: earned ? 0.3 + 0.7 * Curves.elasticOut.transform(scale) : 0.3,
      child: Opacity(
        opacity: earned ? 1.0 : 0.2,
        child: Text(
          '⭐',
          style: TextStyle(fontSize: size),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/screens/victory_screen.dart`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/victory_screen.dart
git commit -m "feat: add victory settlement screen with star rating"
```

---

### Task 7: Wire Victory Navigation in GameScreen

**Files:**
- Modify: `lib/screens/game_screen.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `VictoryScreen`, `DefendTheTowerGame.onGameWon`, `DefendTheTowerGame.killCount`
- Produces: Game won → navigates to victory screen instead of overlay

- [ ] **Step 1: Add victory route in main.dart**

```dart
import 'screens/victory_screen.dart';

// In routes map, add:
'/victory': (context) {
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is Map) {
    return VictoryScreen(
      hp: args['hp'] as int,
      maxHp: args['maxHp'] as int,
      kills: args['kills'] as int,
      wave: args['wave'] as int,
      levelId: args['levelId'] as String? ?? 'stage_1',
    );
  }
  return const VictoryScreen(hp: 0, maxHp: 100, kills: 0, wave: 0);
},
```

- [ ] **Step 2: Modify GameScreen to listen for gameWon and navigate**

In `lib/screens/game_screen.dart`, update `initState`:

```dart
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

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}
```

- [ ] **Step 3: Remove gameWon overlay from _GameHud**

In `_GameHudState.build()`, remove the `if (_data.gameWon)` block (the overlay with "🎉 胜利！"). Keep the `if (_data.gameOver)` block as-is (failure stays as overlay).

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze lib/screens/game_screen.dart lib/main.dart`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart lib/main.dart
git commit -m "feat: wire victory navigation to settlement screen"
```

---

### Task 8: Add Reroll Button to BuffCardOverlay

**Files:**
- Modify: `lib/screens/widgets/buff_card_overlay.dart`
- Modify: `lib/screens/game_screen.dart`

**Interfaces:**
- Consumes: `rerollsRemaining` from TalentManager, game's `rerollBuffChoices()`
- Produces: Reroll button visible on buff selection overlay when rerolls available

- [ ] **Step 1: Add reroll callback to BuffCardOverlay**

In `lib/screens/widgets/buff_card_overlay.dart`:

```dart
// Add to constructor:
final VoidCallback? onReroll;
final int rerollsRemaining;

const BuffCardOverlay({
  super.key,
  required this.choices,
  required this.currentLevels,
  required this.onSelected,
  required this.onSkip,
  this.onReroll,
  this.rerollsRemaining = 0,
});
```

Add reroll button between the cards and the skip button:

```dart
// After the for loop for cards, before the skip button:
if (onReroll != null && rerollsRemaining > 0) ...[
  const SizedBox(height: 16),
  GestureDetector(
    onTap: onReroll,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3340),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x88FFD700)),
      ),
      child: Text(
        '🔄 重抽 ($rerollsRemaining)',
        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14),
      ),
    ),
  ),
],
```

- [ ] **Step 2: Wire reroll in GameScreen**

In `lib/screens/game_screen.dart`, update the `BuffCardOverlay` usage in `build()`:

```dart
// Import talent_manager
import '../game/talent_manager.dart';

// In the BuffCardOverlay constructor, add:
BuffCardOverlay(
  choices: data.buffChoices!,
  currentLevels: data.activeBuffs,
  onSelected: (id) => _game.selectBuff(id),
  onSkip: () => _game.skipBuff(),
  onReroll: TalentManager.instance.rerollsRemaining > 0
      ? () => _game.rerollBuffChoices()
      : null,
  rerollsRemaining: TalentManager.instance.rerollsRemaining,
),
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/screens/widgets/buff_card_overlay.dart lib/screens/game_screen.dart`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add lib/screens/widgets/buff_card_overlay.dart lib/screens/game_screen.dart
git commit -m "feat: add free reroll button to buff selection overlay"
```

---
