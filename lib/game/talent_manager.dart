import 'package:shared_preferences/shared_preferences.dart';

/// 天赋标识枚举
enum TalentId {
  reinforcedArmor,   // 加固装甲：初始血量 +20
  expandedChoices,   // 选择扩充：buff 选择 3→4
  expDrain,          // 经验汲取：每波额外 +10 经验
  freeReroll,        // 重抽机会：每局 1 次免费重抽
}

/// 天赋管理器（单例）
class TalentManager {
  static TalentManager? _instance;
  static TalentManager get instance {
    _instance ??= TalentManager._();
    return _instance!;
  }

  TalentManager._();

  SharedPreferences? _prefs;
  int _availablePoints = 0;
  final Set<TalentId> _unlocked = {};

  // 每局重抽追踪（不持久化）
  int _freeRerollsRemaining = 0;

  // ─── 初始化 ───

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // 首次运行默认给 1 天赋点（方便测试）
    if (_prefs!.getInt('talent_points') == null) {
      _availablePoints = 1;
      await _prefs!.setInt('talent_points', 1);
    } else {
      _availablePoints = _prefs!.getInt('talent_points')!;
    }
    final unlockedStr = _prefs!.getString('talent_unlocked') ?? '';
    if (unlockedStr.isNotEmpty) {
      for (final s in unlockedStr.split(',')) {
        final idx = int.tryParse(s);
        if (idx != null && idx >= 0 && idx < TalentId.values.length) {
          _unlocked.add(TalentId.values[idx]);
        }
      }
    }
  }

  // ─── 查询 ───

  bool isUnlocked(TalentId id) => _unlocked.contains(id);
  int get availablePoints => _availablePoints;

  // ─── 解锁 ───

  bool unlock(TalentId id) {
    if (_availablePoints <= 0 || _unlocked.contains(id)) return false;
    _unlocked.add(id);
    _availablePoints--;
    _save();
    return true;
  }

  // ─── 取消解锁 ───

  bool cancelUnlock(TalentId id) {
    if (!_unlocked.contains(id)) return false;
    _unlocked.remove(id);
    _availablePoints++;
    _save();
    return true;
  }

  // ─── 星级结算 ───

  int getStarsForLevel(String levelId) {
    return _prefs?.getInt('level_stars_$levelId') ?? 0;
  }

  /// 尝试更新星级，返回本次是否获得天赋点
  Future<bool> setStarsForLevel(String levelId, int newStars) async {
    final oldStars = getStarsForLevel(levelId);
    if (newStars <= oldStars) return false;
    final earned = newStars - oldStars;
    await _prefs?.setInt('level_stars_$levelId', newStars);
    _availablePoints += earned;
    await _prefs?.setInt('talent_points', _availablePoints);
    return true;
  }

  // ─── 持久化 ───

  void _save() {
    _prefs?.setInt('talent_points', _availablePoints);
    final indices = _unlocked.map((e) => e.index.toString()).join(',');
    _prefs?.setString('talent_unlocked', indices);
  }

  // ═══════════════════════════════════════════
  // 天赋效果查询
  // ═══════════════════════════════════════════

  int get bonusHp => _unlocked.contains(TalentId.reinforcedArmor) ? 20 : 0;
  int get buffChoiceCount => _unlocked.contains(TalentId.expandedChoices) ? 4 : 3;
  int get bonusExpPerWave => _unlocked.contains(TalentId.expDrain) ? 10 : 0;
  int get freeRerollsPerGame => _unlocked.contains(TalentId.freeReroll) ? 1 : 0;

  // ─── 每局重抽 ───

  int get rerollsRemaining => _freeRerollsRemaining;

  void startGame() {
    _freeRerollsRemaining = freeRerollsPerGame;
  }

  bool useReroll() {
    if (_freeRerollsRemaining <= 0) return false;
    _freeRerollsRemaining--;
    return true;
  }
}
