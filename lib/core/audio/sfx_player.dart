import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sfx.dart';

final sfxPlayerProvider = Provider<SfxPlayer>((ref) {
  final player = SfxPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Plays synthesized [Sfx] tones through a small round-robin pool of
/// [AudioPlayer]s so overlapping effects (e.g. rapid coin pickups) don't cut
/// each other off. Every call is fire-and-forget and failures are swallowed
/// — a missing audio device should never crash gameplay.
class SfxPlayer {
  SfxPlayer({int poolSize = 4})
      : _pool = List.generate(poolSize, (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop));

  final List<AudioPlayer> _pool;
  int _next = 0;

  void play(Sfx sfx, {required bool enabled}) {
    if (!enabled) return;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    final bytes = SfxLibrary.bytesFor(sfx);
    player.play(BytesSource(bytes, mimeType: 'audio/wav')).catchError((_) {});
  }

  Future<void> dispose() async {
    for (final player in _pool) {
      await player.dispose();
    }
  }
}
