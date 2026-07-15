/// 精英特征 — 所有精英敌人（沃土、护士、惊雷）混入此 mixin
///
/// 用于统一判断：`enemy is EliteTrait` 替代
/// `enemy is EliteEnemy || enemy is NurseEnemy || enemy is JingLeiEnemy`
mixin EliteTrait {}
