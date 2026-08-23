import 'dart:typed_data';

import 'tone_synth.dart';

/// Every distinct sound effect used across the app's five games plus the
/// shared hub/menu chrome. Keeping this as one enum (rather than one per
/// game) means a "coin" or "tap" always sounds identical everywhere.
enum Sfx {
  tap,
  select,
  confirm,
  back,
  coin,
  score,
  jump,
  swipe,
  hit,
  damage,
  shieldUp,
  powerUp,
  kick,
  goal,
  save,
  miss,
  crash,
  explosion,
  levelUp,
  win,
  lose,
  countdown,
}

/// Lazily synthesizes and caches the WAV bytes for each [Sfx] so every
/// sound is only rendered once per app run.
abstract final class SfxLibrary {
  static final Map<Sfx, Uint8List> _cache = {};

  static Uint8List bytesFor(Sfx sfx) {
    return _cache.putIfAbsent(sfx, () => ToneSynth.render(_definitions[sfx]!));
  }

  static final Map<Sfx, List<Tone>> _definitions = {
    Sfx.tap: const [Tone(freq: 720, ms: 35, wave: Waveform.square, volume: 0.25)],
    Sfx.select: const [
      Tone(freq: 520, endFreq: 780, ms: 60, wave: Waveform.square, volume: 0.3),
    ],
    Sfx.confirm: const [
      Tone(freq: 600, ms: 55, wave: Waveform.square, volume: 0.32),
      Tone(freq: 900, ms: 90, wave: Waveform.square, volume: 0.32),
    ],
    Sfx.back: const [
      Tone(freq: 500, endFreq: 300, ms: 70, wave: Waveform.square, volume: 0.28),
    ],
    Sfx.coin: const [
      Tone(freq: 988, ms: 55, wave: Waveform.square, volume: 0.35),
      Tone(freq: 1319, ms: 110, wave: Waveform.square, volume: 0.35),
    ],
    Sfx.score: const [
      Tone(freq: 880, ms: 45, wave: Waveform.triangle, volume: 0.3),
      Tone(freq: 1175, ms: 70, wave: Waveform.triangle, volume: 0.3),
    ],
    Sfx.jump: const [
      Tone(freq: 320, endFreq: 640, ms: 110, wave: Waveform.sawtooth, volume: 0.3),
    ],
    Sfx.swipe: const [
      Tone(freq: 900, endFreq: 220, ms: 90, wave: Waveform.noise, volume: 0.18),
    ],
    Sfx.hit: const [
      Tone(freq: 160, endFreq: 60, ms: 90, wave: Waveform.square, volume: 0.4),
    ],
    Sfx.damage: const [
      Tone(freq: 220, endFreq: 80, ms: 160, wave: Waveform.sawtooth, volume: 0.4),
      Tone(freq: 90, ms: 90, wave: Waveform.noise, volume: 0.22),
    ],
    Sfx.shieldUp: const [
      Tone(freq: 440, endFreq: 880, ms: 130, wave: Waveform.sine, volume: 0.3),
    ],
    Sfx.powerUp: const [
      Tone(freq: 523, ms: 60, wave: Waveform.square, volume: 0.3),
      Tone(freq: 659, ms: 60, wave: Waveform.square, volume: 0.3),
      Tone(freq: 784, ms: 60, wave: Waveform.square, volume: 0.3),
      Tone(freq: 1047, ms: 100, wave: Waveform.square, volume: 0.32),
    ],
    Sfx.kick: const [
      Tone(freq: 200, endFreq: 500, ms: 70, wave: Waveform.triangle, volume: 0.35),
      Tone(freq: 700, endFreq: 120, ms: 70, wave: Waveform.noise, volume: 0.2),
    ],
    Sfx.goal: const [
      Tone(freq: 659, ms: 90, wave: Waveform.square, volume: 0.34),
      Tone(freq: 880, ms: 90, wave: Waveform.square, volume: 0.34),
      Tone(freq: 1319, ms: 180, wave: Waveform.square, volume: 0.36),
    ],
    Sfx.save: const [
      Tone(freq: 300, endFreq: 140, ms: 160, wave: Waveform.sawtooth, volume: 0.32),
    ],
    Sfx.miss: const [
      Tone(freq: 260, endFreq: 160, ms: 140, wave: Waveform.triangle, volume: 0.3),
    ],
    Sfx.crash: const [
      Tone(freq: 150, ms: 130, wave: Waveform.noise, volume: 0.42),
      Tone(freq: 90, endFreq: 40, ms: 160, wave: Waveform.sawtooth, volume: 0.38),
    ],
    Sfx.explosion: const [
      Tone(freq: 120, ms: 90, wave: Waveform.noise, volume: 0.45),
      Tone(freq: 70, endFreq: 30, ms: 220, wave: Waveform.sawtooth, volume: 0.4),
    ],
    Sfx.levelUp: const [
      Tone(freq: 523, ms: 70, wave: Waveform.square, volume: 0.32),
      Tone(freq: 659, ms: 70, wave: Waveform.square, volume: 0.32),
      Tone(freq: 784, ms: 70, wave: Waveform.square, volume: 0.32),
      Tone(freq: 1047, ms: 70, wave: Waveform.square, volume: 0.32),
      Tone(freq: 1319, ms: 140, wave: Waveform.square, volume: 0.36),
    ],
    Sfx.win: const [
      Tone(freq: 659, ms: 90, wave: Waveform.square, volume: 0.34),
      Tone(freq: 831, ms: 90, wave: Waveform.square, volume: 0.34),
      Tone(freq: 988, ms: 90, wave: Waveform.square, volume: 0.34),
      Tone(freq: 1319, ms: 220, wave: Waveform.square, volume: 0.38),
    ],
    Sfx.lose: const [
      Tone(freq: 392, ms: 120, wave: Waveform.sawtooth, volume: 0.32),
      Tone(freq: 330, ms: 120, wave: Waveform.sawtooth, volume: 0.32),
      Tone(freq: 262, ms: 220, wave: Waveform.sawtooth, volume: 0.34),
    ],
    Sfx.countdown: const [
      Tone(freq: 440, ms: 80, wave: Waveform.square, volume: 0.3),
    ],
  };
}
