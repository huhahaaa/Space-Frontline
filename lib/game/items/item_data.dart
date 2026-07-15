import 'dart:math';
import 'package:flutter/material.dart';

/// 局内道具 ID
enum ItemId {
  nanoRepair,
  cryoBomb,
  overchargeCore,
  orbitalStrike,
  timeWarp,
}

/// 道具元数据
class ItemMeta {
  final ItemId id;
  final String name;
  final String icon;
  final String description;
  final Color color;

  const ItemMeta({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
  });
}

/// 道具注册表
class ItemRegistry {
  ItemRegistry._();

  static const Map<ItemId, ItemMeta> data = {
    ItemId.nanoRepair: ItemMeta(
      id: ItemId.nanoRepair,
      name: '纳米修复',
      icon: '🩹',
      description: '恢复炮塔 30% HP',
      color: Color(0xFF4CAF50),
    ),
    ItemId.cryoBomb: ItemMeta(
      id: ItemId.cryoBomb,
      name: '急冻炸弹',
      icon: '❄️',
      description: '冻结全屏敌人 3 秒',
      color: Color(0xFF64B5F6),
    ),
    ItemId.overchargeCore: ItemMeta(
      id: ItemId.overchargeCore,
      name: '超载核心',
      icon: '⚡',
      description: '炮塔攻速翻倍，持续 6 秒',
      color: Color(0xFFFFD740),
    ),
    ItemId.orbitalStrike: ItemMeta(
      id: ItemId.orbitalStrike,
      name: '轨道打击',
      icon: '🛰️',
      description: '手动瞄准，点击屏幕选择位置，1.5 秒后造成 50 范围伤害',
      color: Color(0xFFFF7043),
    ),
    ItemId.timeWarp: ItemMeta(
      id: ItemId.timeWarp,
      name: '时空扭曲',
      icon: '🌀',
      description: '全屏敌人减速 70%，持续 4 秒',
      color: Color(0xFFAB47BC),
    ),
  };

  /// 随机获取一个道具 ID
  static ItemId randomId() {
    final list = ItemId.values;
    return list[Random().nextInt(list.length)];
  }
}
