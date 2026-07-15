import 'package:audioplayers/audioplayers.dart';

/// 全局背景音乐管理器
///
/// 所有 BGM 调用通过 [playBgm] 触发，内部异步执行不阻塞 UI。
/// 同一曲目不会重复播放。
class AudioManager {
  static final AudioManager _instance = AudioManager._();
  static AudioManager get instance => _instance;
  AudioManager._();

  AudioPlayer? _player;
  String? _path;

  /// 统一音量（0.0 ~ 1.0）
  static const double defaultVolume = 0.60;

  /// 当前正在播放的曲目
  String? get currentPath => _path;

  /// 播放背景音乐（非阻塞）
  ///
  /// - [loop] = true → 循环，适合 BGM
  /// - [loop] = false → 单次，适合胜利/失败音乐
  void playBgm(
    String assetPath, {
    bool loop = true,
    double volume = defaultVolume,
  }) {
    // 同一曲目已在播放中 → 跳过
    if (_path == assetPath && _player?.state == PlayerState.playing) return;

    _path = assetPath;

    // 异步执行，绝不阻塞调用方
    _switchTrack(assetPath, loop: loop, volume: volume);
  }

  Future<void> _switchTrack(
    String assetPath, {
    bool loop = true,
    double volume = defaultVolume,
  }) async {
    // 先停旧播放器
    final old = _player;
    _player = null;
    if (old != null) {
      try {
        await old.stop();
        await old.dispose();
      } catch (_) {}
    }

    // 创建新播放器
    final player = AudioPlayer();
    _player = player;

    try {
      await player.play(AssetSource(assetPath), volume: volume);
      if (loop) {
        await player.setReleaseMode(ReleaseMode.loop);
      }
      // 播放成功，确认曲目
      _path = assetPath;
    } catch (_) {
      // 失败静默降级
      await player.dispose();
      _player = null;
      _path = null;
    }
  }

  /// 停止背景音乐
  void stopBgm() {
    _path = null;
    final old = _player;
    _player = null;
    if (old != null) {
      old.stop();
      old.dispose();
    }
  }
}
