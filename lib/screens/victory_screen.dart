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

class _VictoryScreenState extends State<VictoryScreen>
    with SingleTickerProviderStateMixin {
  int _stars = 0;
  int _earnedPoints = 0;
  late AnimationController _starAnim;

  @override
  void initState() {
    super.initState();
    // 计算星级
    final hpPercent =
        widget.maxHp > 0 ? widget.hp / widget.maxHp : 0;
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
    final hpPercent = widget.maxHp > 0
        ? (widget.hp / widget.maxHp).clamp(0.0, 1.0)
        : 0.0;

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
              _StatRow(
                label: '剩余血量',
                value: '${widget.hp} / ${widget.maxHp}',
                color: hpPercent > 0.5
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
              _StatRow(label: '击杀数', value: '${widget.kills}'),
              _StatRow(label: '存活波数', value: '${widget.wave} / 15'),
              const SizedBox(height: 8),

              // 获得天赋点
              if (_earnedPoints > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3340),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x88FFD700)),
                  ),
                  child: Text(
                    '⭐ 获得 $_earnedPoints 天赋点',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (_) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A5A4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('返回主菜单',
                    style: TextStyle(fontSize: 16)),
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
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
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
        child: Text('⭐', style: TextStyle(fontSize: size)),
      ),
    );
  }
}
