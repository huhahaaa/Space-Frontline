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
    _TalentNode(0, -1, TalentId.reinforcedArmor, '城墙加固', '🏰', '城墙初始耐久 +20'),
    _TalentNode(1, -1, TalentId.expandedChoices, '选择扩充', '📋', '升级时 buff 选择 3→4 张'),
    _TalentNode(1, 0, TalentId.expDrain, '经验汲取', '📊', '每波额外 +10 经验'),
    _TalentNode(0, 1, TalentId.freeReroll, '重抽机会', '🔄', '每局可免费重抽 buff 1 次'),
    _TalentNode(-1, 0, null, '', '🔒', '暂未开放'),
    _TalentNode(-1, 1, null, '', '🔒', '暂未开放'),
    _TalentNode(0, -2, null, '', '🔒', '暂未开放'),
    _TalentNode(2, -1, null, '', '🔒', '暂未开放'),
    _TalentNode(2, 0, null, '', '🔒', '暂未开放'),
    _TalentNode(0, 2, null, '', '🔒', '暂未开放'),
    _TalentNode(-2, 1, null, '', '🔒', '暂未开放'),
    _TalentNode(-2, 0, null, '', '🔒', '暂未开放'),
  ];

  Offset _hexToPixel(int q, int r, double size) {
    return Offset(size * 1.5 * q, size * (sqrt(3) / 2 * q + sqrt(3) * r));
  }

  bool _isAdjacent(int q1, int r1, int q2, int r2) {
    final dq = q1 - q2, dr = r1 - r2;
    return (dq == 1 && dr == 0) || (dq == 1 && dr == -1) ||
        (dq == 0 && dr == -1) || (dq == -1 && dr == 0) ||
        (dq == -1 && dr == 1) || (dq == 0 && dr == 1);
  }

  bool _canUnlock(_TalentNode node, Set<TalentId> unlocked) {
    if (_isAdjacent(node.q, node.r, 0, 0)) return true;
    for (final other in _nodes) {
      if (other.talentId == null || !unlocked.contains(other.talentId)) continue;
      if (_isAdjacent(node.q, node.r, other.q, other.r)) return true;
    }
    return false;
  }

  // ── 根据屏宽计算六边形半径 ──
  static double _calcHexSize(double screenWidth, double gridHeight) {
    // 网格宽度：q ∈ [-2, 2]，跨度 4 步，每步 1.5*size，再加上一个六边形的"外溢"
    // → 总占宽 ≈ 4 * 1.5 * size + (sqrt(3) ≈ 1.732) * size ≈ 7.732 * size
    // 留 8% 边距 → size = screenWidth * 0.92 / 7.732
    final byWidth = screenWidth * 0.92 / 7.732;
    // 网格高度：r ∈ [-2, 2]，跨度 4 步，每步 sqrt(3)*size，加外溢
    // → 总占高 ≈ 5 * sqrt(3) * size ≈ 8.66 * size
    // 顶部栏+徽章约占 100px，留 6% 边距
    final availH = gridHeight * 0.88;
    final byHeight = availH / 8.66;
    return min(byWidth, byHeight).clamp(36.0, 62.0);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // 网格可用高度：扣除顶部栏(~44px)、徽章(~36px)、提示(~24px)、safe area
    final gridHeight = screen.height - safeTop - safeBottom - 110;

    final hexSize = _calcHexSize(screen.width, gridHeight);
    final sp = _ScaledText(hexSize); // 统一文字缩放

    final tm = TalentManager.instance;
    final unlocked = <TalentId>{};
    for (final id in TalentId.values) {
      if (tm.isUnlocked(id)) unlocked.add(id);
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/Space Background_2.png', fit: BoxFit.cover),
          Container(color: Colors.black.withAlpha(40)),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(sp),
                const SizedBox(height: 2),
                _buildPointBadge(tm.availablePoints, sp),
                const SizedBox(height: 4),
                Text('点击相邻节点解锁天赋',
                    style: TextStyle(color: Colors.white.withAlpha(130), fontSize: sp.hint)),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: _buildHexGrid(unlocked, tm, hexSize, sp,
                        screen.width, gridHeight),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(_ScaledText sp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sp.padH, vertical: 2),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: sp.tapTarget, minHeight: sp.tapTarget),
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: sp.backIcon),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text('天赋星图', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: sp.title, fontWeight: FontWeight.w500, letterSpacing: sp.titleSpacing)),
          ),
          SizedBox(width: sp.tapTarget),
        ],
      ),
    );
  }

  Widget _buildPointBadge(int points, _ScaledText sp) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: sp.badgePadH, vertical: sp.badgePadV),
      decoration: BoxDecoration(
        color: const Color(0xCC0D1B2A),
        borderRadius: BorderRadius.circular(sp.badgeRadius),
        border: Border.all(color: const Color(0xAAFFD700), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withAlpha(50), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⭐', style: TextStyle(fontSize: sp.badgeText)),
          const SizedBox(width: 6),
          Text('$points', style: TextStyle(color: const Color(0xFFFFD700), fontSize: sp.badgeText, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ═══════════════════════════════ 网格 ═══════════════════════════════

  Widget _buildHexGrid(Set<TalentId> unlocked, TalentManager tm,
      double hexSize, _ScaledText sp, double screenW, double gridH) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ConstellationPainter(
            nodes: _nodes, hexSize: hexSize, unlocked: unlocked,
            maxW: constraints.maxWidth, maxH: constraints.maxHeight,
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                for (final node in _nodes)
                  Positioned(
                    left: constraints.maxWidth / 2 +
                        _hexToPixel(node.q, node.r, hexSize).dx - hexSize,
                    top: constraints.maxHeight / 2 +
                        _hexToPixel(node.q, node.r, hexSize).dy -
                        hexSize * 0.87,
                    child: _HexTile(
                      node: node, size: hexSize, sp: sp,
                      unlocked: unlocked,
                      canUnlock: node.talentId != null && _canUnlock(node, unlocked),
                      hasPoints: tm.availablePoints > 0,
                      onTap: () => _onNodeTap(context, node, unlocked, tm, sp),
                    ),
                  ),
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

  // ═══════════════════════════════ 交互 ═══════════════════════════════

  void _onNodeTap(BuildContext context, _TalentNode node,
      Set<TalentId> unlocked, TalentManager tm, _ScaledText sp) {
    final isUnlocked = node.talentId != null && unlocked.contains(node.talentId);
    final canUnlock = node.talentId != null && !isUnlocked && _canUnlock(node, unlocked);

    if (isUnlocked) {
      _showInfo(context, node, sp);
    } else if (canUnlock && tm.availablePoints > 0) {
      _showUnlockConfirm(context, node, tm, sp);
    } else if (node.talentId == null) {
      _toast(context, '暂未开放', Colors.white54, sp);
    } else if (!canUnlock) {
      _toast(context, '需先解锁相邻节点', Colors.orangeAccent, sp);
    } else {
      _toast(context, '天赋点不足', const Color(0xFFFF4444), sp);
    }
  }

  void _showInfo(BuildContext context, _TalentNode node, _ScaledText sp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF0111D2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x44FFFFFF))),
        title: Row(children: [
          Text(node.icon, style: TextStyle(fontSize: sp.dialogIcon)),
          const SizedBox(width: 10),
          Text(node.name, style: TextStyle(color: Colors.white, fontSize: sp.dialogTitle)),
        ]),
        content: Text(node.description,
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: sp.dialogBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定', style: TextStyle(color: Colors.cyanAccent, fontSize: sp.dialogBtn)),
          ),
        ],
      ),
    );
  }

  void _showUnlockConfirm(BuildContext context, _TalentNode node, TalentManager tm, _ScaledText sp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF0111D2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xAAFFD700))),
        title: Row(children: [
          Text(node.icon, style: TextStyle(fontSize: sp.dialogIcon)),
          const SizedBox(width: 10),
          Text('解锁 ${node.name}', style: TextStyle(color: Colors.white, fontSize: sp.dialogTitle)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(node.description, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: sp.dialogBody)),
          const SizedBox(height: 12),
          Row(children: [
            Text('⭐', style: TextStyle(fontSize: sp.dialogBody)),
            const SizedBox(width: 4),
            Text('消耗 1 天赋点',
                style: TextStyle(color: const Color(0xFFFFD700).withAlpha(230),
                    fontSize: sp.dialogBody, fontWeight: FontWeight.w600)),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: Colors.white54, fontSize: sp.dialogBtn)),
          ),
          ElevatedButton(
            onPressed: () {
              final ok = tm.unlock(node.talentId!);
              Navigator.pop(ctx);
              if (ok) { setState(() {}); _toast(context, '已解锁 ${node.name}', const Color(0xFF44CC88), sp); }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('确认解锁', style: TextStyle(fontSize: sp.dialogBtn, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg, Color color, _ScaledText sp) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: sp.toastText, fontWeight: FontWeight.w600)),
      duration: const Duration(seconds: 1),
      backgroundColor: const Color(0xF01A2A3A),
      behavior: SnackBarBehavior.floating,
      width: sp.toastWidth,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// 自适应文字尺寸
// ═══════════════════════════════════════════════════════════

class _ScaledText {
  final double hexSize;
  const _ScaledText(this.hexSize);

  double get title => (hexSize * 0.28).clamp(12.0, 16.0);
  double get titleSpacing => (hexSize * 0.07).clamp(2.5, 4.5);
  double get backIcon => (hexSize * 0.33).clamp(15.0, 20.0);
  double get tapTarget => (hexSize * 0.7).clamp(32.0, 44.0);
  double get padH => (hexSize * 0.08).clamp(3.0, 6.0);

  double get badgeText => (hexSize * 0.28).clamp(11.0, 16.0);
  double get badgePadH => (hexSize * 0.28).clamp(12.0, 18.0);
  double get badgePadV => (hexSize * 0.10).clamp(4.0, 7.0);
  double get badgeRadius => (hexSize * 0.26).clamp(10.0, 16.0);

  double get hint => (hexSize * 0.19).clamp(8.0, 11.0);

  double get tileIcon => hexSize * 0.32;
  double get tileName => hexSize * 0.17;

  double get dialogIcon => (hexSize * 0.40).clamp(18.0, 24.0);
  double get dialogTitle => (hexSize * 0.30).clamp(13.0, 17.0);
  double get dialogBody => (hexSize * 0.24).clamp(11.0, 14.0);
  double get dialogBtn => (hexSize * 0.24).clamp(11.0, 14.0);

  double get toastText => (hexSize * 0.24).clamp(10.0, 14.0);
  double get toastWidth => (hexSize * 4.2).clamp(170.0, 260.0);
}

// ═══════════════════════════════════════════════════════════
// 六边形 Tile
// ═══════════════════════════════════════════════════════════

class _HexTile extends StatelessWidget {
  final _TalentNode node;
  final double size;
  final _ScaledText sp;
  final Set<TalentId> unlocked;
  final bool canUnlock;
  final bool hasPoints;
  final VoidCallback onTap;

  const _HexTile({
    required this.node, required this.size, required this.sp,
    required this.unlocked, required this.canUnlock,
    required this.hasPoints, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = node.talentId != null && unlocked.contains(node.talentId);
    final isPlaceholder = node.talentId == null;

    final Color fill; final Color border; final Color? glow;
    if (isUnlocked) {
      fill = const Color(0xFF1B4A35); border = const Color(0xFF55DD88); glow = const Color(0x5555DD88);
    } else if (canUnlock && hasPoints) {
      fill = const Color(0xFF3A2E0E); border = const Color(0xFFFFD700); glow = const Color(0x55FFD700);
    } else if (canUnlock && !hasPoints) {
      fill = const Color(0xFF2A1E0E); border = const Color(0xBBFFD700); glow = const Color(0x22FFD700);
    } else if (isPlaceholder) {
      fill = const Color(0x44121824); border = const Color(0x44FFFFFF); glow = null;
    } else {
      fill = const Color(0xFF141E28); border = const Color(0x55FFFFFF); glow = null;
    }

    final tileW = size * 1.82;
    final tileH = size * 1.58;
    final bw = (size * 0.036).clamp(1.5, 2.5);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: tileW, height: tileH,
        child: Stack(alignment: Alignment.center, children: [
          if (glow != null)
            CustomPaint(size: Size(tileW, tileH),
                painter: _HexGlowPainter(size: size, glowColor: glow)),
          CustomPaint(size: Size(tileW, tileH),
              painter: _HexShapePainter(size: size, fill: fill, border: border, borderWidth: bw)),
          Padding(
            padding: EdgeInsets.only(top: size * 0.1),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(node.icon, style: TextStyle(fontSize: sp.tileIcon,
                  shadows: isUnlocked ? [Shadow(color: const Color(0x8855FF88), blurRadius: size * 0.15)]
                      : (canUnlock && hasPoints) ? [Shadow(color: const Color(0x88FFD700), blurRadius: size * 0.15)] : null)),
              if (isUnlocked || canUnlock || isPlaceholder)
                Padding(
                  padding: EdgeInsets.only(top: size * 0.04),
                  child: Text(isPlaceholder ? '???' : node.name,
                      style: TextStyle(
                          color: isUnlocked ? Colors.white : canUnlock ? const Color(0xFFFFD700) : Colors.white60,
                          fontSize: sp.tileName, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════ 中心 ═══════════════════════════════

class _CenterNode extends StatelessWidget {
  final double size;
  const _CenterNode({required this.size});

  @override
  Widget build(BuildContext context) {
    final tileW = size * 1.82;
    final tileH = size * 1.58;
    return SizedBox(width: tileW, height: tileH,
      child: CustomPaint(
        size: Size(tileW, tileH),
        painter: _HexShapePainter(size: size, fill: const Color(0x55182532),
            border: const Color(0x77FFFFFF), borderWidth: 1.5),
        child: Center(child: Text('✦',
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: size * 0.35))),
      ),
    );
  }
}

// ═══════════════════════════════ 绘制 ═══════════════════════════════

class _HexShapePainter extends CustomPainter {
  final double size; final Color fill; final Color border; final double borderWidth;
  _HexShapePainter({required this.size, required this.fill, required this.border, required this.borderWidth});

  @override
  void paint(Canvas canvas, Size s) {
    final path = _hexPath(s.width / 2, s.height / 2, size);
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()
      ..color = border..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _HexShapePainter old) =>
      old.fill != fill || old.border != border || old.size != size;
}

class _HexGlowPainter extends CustomPainter {
  final double size; final Color glowColor;
  _HexGlowPainter({required this.size, required this.glowColor});

  @override
  void paint(Canvas canvas, Size s) {
    final path = _hexPath(s.width / 2, s.height / 2, size * 1.05);
    canvas.drawPath(path, Paint()
      ..color = glowColor..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.25));
  }

  @override
  bool shouldRepaint(covariant _HexGlowPainter old) => old.glowColor != glowColor || old.size != size;
}

Path _hexPath(double cx, double cy, double r) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = pi / 180 * (60.0 * i - 30.0);
    (i == 0) ? path.moveTo(cx + r * cos(angle), cy + r * sin(angle))
             : path.lineTo(cx + r * cos(angle), cy + r * sin(angle));
  }
  path.close();
  return path;
}

// ═══════════════════════════════ 连线 ═══════════════════════════════

class _ConstellationPainter extends CustomPainter {
  final List<_TalentNode> nodes; final double hexSize;
  final Set<TalentId> unlocked; final double maxW; final double maxH;

  _ConstellationPainter({
    required this.nodes, required this.hexSize, required this.unlocked,
    required this.maxW, required this.maxH,
  });

  Offset _hexToPixel(int q, int r, double cx, double cy) {
    return Offset(cx + hexSize * 1.5 * q,
                  cy + hexSize * (sqrt(3) / 2 * q + sqrt(3) * r));
  }

  bool _isAdjacent(int q1, int r1, int q2, int r2) {
    final dq = q1 - q2, dr = r1 - r2;
    return (dq == 1 && dr == 0) || (dq == 1 && dr == -1) ||
        (dq == 0 && dr == -1) || (dq == -1 && dr == 0) ||
        (dq == -1 && dr == 1) || (dq == 0 && dr == 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 装饰环 — 半径不超过可视区域
    final ringPaint = Paint()
      ..color = const Color(0x30FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final r1 = min(hexSize * 3.4, min(cx, cy) * 0.95);
    final r2 = min(hexSize * 5.3, min(cx, cy) * 0.95);
    if (r1 > 0) canvas.drawCircle(Offset(cx, cy), r1, ringPaint);
    if (r2 > r1 + 10) canvas.drawCircle(Offset(cx, cy), r2, ringPaint);

    final linePaint = Paint()..strokeWidth = (hexSize * 0.028).clamp(1.0, 1.8)..style = PaintingStyle.stroke;
    final glowPaint = Paint()
      ..strokeWidth = (hexSize * 0.072).clamp(3.0, 5.0)
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, hexSize * 0.09);

    for (final node in nodes) {
      final nodePos = _hexToPixel(node.q, node.r, cx, cy);

      if (_isAdjacent(node.q, node.r, 0, 0)) {
        final connected = node.talentId != null && unlocked.contains(node.talentId);
        if (connected) {
          glowPaint.color = const Color(0x55FFD700);
          canvas.drawLine(Offset(cx, cy), nodePos, glowPaint);
          linePaint.color = const Color(0xBBFFD700);
        } else {
          linePaint.color = const Color(0x35FFFFFF);
        }
        canvas.drawLine(Offset(cx, cy), nodePos, linePaint);
      }

      for (final other in nodes) {
        if (other == node) continue;
        if (!_isAdjacent(node.q, node.r, other.q, other.r)) continue;
        if (node.q + node.r > other.q + other.r) continue;

        final otherPos = _hexToPixel(other.q, other.r, cx, cy);
        final both = node.talentId != null && unlocked.contains(node.talentId) &&
                     other.talentId != null && unlocked.contains(other.talentId);
        if (both) {
          glowPaint.color = const Color(0x55FFD700);
          canvas.drawLine(nodePos, otherPos, glowPaint);
          linePaint.color = const Color(0xAAFFD700);
        } else {
          linePaint.color = const Color(0x35FFFFFF);
        }
        canvas.drawLine(nodePos, otherPos, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) =>
      old.unlocked.length != unlocked.length;
}

// ═══════════════════════════════ 模型 ═══════════════════════════════

class _TalentNode {
  final int q, r;
  final TalentId? talentId;
  final String name, icon, description;
  const _TalentNode(this.q, this.r, this.talentId, this.name, this.icon, this.description);
}
