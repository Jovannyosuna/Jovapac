// Synthesizes every sound effect and the music loop into assets/audio/.
// Run with: dart run tool/generate_audio.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

enum Wave { square, triangle, noise, sine }

class Tone {
  Tone(
    this.start,
    this.duration,
    this.freq, {
    double? endFreq,
    this.wave = Wave.square,
    this.volume = 0.4,
    this.duty = 0.5,
    this.attack = 0.004,
    this.release = 0.03,
    this.vibrato = 0,
  }) : endFreq = endFreq ?? freq;

  final double start;
  final double duration;
  final double freq;
  final double endFreq;
  final Wave wave;
  final double volume;
  final double duty;
  final double attack;
  final double release;
  final double vibrato;
}

double midi(num note) => 440 * pow(2, (note - 69) / 12).toDouble();

final Random _noise = Random(42);

Float64List render(List<Tone> tones, {double? length, bool loop = false}) {
  final total = length ??
      tones.map((t) => t.start + t.duration + t.release).reduce(max);
  final samples = (total * sampleRate).ceil();
  final out = Float64List(samples);
  for (final tone in tones) {
    final first = (tone.start * sampleRate).round();
    final count = ((tone.duration + tone.release) * sampleRate).round();
    var phase = 0.0;
    var held = 0.0;
    for (var n = 0; n < count; n++) {
      final t = n / sampleRate;
      final k = (t / tone.duration).clamp(0.0, 1.0);
      var f = tone.freq * pow(tone.endFreq / tone.freq, k);
      if (tone.vibrato > 0) f *= 1 + tone.vibrato * sin(2 * pi * 6 * t);
      phase = (phase + f / sampleRate) % 1.0;
      double v;
      switch (tone.wave) {
        case Wave.square:
          v = phase < tone.duty ? 1 : -1;
        case Wave.triangle:
          v = 4 * (phase < 0.5 ? phase : 1 - phase) - 1;
        case Wave.sine:
          v = sin(2 * pi * phase);
        case Wave.noise:
          if (n % 2 == 0) held = _noise.nextDouble() * 2 - 1;
          v = held;
      }
      double env;
      if (t < tone.attack) {
        env = t / tone.attack;
      } else if (t < tone.duration) {
        env = 1;
      } else {
        env = max(0, 1 - (t - tone.duration) / tone.release);
      }
      var index = first + n;
      if (index >= samples) {
        if (!loop) break;
        index %= samples;
      }
      out[index] += v * env * tone.volume;
    }
  }
  return out;
}

void write(String name, Float64List data, {double gain = 0.8}) {
  final bytes = BytesData(data.length * 2 + 44);
  final pcm = Int16List(data.length);
  for (var i = 0; i < data.length; i++) {
    final v = _tanh(data[i] * gain);
    pcm[i] = (v * 32000).round();
  }
  bytes.writeHeader(data.length);
  bytes.add(pcm.buffer.asUint8List());
  File('assets/audio/$name').writeAsBytesSync(bytes.toBytes());
  stdout.writeln('assets/audio/$name  ${(data.length / sampleRate).toStringAsFixed(2)}s');
}

double _tanh(double x) {
  final e = exp(2 * x);
  return (e - 1) / (e + 1);
}

class BytesData {
  BytesData(int capacity) : _builder = BytesBuilder(copy: false);

  final BytesBuilder _builder;

  void writeHeader(int sampleCount) {
    final header = ByteData(44);
    final dataSize = sampleCount * 2;
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, dataSize, Endian.little);
    _builder.add(header.buffer.asUint8List());
  }

  void add(List<int> bytes) => _builder.add(bytes);

  Uint8List toBytes() => _builder.takeBytes();
}

List<Tone> sequence(List<(num, double)> notes,
    {double start = 0, Wave wave = Wave.square, double volume = 0.35, double duty = 0.5, double gap = 0.012}) {
  final tones = <Tone>[];
  var t = start;
  for (final (note, length) in notes) {
    if (note > 0) {
      tones.add(Tone(t, length - gap, midi(note),
          wave: wave, volume: volume, duty: duty, release: 0.02));
    }
    t += length;
  }
  return tones;
}

void main() {
  Directory('assets/audio').createSync(recursive: true);

  write('chomp_a.wav', render([
    Tone(0, 0.06, 560, endFreq: 260, wave: Wave.triangle, volume: 0.6, release: 0.015),
    Tone(0, 0.05, 560, endFreq: 280, wave: Wave.square, volume: 0.12, duty: 0.25, release: 0.01),
  ]));
  write('chomp_b.wav', render([
    Tone(0, 0.06, 280, endFreq: 560, wave: Wave.triangle, volume: 0.6, release: 0.015),
    Tone(0, 0.05, 300, endFreq: 560, wave: Wave.square, volume: 0.12, duty: 0.25, release: 0.01),
  ]));

  write('power.wav', render([
    ...sequence([(72, 0.055), (76, 0.055), (79, 0.055), (84, 0.055), (88, 0.055)],
        duty: 0.25, volume: 0.3),
    Tone(0.27, 0.18, midi(84), endFreq: midi(96), wave: Wave.triangle, volume: 0.35, release: 0.08),
  ]));

  write('eat_ghost.wav', render([
    Tone(0, 0.24, 180, endFreq: 1500, wave: Wave.square, duty: 0.3, volume: 0.28, release: 0.05),
    Tone(0, 0.24, 90, endFreq: 750, wave: Wave.triangle, volume: 0.4, release: 0.05),
  ]));

  write('death.wav', render([
    for (var i = 0; i < 10; i++)
      Tone(i * 0.1, 0.09, 880 * pow(0.82, i).toDouble(),
          endFreq: 700 * pow(0.82, i).toDouble(),
          wave: Wave.square, duty: 0.4, volume: 0.28, vibrato: 0.03, release: 0.02),
    Tone(1.05, 0.06, midi(48), wave: Wave.triangle, volume: 0.5),
    Tone(1.17, 0.12, midi(43), wave: Wave.triangle, volume: 0.5, release: 0.1),
  ]));

  write('level_clear.wav', render([
    ...sequence([(72, 0.09), (76, 0.09), (79, 0.09), (84, 0.09), (79, 0.09), (84, 0.09), (88, 0.42)],
        duty: 0.25, volume: 0.3),
    ...sequence([(48, 0.36), (55, 0.36), (60, 0.5)], wave: Wave.triangle, volume: 0.45),
  ]));

  write('game_over.wav', render([
    ...sequence([(76, 0.24), (74, 0.24), (72, 0.24), (71, 0.24)], duty: 0.5, volume: 0.28),
    Tone(0.96, 0.6, midi(69), wave: Wave.square, duty: 0.5, volume: 0.28, vibrato: 0.012, release: 0.25),
    ...sequence([(45, 0.48), (40, 0.48), (45, 0.8)], wave: Wave.triangle, volume: 0.45),
  ]));

  write('victory.wav', render([
    ...sequence([(72, 0.12), (72, 0.12), (72, 0.12), (72, 0.36), (68, 0.36), (70, 0.36), (72, 0.18), (70, 0.12), (72, 0.8)],
        duty: 0.5, volume: 0.27),
    ...sequence([(64, 0.12), (64, 0.12), (64, 0.12), (64, 0.36), (60, 0.36), (62, 0.36), (64, 0.18), (62, 0.12), (67, 0.8)],
        duty: 0.25, volume: 0.14),
    ...sequence([(48, 0.72), (44, 0.36), (46, 0.36), (48, 0.3), (48, 0.8)], wave: Wave.triangle, volume: 0.45),
  ]));

  write('extra_life.wav', render([
    ...sequence([(83, 0.07), (88, 0.07), (95, 0.07), (83, 0.07), (88, 0.07), (95, 0.14)],
        duty: 0.25, volume: 0.28),
  ]));

  write('bonus.wav', render([
    ...sequence([(91, 0.045), (95, 0.045), (98, 0.045), (103, 0.12)], wave: Wave.triangle, volume: 0.45),
    Tone(0, 0.02, 1, wave: Wave.noise, volume: 0.15, release: 0.02),
  ]));

  write('select.wav', render([
    Tone(0, 0.035, 880, endFreq: 1320, wave: Wave.square, duty: 0.25, volume: 0.25, release: 0.02),
  ]));

  // Intro jingle that plays under the "get ready" banner (2 s).
  const e = 0.125;
  write('start.wav', render([
    ...sequence([
      (69, e), (72, e), (76, e), (81, e), (79, e), (76, e), (72, e), (76, e),
      (77, e), (74, e), (69, e), (74, e), (76, e * 2), (88, e * 2),
    ], duty: 0.5, volume: 0.26),
    ...sequence([
      (45, e * 2), (57, e * 2), (41, e * 2), (53, e * 2), (38, e * 2), (50, e * 2), (40, e * 2), (52, e * 2),
    ], wave: Wave.triangle, volume: 0.45),
  ]));

  write('music_loop.wav', _music(), gain: 0.7);
}

Float64List _music() {
  const eighth = 0.25;
  const sixteenth = eighth / 2;
  const bars = 8;
  const barLength = eighth * 8;
  const roots = [45, 41, 48, 43, 45, 41, 43, 40];
  const arps = [
    [69, 72, 76], [65, 69, 72], [67, 72, 76], [67, 71, 74],
    [69, 72, 76], [65, 69, 72], [67, 71, 74], [68, 71, 76],
  ];
  const lead = <(int, int, int)>[
    (0, 76, 2), (2, 81, 2), (4, 79, 1), (5, 76, 1), (6, 72, 2),
    (8, 77, 2), (10, 81, 2), (12, 79, 2), (14, 77, 2),
    (16, 76, 3), (19, 74, 1), (20, 72, 2), (22, 76, 2),
    (24, 74, 4), (28, 71, 2), (30, 74, 2),
    (32, 76, 2), (34, 81, 2), (36, 83, 1), (37, 81, 1), (38, 79, 2),
    (40, 81, 2), (42, 77, 2), (44, 84, 2), (46, 81, 2),
    (48, 83, 2), (50, 79, 2), (52, 74, 2), (54, 79, 2),
    (56, 80, 4), (60, 76, 2), (62, 71, 2),
  ];

  final tones = <Tone>[];
  for (var bar = 0; bar < bars; bar++) {
    final t0 = bar * barLength;
    for (var i = 0; i < 8; i++) {
      final note = roots[bar] + (i.isOdd ? 12 : 0);
      tones.add(Tone(t0 + i * eighth, eighth * 0.8, midi(note),
          wave: Wave.triangle, volume: 0.42, release: 0.03));
      if (i.isOdd) {
        tones.add(Tone(t0 + i * eighth, 0.02, 1,
            wave: Wave.noise, volume: 0.07, release: 0.02));
      }
    }
    for (final beat in [0, 4]) {
      tones.add(Tone(t0 + beat * eighth, 0.09, 140, endFreq: 45,
          wave: Wave.sine, volume: 0.5, release: 0.04));
    }
    for (var s = 0; s < 16; s++) {
      final chord = arps[bar];
      tones.add(Tone(t0 + s * sixteenth, sixteenth * 0.6, midi(chord[s % 3] + 12),
          wave: Wave.square, duty: 0.125, volume: 0.05, release: 0.02));
    }
  }
  for (final (pos, note, length) in lead) {
    tones.add(Tone(pos * eighth, length * eighth - 0.03, midi(note),
        wave: Wave.square, duty: 0.5, volume: 0.13, vibrato: length > 2 ? 0.006 : 0, release: 0.04));
  }
  return render(tones, length: bars * barLength, loop: true);
}
