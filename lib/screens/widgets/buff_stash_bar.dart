import 'package:flutter/material.dart';
import '../../game/buffs/buff_registry.dart';

class BuffStashBar extends StatelessWidget {
  final List<List<BuffId>> stash;
  final Map<BuffId, int> activeBuffs;
  final void Function(int index) onTap;

  const BuffStashBar({
    super.key,
    required this.stash,
    required this.activeBuffs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? 4 : 0),
            child: GestureDetector(
              onTap: i < stash.length ? () => onTap(i) : null,
              child: _buildSlot(i),
            ),
          ),
      ],
    );
  }

  Widget _buildSlot(int index) {
    final hasEntry = index < stash.length;

    if (!hasEntry) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Text(
            '○',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.15),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final firstId = stash[index].first;
    final meta = BuffRegistry.data[firstId]!;
    final color = Color(BuffRegistry.elementColor(meta.element));

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Center(
        child: Text(meta.icon, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
