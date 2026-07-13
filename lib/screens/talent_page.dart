import 'dart:math';
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
    if (_isAdjacent(node.q, node.r, 0, 0)) return true;
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
        final hexSize = 40.0;
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
        shape: BoxShape.circle,
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
      _showInfo(context, node);
    } else if (canUnlock && tm.availablePoints > 0) {
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

    // 画中心到第一圈的连线
    for (final node in nodes) {
      final nodePos = _hexToPixel(node.q, node.r, cx, cy);

      if (_isAdjacent(node.q, node.r, 0, 0)) {
        final centerPos = Offset(cx, cy);
        paint.color = const Color(0x33FFFFFF);
        canvas.drawLine(centerPos, nodePos, paint);
      }

      // 节点到邻居连线
      for (final other in nodes) {
        if (other == node) continue;
        if (_isAdjacent(node.q, node.r, other.q, other.r)) {
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
