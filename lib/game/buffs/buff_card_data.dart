import 'buff_registry.dart';

/// 一组待选的 3 张卡片（用于暂存槽持久化）
class BuffCardSet {
  final List<BuffId> choices;
  BuffCardSet(this.choices);

  BuffMeta meta(int index) => BuffRegistry.data[choices[index]]!;
}
