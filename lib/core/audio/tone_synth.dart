import 'dart:math' as math;
import 'dart:typed_data';

enum Waveform { sine, square, triangle, sawtooth, noise }

/// One synthesized note: a frequency sweep from [freq] to [endFreq] (or a
/// flat tone when they match), rendered as [wave] for [ms] milliseconds at
/// [volume] (0..1). A short linear fade-in/out is always applied so notes
/// never click when concatenated back to back.
class Tone {
  const Tone({
    required this.freq,
    double? endFreq,
    required this.ms,
    this.wave = Waveform.square,
    this.volume = 0.5,
  }) : endFreq = endFreq ?? freq;

  final double freq;
  final double endFreq;
  final int ms;
  final Waveform wave;
  final double volume;
}

/// Renders short sequences of [Tone]s into 16-bit PCM mono WAV byte arrays,
/// purely in Dart. This is how every sound effect in the app is produced —
/// there are no bundled audio assets, so simple retro/chiptune-style blips
/// are synthesized on demand and cached by the caller.
abstract final class ToneSynth {
  static const sampleRate = 22050;

  static Uint8List render(List<Tone> tones) {
    final samples = <int>[];
    final rnd = math.Random(1);

    for (final tone in tones) {
      final sampleCount = (sampleRate * tone.ms / 1000).round();
      final fadeSamples = math.min(sampleCount ~/ 8, (sampleRate * 0.006).round());
      var phase = 0.0;

      for (var i = 0; i < sampleCount; i++) {
        final t = i / sampleCount;
        final freq = tone.freq + (tone.endFreq - tone.freq) * t;
        phase += freq / sampleRate;
        if (phase >= 1) phase -= phase.floorToDouble();

        double raw;
        switch (tone.wave) {
          case Waveform.sine:
            raw = math.sin(2 * math.pi * phase);
          case Waveform.square:
            raw = phase < 0.5 ? 1.0 : -1.0;
          case Waveform.triangle:
            raw = 4 * (phase - 0.5).abs() - 1;
          case Waveform.sawtooth:
            raw = 2 * phase - 1;
          case Waveform.noise:
            raw = rnd.nextDouble() * 2 - 1;
        }

        var envelope = 1.0;
        if (i < fadeSamples) envelope = i / fadeSamples;
        if (i > sampleCount - fadeSamples) {
          envelope = math.min(envelope, (sampleCount - i) / fadeSamples);
        }

        final amplitude = (raw * tone.volume * envelope).clamp(-1.0, 1.0);
        samples.add((amplitude * 32767).round());
      }
    }

    return _wrapWav(samples);
  }

  static Uint8List _wrapWav(List<int> samples) {
    const bitsPerSample = 16;
    const channels = 1;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2;

    final bytes = ByteData(44 + dataSize);
    void writeString(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeString(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}
