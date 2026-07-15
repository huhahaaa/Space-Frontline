import 'package:flutter/material.dart';
import '../../game/items/item_data.dart';

class ItemBar extends StatelessWidget {
  final List<ItemId> items;
  final void Function(int index) onTap;
  final void Function(int index)? onLongPress;

  const ItemBar({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
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
              onTap: i < items.length ? () => onTap(i) : null,
              onLongPress: i < items.length && onLongPress != null
                  ? () => onLongPress!(i)
                  : null,
              child: _buildSlot(i),
            ),
          ),
      ],
    );
  }

  Widget _buildSlot(int index) {
    final hasItem = index < items.length;

    if (!hasItem) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Center(
          child: Text(
            '○',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.12),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final meta = ItemRegistry.data[items[index]]!;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: meta.color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(meta.icon, style: const TextStyle(fontSize: 17)),
          Text(
            meta.name,
            style: TextStyle(
              color: meta.color.withValues(alpha: 0.9),
              fontSize: 7,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
