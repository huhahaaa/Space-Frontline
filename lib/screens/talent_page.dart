import 'dart:math';
import 'package:flutter/material.dart';
import '../game/talent_manager.dart';

class TalentPage extends StatefulWidget {
  const TalentPage({super.key});

  @override
  State<TalentPage> createState() => _TalentPageState();
}

class _TalentPageState extends State<TalentPage> {
  static const _nodes = <_TalentNode>[
    // 第一圈（环绕中心）— 6 个
    _TalentNode(0, -1, TalentId.reinforcedArmor, '加固装甲', '🛡️', '初始血量 +20'),
    _TalentNode(1, -1, TalentId.expandedChoices, '选择扩充', '📋', '升级时 buff 选择 3→4 张'),
    _TalentNode(1, 0, TalentId.expDrain, '经验汲取', '📊', '每波额外 +10 经验'),
    _TalentNode(0, 1, TalentId.freeReroll, '重抽机会', '🔄', '每局可免费重抽 buff 1 次'),
    _TalentNode(-1, 0, null, '', '🔒', '暂未开放'),
    _TalentNode(-1, 1, null, '', '🔒', '暂未开放'),
    // 第二圈（外围空壳）— 6 个
    _TalentNode(0, -2, null, '', '🔒', '暂未开放'),
    _TalentNode(2, -1, null, '', '🔒', '暂未开放'),
    _TalentNode(2, 0, null, '', '🔒', '暂未开放'),
    _TalentNode(0, 2, null, '', '🔒', '暂未开放'),
    _TalentNode(-2, 1, null, '', '🔒', '暂未开放'),
    _TalentNode(-2, 0, null, '', '🔒', '暂未开放'),
  ];

  Offset _hexToPixel(int q, int r, double size) {
    final x = size * (3.0 / 2 * q);
    final y = size * (sqrt(3) / 2 * q + sqrt(3) * r);
    return Offset(x, y);
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

  bool _canUnlock(_TalentNode node, Set<TalentId> unlocked) {
    if (_isAdjacent(node.q, node.r, 0, 0)) return true;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 星空背景
          Image.asset(
            'assets/images/Space Background_2.png',
            fit: BoxFit.cover,
          ),
          // 暗色覆层增强可读性
          Container(color: Colors.black.withAlpha(120)),

          // 内容
          SafeArea(
            child: Column(
              children: [
                // 顶部栏 — 浮动风格
                _buildTopBar(),
                const SizedBox(height: 2),
                // 天赋点徽章
                _buildPointBadge(tm.availablePoints),
                const SizedBox(height: 8),
                // 提示文字
                Text(
                  '点击相邻节点解锁天赋',
                  style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                // 六边形网格
                Expanded(child: Center(child: _buildHexGrid(unlocked, tm))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              '天赋星图',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildPointBadge(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xAA0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FFD700)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFD700).withAlpha(30), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            '$points',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 六边形网格
  // ═══════════════════════════════════════════

  Widget _buildHexGrid(Set<TalentId> unlocked, TalentManager tm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用空间动态计算 hex 尺寸
        final maxDim = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final hexSize = (maxDim / 6.8).clamp(48.0, 64.0);

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ConstellationPainter(
            nodes: _nodes,
            hexSize: hexSize,
            unlocked: unlocked,
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                for (final node in _nodes)
                  Positioned(
                    left: constraints.maxWidth / 2 +
                        _hexToPixel(node.q, node.r, hexSize).dx -
                        hexSize,
                    top: constraints.maxHeight / 2 +
                        _hexToPixel(node.q, node.r, hexSize).dy -
                        hexSize * 0.87,
                    child: _HexTile(
                      node: node,
                      size: hexSize,
                      unlocked: unlocked,
                      canUnlock: node.talentId != null && _canUnlock(node, unlocked),
                      hasPoints: tm.availablePoints > 0,
                      onTap: () => _onNodeTap(context, node, unlocked, tm),
                    ),
                  ),
                // 中心节点
                Positioned(
                  left: constraints.maxWidth / 2 - hexSize,
                  top: constraints.maxHeight / 2 - hexSize * 0.87,
                  child: _CenterNode(size: hexSize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // 交互
  // ═══════════════════════════════════════════

  void _onNodeTap(BuildContext context, _TalentNode node, Set<TalentId> unlocked, TalentManager tm) {
    final isUnlocked = node.talentId != null && unlocked.contains(node.talentId);
    final canUnlock = node.talentId != null && !isUnlocked && _canUnlock(node, unlocked);

    if (isUnlocked) {
      _showInfo(context, node);
    } else if (canUnlock && tm.availablePoints > 0) {
      _showUnlockConfirm(context, node, tm);
    } else if (node.talentId == null) {
      _toast(context, '暂未开放');
    } else if (!canUnlock) {
      _toast(context, '需先解锁相邻节点');
    } else {
      _toast(context, '天赋点不足');
    }
  }

  void _showInfo(BuildContext context, _TalentNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEE0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Text(node.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(node.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(node.description, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
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
        backgroundColor: const Color(0xEE0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Text(node.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('解锁 ${node.name}', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.description, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text('消耗 1 天赋点', style: TextStyle(color: const Color(0xFFFFD700).withAlpha(200), fontSize: 13)),
              ],
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
                _toast(context, '已解锁 ${node.name}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xCCFFD700),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('确认解锁', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xCC0D1B2A),
        behavior: SnackBarBehavior.floating,
        width: 200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 六边形 Tile Widget
// ═══════════════════════════════════════════

class _HexTile extends StatelessWidget {
  final _TalentNode node;
  final double size;
  final Set<TalentId> unlocked;
  final bool canUnlock;
  final bool hasPoints;
  final VoidCallback onTap;

  const _HexTile({
    required this.node,
    required this.size,
    required this.unlocked,
    required this.canUnlock,
    required this.hasPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = node.talentId != null && unlocked.contains(node.talentId);
    final isPlaceholder = node.talentId == null;

    // 颜色方案
    final Color fill; final Color border; final Color? glow;
    if (isUnlocked) {
      fill = const Color(0xFF1A3A2A);
      border = const Color(0xCC44CC88);
      glow = const Color(0x3344CC88);
    } else if (canUnlock && hasPoints) {
      fill = const Color(0xFF2A2A18);
      border = const Color(0xCCFFD700);
      glow = const Color(0x33FFD700);
    } else if (isPlaceholder) {
      fill = const Color(0x331A1A2A);
      border = const Color(0x22FFFFFF);
      glow = null;
    } else {
      fill = const Color(0xFF141E28);
      border = const Color(0x33FFFFFF);
      glow = null;
    }

    final tileW = size * 1.82;
    final tileH = size * 1.58;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: tileW,
        height: tileH,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 发光晕（底层）
            if (glow != null)
              CustomPaint(
                size: Size(tileW, tileH),
                painter: _HexGlowPainter(size: size, glowColor: glow),
              ),
            // 六边形填充
            CustomPaint(
              size: Size(tileW, tileH),
              painter: _HexShapePainter(size: size, fill: fill, border: border, borderWidth: 1.8),
            ),
            // 内容
            Padding(
              padding: EdgeInsets.only(top: size * 0.1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.icon,
                    style: TextStyle(
                      fontSize: size * 0.32,
                      shadows: isUnlocked
                          ? [const Shadow(color: Color(0x6644FF88), blurRadius: 6)]
                          : null,
                    ),
                  ),
                  if (isUnlocked || (canUnlock && hasPoints) || isPlaceholder)
                    Padding(
                      padding: EdgeInsets.only(top: size * 0.04),
                      child: Text(
                        isPlaceholder ? '???' : node.name,
                        style: TextStyle(
                          color: isUnlocked
                              ? Colors.white
                              : canUnlock
                                  ? const Color(0xFFFFD700)
                                  : Colors.white38,
                          fontSize: size * 0.17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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

// ═══════════════════════════════════════════
// 中心节点
// ═══════════════════════════════════════════

class _CenterNode extends StatelessWidget {
  final double size;
  const _CenterNode({required this.size});

  @override
  Widget build(BuildContext context) {
    final tileW = size * 1.82;
    final tileH = size * 1.58;
    return SizedBox(
      width: tileW,
      height: tileH,
      child: CustomPaint(
        size: Size(tileW, tileH),
        painter: _HexShapePainter(
          size: size,
          fill: const Color(0x220E1B2A),
          border: const Color(0x44FFFFFF),
          borderWidth: 1.2,
        ),
        child: Center(
          child: Text(
            '✦',
            style: TextStyle(
              color: Colors.white.withAlpha(80),
              fontSize: size * 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 六边形形状绘制
// ═══════════════════════════════════════════

class _HexShapePainter extends CustomPainter {
  final double size;
  final Color fill;
  final Color border;
  final double borderWidth;
  _HexShapePainter({
    required this.size,
    required this.fill,
    required this.border,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final path = _hexPath(s.width / 2, s.height / 2, size);
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = borderWidth);
  }

  @override
  bool shouldRepaint(covariant _HexShapePainter old) =>
      old.fill != fill || old.border != border || old.size != size;
}

class _HexGlowPainter extends CustomPainter {
  final double size;
  final Color glowColor;
  _HexGlowPainter({required this.size, required this.glowColor});

  @override
  void paint(Canvas canvas, Size s) {
    final path = _hexPath(s.width / 2, s.height / 2, size * 1.08);
    canvas.drawPath(path, Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }

  @override
  bool shouldRepaint(covariant _HexGlowPainter old) => old.glowColor != glowColor || old.size != size;
}

/// pointy-top 六边形路径
Path _hexPath(double cx, double cy, double r) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = pi / 180 * (60.0 * i - 30.0);
    final x = cx + r * cos(angle);
    final y = cy + r * sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

// ═══════════════════════════════════════════
// 星座连线 Painter
// ═══════════════════════════════════════════

class _ConstellationPainter extends CustomPainter {
  final List<_TalentNode> nodes;
  final double hexSize;
  final Set<TalentId> unlocked;

  _ConstellationPainter({
    required this.nodes,
    required this.hexSize,
    required this.unlocked,
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

    // 外圈装饰环
    final ringPaint = Paint()
      ..color = const Color(0x15FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), hexSize * 3.4, ringPaint);
    canvas.drawCircle(Offset(cx, cy), hexSize * 5.3, ringPaint);

    final linePaint = Paint()..strokeWidth = 1.3..style = PaintingStyle.stroke;
    final glowPaint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final node in nodes) {
      final nodePos = _hexToPixel(node.q, node.r, cx, cy);

      // 连接到中心
      if (_isAdjacent(node.q, node.r, 0, 0)) {
        final connected = node.talentId != null && unlocked.contains(node.talentId);
        if (connected) {
          glowPaint.color = const Color(0x44FFD700);
          canvas.drawLine(Offset(cx, cy), nodePos, glowPaint);
          linePaint.color = const Color(0xAAFFD700);
        } else {
          linePaint.color = const Color(0x18FFFFFF);
        }
        canvas.drawLine(Offset(cx, cy), nodePos, linePaint);
      }

      // 连接到邻居
      for (final other in nodes) {
        if (other == node) continue;
        if (!_isAdjacent(node.q, node.r, other.q, other.r)) continue;
        if (node.q + node.r > other.q + other.r) continue;

        final otherPos = _hexToPixel(other.q, other.r, cx, cy);
        final bothUnlocked = node.talentId != null && unlocked.contains(node.talentId) &&
            other.talentId != null && unlocked.contains(other.talentId);

        if (bothUnlocked) {
          glowPaint.color = const Color(0x44FFD700);
          canvas.drawLine(nodePos, otherPos, glowPaint);
          linePaint.color = const Color(0x88FFD700);
        } else {
          linePaint.color = const Color(0x18FFFFFF);
        }
        canvas.drawLine(nodePos, otherPos, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) =>
      old.unlocked.length != unlocked.length;
}

// ═══════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════

class _TalentNode {
  final int q;
  final int r;
  final TalentId? talentId;
  final String name;
  final String icon;
  final String description;

  const _TalentNode(this.q, this.r, this.talentId, this.name, this.icon, this.description);
}
