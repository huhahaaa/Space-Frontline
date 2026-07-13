import 'package:flutter/material.dart';
import '../../game/buffs/buff_registry.dart';

class BuffCardOverlay extends StatelessWidget {
  final List<BuffId> choices;
  final Map<BuffId, int> currentLevels;
  final void Function(BuffId id) onSelected;
  final VoidCallback onSkip;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '⬆ LEVEL UP! ⬆',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < choices.length; i++) ...[
              _buildCard(context, choices[i]),
              if (i < choices.length - 1) const SizedBox(height: 12),
            ],
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
            const SizedBox(height: 24),
            TextButton(
              onPressed: onSkip,
              child: const Text(
                '跳过本次 →',
                style: TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, BuffId id) {
    final meta = BuffRegistry.data[id]!;
    final currentLv = currentLevels[id] ?? 0;
    final nextLv = currentLv + 1;
    final levelMeta = meta.level(nextLv);
    final color = Color(BuffRegistry.elementColor(meta.element));

    String levelLabel;
    if (currentLv == 0) {
      levelLabel = 'NEW';
    } else if (nextLv >= meta.maxLevel) {
      levelLabel = 'MAX';
    } else {
      levelLabel = 'Lv.$currentLv→$nextLv';
    }

    return GestureDetector(
      onTap: () => onSelected(id),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3340),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(meta.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        meta.name,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          levelLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    levelMeta.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
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
