import 'dart:math';

import 'package:flutter/material.dart';

/// Wire colors on the Lab Kit. Placeholder assignments until the team makes them official.
enum WireColor {
  red('Red', Color(0xFFD7263D), Color(0xFFD7263D)),
  black('Black', Color(0xFF1A1A1F), Color(0xFF1A1A1F)),
  blue('Blue', Color(0xFF1D6FE0), Color(0xFF1D6FE0)),
  white('White', Color(0xFFFFFFFF), Color(0xFF9A9AA5)),
  yellow('Yellow', Color(0xFFF2C230), Color(0xFFB88A00)),
  orange('Orange', Color(0xFFF28C1E), Color(0xFFC26A0A)),
  green('Green', Color(0xFF2E9E5B), Color(0xFF2E9E5B));

  const WireColor(this.label, this.fill, this.edge);
  final String label;
  final Color fill;
  final Color edge;
}

/// The DC outputs available to students (only the ones the labs use).
enum Rail {
  p5('+5 V', WireColor.red, 5.03, 2),
  n5('−5 V', WireColor.yellow, -4.98, 2),
  p05('+0.5 V', WireColor.orange, 0.502, 3);

  const Rail(this.label, this.wire, this.simulatedValue, this.decimals);
  final String label;
  final WireColor wire;
  final double simulatedValue;
  final int decimals;
}

/// What the DMM can measure.
enum MeterMode {
  volts('DC voltage', 'Volts (V)', [
    'Clip the blue wire to the higher-voltage side and the white wire to the lower-voltage side.',
    'The circuit can be powered for this measurement. Keep fingers clear of exposed metal.',
  ]),
  ohms('Resistance', 'Ohms (Ω)', [
    'Turn off all DC outputs first. Measuring resistance on a powered circuit gives wrong readings and can damage the meter.',
    "For the most accurate value, measure the part out of the circuit and don't hold both legs with your fingers.",
  ]),
  inductance('Inductance', 'Henries (H)', [
    'Turn off all DC outputs first. Inductors must be measured with no power applied.',
    "Measure the inductor out of the circuit so other parts don't affect the reading.",
  ]),
  capacitance('Capacitance', 'Farads (F)', [
    'Turn off all DC outputs first, then discharge the capacitor before connecting the meter.',
    'Polarized (electrolytic) capacitors: blue wire to the + leg, white wire to the − leg.',
  ]);

  const MeterMode(this.label, this.unit, this.safetyPoints);
  final String label;
  final String unit;
  final List<String> safetyPoints;
}

enum WaveShape {
  sine('Sine'),
  square('Square'),
  triangle('Triangle');

  const WaveShape(this.label);
  final String label;
}

/// One waveform setting the kit should output.
class WaveSetting {
  const WaveSetting({
    required this.shape,
    required this.frequencyHz,
    required this.amplitudeV,
    this.offsetV = 0,
    this.dutyPercent = 50,
  });

  final WaveShape shape;
  final double frequencyHz;
  final double amplitudeV;
  final double offsetV;
  final double dutyPercent;
}

/// Everything the app needs from the Lab Kit.
///
/// [SimulatedKit] fakes it for demos. The Bluetooth version will implement the
/// same methods by sending commands to the nRF52832 and reading its responses,
/// so no screen needs to change when it is swapped in (see lib/main.dart).
abstract class KitService extends ChangeNotifier {
  String get name;
  bool get connected;
  bool get simulated;

  bool railOn(Rail rail);
  bool get meterOn;
  MeterMode get meterMode;
  bool get waveOn;
  WaveSetting? get wave;

  bool get anythingOn => Rail.values.any(railOn) || meterOn || waveOn;

  Future<void> connect(String kitName);
  Future<void> setRail(Rail rail, bool on);
  Future<void> setMeter(bool on, MeterMode mode);
  Future<void> setWave(bool on, WaveSetting? setting);

  /// Turns every output and the meter off.
  Future<void> allOff();

  /// Latest meter reading. [expected] is only used by the simulator.
  double readMeter(MeterMode mode, {required double expected});

  /// Latest measured voltage of a DC output.
  double readRail(Rail rail);
}

class SimulatedKit extends KitService {
  final _rand = Random();
  String _name = 'Lab Kit #18';
  final Map<Rail, bool> _rails = {for (final r in Rail.values) r: false};
  bool _meterOn = false;
  MeterMode _meterMode = MeterMode.volts;
  bool _waveOn = false;
  WaveSetting? _wave;

  double _noise(double value, double spread) => value * (1 + (_rand.nextDouble() - 0.5) * spread);

  @override
  String get name => _name;
  @override
  bool get connected => true;
  @override
  bool get simulated => true;

  @override
  bool railOn(Rail rail) => _rails[rail] ?? false;
  @override
  bool get meterOn => _meterOn;
  @override
  MeterMode get meterMode => _meterMode;
  @override
  bool get waveOn => _waveOn;
  @override
  WaveSetting? get wave => _wave;

  @override
  Future<void> connect(String kitName) async {
    _name = kitName;
    notifyListeners();
  }

  @override
  Future<void> setRail(Rail rail, bool on) async {
    _rails[rail] = on;
    notifyListeners();
  }

  @override
  Future<void> setMeter(bool on, MeterMode mode) async {
    _meterOn = on;
    _meterMode = mode;
    notifyListeners();
  }

  @override
  Future<void> setWave(bool on, WaveSetting? setting) async {
    _waveOn = on;
    _wave = setting;
    notifyListeners();
  }

  @override
  Future<void> allOff() async {
    final changed = anythingOn;
    for (final r in Rail.values) {
      _rails[r] = false;
    }
    _meterOn = false;
    _waveOn = false;
    if (changed) notifyListeners();
  }

  @override
  double readMeter(MeterMode mode, {required double expected}) => _noise(expected, 0.004);

  @override
  double readRail(Rail rail) => _noise(rail.simulatedValue, 0.002);
}
