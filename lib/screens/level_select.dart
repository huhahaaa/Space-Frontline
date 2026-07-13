import 'package:flutter/material.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2D3A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                        '选择关卡',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _StageCard(
                      stage: 1,
                      title: '初临战火',
                      subtitle: '10 波 · 每波 15s',
                      unlocked: true,
                      onTap: () =>
                          Navigator.pushNamed(context, '/game',
                            arguments: {'backgroundName': 'SpaceBackground.gif'}),

                    ),
                    const SizedBox(height: 12),
                    _StageCard(stage: 2, unlocked: false),
                    const SizedBox(height: 12),
                    _StageCard(stage: 3, unlocked: false),
                    const SizedBox(height: 12),
                    _StageCard(stage: 4, unlocked: false),
                    const SizedBox(height: 12),
                    _StageCard(stage: 5, unlocked: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final int stage;
  final String title;
  final String? subtitle;
  final bool unlocked;
  final VoidCallback? onTap;

  const _StageCard({
    required this.stage,
    this.title = '???',
    this.subtitle,
    required this.unlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFF1A3340)
              : const Color(0xFF0F1F28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked
                ? const Color(0x44FFFFFF)
                : const Color(0x22FFFFFF),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // 关卡编号
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? const Color(0xFF2A5A6A)
                    : const Color(0xFF1A2A30),
                border: Border.all(
                  color: unlocked
                      ? const Color(0x88FFFFFF)
                      : const Color(0x33FFFFFF),
                ),
              ),
              child: Center(
                child: Text(
                  unlocked ? '$stage' : '🔒',
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white38,
                    fontSize: unlocked ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 关卡信息
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '第$stage关',
                    style: TextStyle(
                      color: unlocked ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unlocked ? title : '敬请期待',
                    style: TextStyle(
                      color: unlocked ? Colors.white70 : Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                  if (subtitle != null && unlocked) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (unlocked)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}
