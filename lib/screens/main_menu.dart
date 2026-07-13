import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 星空背景底图
          Image.asset(
            'assets/images/Space Background_3.png',
            fit: BoxFit.cover,
          ),
          // 星球 GIF — 仅上半部分可见
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Image.asset(
              'assets/images/Planet2.gif',
              fit: BoxFit.cover,
            ),
          ),
          // 菜单内容
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Space Frontline',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 14,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _MenuButton(
                    icon: '⚔️',
                    label: '开始游戏',
                    onTap: () => Navigator.pushNamed(context, '/levelSelect'),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    icon: '📖',
                    label: '怪物图鉴',
                    onTap: () => Navigator.pushNamed(context, '/monsterpedia'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3340),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x44FFFFFF)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
