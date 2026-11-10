import 'dart:async';

import 'package:flutter/material.dart';

import '../kit/kit_service.dart';
import '../labs/lab_model.dart' show formatReading;
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/diagrams.dart';
import '../widgets/power_dialog.dart';

/// A wave gen preset taken from the lab procedures.
class _WavePreset {
  const _WavePreset(this.id, this.lab, this.amplitude, {this.freq, this.sweep = false, this.offset = 0, this.extra});
  final String id;
  final String lab;
  final double amplitude;
  final double? freq;
  final bool sweep;
  final double offset;
  final String? extra;
}

const _presets = <WaveShape, List<_WavePreset>>{
  WaveShape.sine: [
    _WavePreset('l5', 'Lab 5 · AC signals', 2.0, freq: 30.0),
    _WavePreset('l6', 'Lab 6 · Frequency response', 2.0, sweep: true),
    _WavePreset('l7s', 'Lab 7 · Op amp integrator', 0.5, freq: 30.0),
  ],
  WaveShape.square: [
    _WavePreset('l4', 'Lab 4 · RC and RL transients', 1.0, freq: 20.0, offset: 1.0, extra: '+1 V offset · 50% duty'),
    _WavePreset('l7q', 'Lab 7 · Op amp integrator', 0.5, freq: 30.0),
  ],
  WaveShape.triangle: [
    _WavePreset('l7t', 'Lab 7 · Op amp integrator', 0.5, freq: 30.0),
  ],
};

/// Lab 6, Table 5 frequencies.
const _sweep = <double>[1, 2, 10, 20, 50, 100, 200, 250, 300, 350, 400, 450, 500, 800, 1000, 1200];

String _hz(double f) => f >= 1000 ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)} kHz' : '${f.toStringAsFixed(0)} Hz';

String _volts(double v) => v == v.roundToDouble() ? '${v.toStringAsFixed(0)} V' : '$v V';

class InstrumentsScreen extends StatefulWidget {
  const InstrumentsScreen({super.key, required this.showOffNote, required this.onClearNote});

  /// True right after the shell switched everything off because the student left this tab.
  final bool showOffNote;
  final VoidCallback onClearNote;

  @override
  State<InstrumentsScreen> createState() => _InstrumentsScreenState();
}

enum _Tab { scope, dmm, wave, dc }

class _InstrumentsScreenState extends State<InstrumentsScreen> {
  _Tab _tab = _Tab.dc;
  MeterMode _mode = MeterMode.volts;
  WaveShape? _shape;
  _WavePreset? _preset;
  double _sweepF = 1;
  Timer? _timer;

  KitService get _kit => AppScope.read(context).kit;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted && (_tab == _Tab.dc || _tab == _Tab.dmm)) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  WaveSetting? get _setting {
    final p = _preset, s = _shape;
    if (p == null || s == null) return null;
    return WaveSetting(shape: s, frequencyHz: p.sweep ? _sweepF : p.freq!, amplitudeV: p.amplitude, offsetV: p.offset);
  }

  String _settingSummary() {
    final p = _preset!, s = _shape!;
    final f = p.sweep ? _sweepF : p.freq!;
    return '${s.label} · ${_hz(f)} · ${_volts(p.amplitude)} amplitude${p.extra != null ? ' · ${p.extra}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild when the kit changes
    return Column(
      children: [
        const TabHeader(title: 'Instruments'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                for (final t in _Tab.values)
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _tab = t),
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tab == t ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          const {_Tab.scope: 'Scope', _Tab.dmm: 'DMM', _Tab.wave: 'Wave gen', _Tab.dc: 'DC'}[t]!,
                          style: ts(14,
                              weight: _tab == t ? FontWeight.w600 : FontWeight.w500,
                              color: _tab == t ? AppColors.maroon : AppColors.text2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            children: [
              if (widget.showOffNote) ...[
                const Callout(CalloutKind.info, 'Everything was turned off when you left this screen.'),
                const SizedBox(height: 12),
              ],
              ..._body(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _body() {
    switch (_tab) {
      case _Tab.scope:
        return _scope();
      case _Tab.dmm:
        return _dmm();
      case _Tab.wave:
        return _wave();
      case _Tab.dc:
        return _dc();
    }
  }

  // ---------------- Scope ----------------
  List<Widget> _scope() => [
        CardBox(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 12, height: 3, color: AppColors.maroon),
                const SizedBox(width: 6),
                Text('CH1', style: ts(13, weight: FontWeight.w600)),
                const SizedBox(width: 14),
                Container(width: 12, height: 3, color: const Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text('CH2', style: ts(13, weight: FontWeight.w600, color: AppColors.muted)),
                const Spacer(),
                Text('Running · Simulated', style: ts(13, weight: FontWeight.w600, color: AppColors.green)),
              ]),
              const SizedBox(height: 10),
              const ScopeTrace(),
              const SizedBox(height: 10),
              Text('Scope settings will be limited to what Labs 4–7 use.', style: ts(13, color: AppColors.muted)),
            ],
          ),
        ),
      ];

  // ---------------- DMM ----------------
  List<Widget> _dmm() {
    final on = _kit.meterOn && _kit.meterMode == _mode;
    const expected = {
      MeterMode.volts: 3.446,
      MeterMode.ohms: 218.7,
      MeterMode.inductance: 1.02,
      MeterMode.capacitance: 0.98,
    };
    final decimals = _mode == MeterMode.volts ? 3 : 1;
    return [
      sectionLabel('What are you measuring?'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          for (final m in MeterMode.values)
            Pressable(
              onTap: () {
                if (m == _mode) return;
                if (_kit.meterOn) _kit.setMeter(false, m);
                setState(() => _mode = m);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: m == _mode ? AppColors.maroonTint : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: m == _mode ? AppColors.maroon : AppColors.border, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label, style: ts(15, weight: FontWeight.w700, color: m == _mode ? AppColors.maroon : AppColors.text)),
                    Text(m.unit, style: ts(12, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _switchRow(
              title: 'Meter',
              status: on ? 'On · measuring ${_mode.label.toLowerCase()}' : 'Off · choose a measurement, then turn on',
              on: on,
              onChanged: (v) async {
                if (!v) {
                  _kit.setMeter(false, _mode);
                  return;
                }
                final ok = await confirmPower(
                  context,
                  title: 'Measure ${_mode.label.toLowerCase()}',
                  wires: const [(WireColor.blue, 'Meter +'), (WireColor.white, 'Meter −')],
                  points: _mode.safetyPoints,
                  confirmLabel: 'Start measuring',
                );
                if (ok) {
                  _kit.setMeter(true, _mode);
                  widget.onClearNote();
                }
              },
            ),
            if (on) ...[
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live reading', style: ts(12, weight: FontWeight.w600, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      formatReading(_kit.readMeter(_mode, expected: expected[_mode]!), _mode, decimals),
                      style: AppFonts.mono(size: 38),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        const WireSwatch(WireColor.blue, width: 22, height: 8),
        const SizedBox(width: 6),
        Text('Meter +', style: ts(13, color: AppColors.muted)),
        const SizedBox(width: 16),
        const WireSwatch(WireColor.white, width: 22, height: 8),
        const SizedBox(width: 6),
        Text('Meter −', style: ts(13, color: AppColors.muted)),
      ]),
    ];
  }

  // ---------------- Wave gen ----------------
  List<Widget> _wave() {
    final shape = _shape;
    final preset = _preset;
    final on = _kit.waveOn;
    return [
      sectionLabel('1. Choose a shape'),
      Row(
        children: [
          for (final s in WaveShape.values) ...[
            Expanded(
              child: Pressable(
                onTap: () {
                  if (s == shape) return;
                  if (on) _kit.setWave(false, null);
                  setState(() {
                    _shape = s;
                    _preset = null;
                  });
                },
                child: Container(
                  height: 84,
                  decoration: BoxDecoration(
                    color: s == shape ? AppColors.maroonTint : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: s == shape ? AppColors.maroon : AppColors.border, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WaveIcon(s, color: s == shape ? AppColors.maroon : AppColors.text),
                      const SizedBox(height: 6),
                      Text(s.label, style: ts(14, weight: FontWeight.w700, color: s == shape ? AppColors.maroon : AppColors.text)),
                    ],
                  ),
                ),
              ),
            ),
            if (s != WaveShape.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
      if (shape != null) ...[
        const SizedBox(height: 16),
        sectionLabel('2. Choose the lab setting'),
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in _presets[shape]!)
                Pressable(
                  onTap: () {
                    if (p.id == preset?.id) return;
                    if (on) _kit.setWave(false, null);
                    setState(() {
                      _preset = p;
                      _sweepF = 1;
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: p.id == preset?.id ? AppColors.maroon : const Color(0xFFB9B9C2), width: 2),
                          ),
                          child: p.id == preset?.id
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.lab, style: ts(15, weight: FontWeight.w700)),
                              Text(
                                '${p.sweep ? '1 Hz to 1.2 kHz' : _hz(p.freq!)} · ${_volts(p.amplitude)} amplitude${p.extra != null ? ' · ${p.extra}' : ''}',
                                style: ts(13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (preset != null && preset.sweep)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frequency (Table 5) · you can change this while the output is on',
                          style: ts(13, weight: FontWeight.w600, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final f in _sweep)
                            Pressable(
                              onTap: () {
                                setState(() => _sweepF = f);
                                if (on) _kit.setWave(true, _setting);
                              },
                              child: Container(
                                width: 70,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: f == _sweepF ? AppColors.maroon : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: f == _sweepF ? AppColors.maroon : AppColors.buttonBorder),
                                ),
                                child: Text(
                                  f >= 1000 ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k' : f.toStringAsFixed(0),
                                  style: AppFonts.mono(size: 13, color: f == _sweepF ? Colors.white : AppColors.text),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: _switchRow(
          wire: WireColor.green,
          title: 'Output',
          subtitle: 'Green wire',
          status: on
              ? 'On · ${_settingSummary()}'
              : (preset != null ? 'Ready · ${_settingSummary()}' : 'Off · choose a shape and lab setting'),
          on: on,
          onChanged: preset == null
              ? null
              : (v) async {
                  if (!v) {
                    _kit.setWave(false, null);
                    return;
                  }
                  final ok = await confirmPower(
                    context,
                    title: 'Start the ${shape!.label.toLowerCase()} wave?',
                    wires: const [(WireColor.green, 'Wave gen output'), (WireColor.black, 'Ground')],
                    points: [
                      'Check the setting matches your lab step: ${_settingSummary()}.',
                      'Confirm both wires are fully seated in the breadboard before starting the output.',
                      'Do not connect, remove or move any wires while the output is on.',
                    ],
                    confirmLabel: 'Start output',
                  );
                  if (ok) {
                    _kit.setWave(true, _setting);
                    widget.onClearNote();
                  }
                },
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Changing the shape or lab setting turns the output off, so you always confirm before a new signal starts.',
        style: ts(13, color: AppColors.muted, height: 1.45),
      ),
    ];
  }

  // ---------------- DC ----------------
  List<Widget> _dc() {
    final anyOn = Rail.values.any(_kit.railOn);
    return [
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final r in Rail.values) ...[
              _switchRow(
                wire: r.wire,
                title: r.label,
                titleMono: true,
                subtitle: '${r.wire.label} wire',
                status: _kit.railOn(r)
                    ? 'On · reading ${_kit.readRail(r) >= 0 ? '+' : '−'}${_kit.readRail(r).abs().toStringAsFixed(r.decimals)} V'
                    : 'Off',
                on: _kit.railOn(r),
                onChanged: (v) async {
                  if (!v) {
                    _kit.setRail(r, false);
                    return;
                  }
                  final ok = await confirmPower(
                    context,
                    title: 'Turn on the ${r.label} output?',
                    wires: [(r.wire, '${r.label} output'), (WireColor.black, 'Ground')],
                    points: const [
                      'Confirm both wires are fully seated in the breadboard before turning the output on.',
                      'Do not connect, remove or move any wires while the output is on.',
                    ],
                    confirmLabel: 'Turn on',
                  );
                  if (ok) {
                    _kit.setRail(r, true);
                    widget.onClearNote();
                  }
                },
              ),
              const Divider(height: 1, color: AppColors.divider),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const WireSwatch(WireColor.black, width: 22, height: 8),
                const SizedBox(width: 10),
                Text('Ground for every output is the black wire.', style: ts(13, color: AppColors.muted)),
              ]),
            ),
          ],
        ),
      ),
      if (anyOn) ...[
        const SizedBox(height: 12),
        Pressable(
          onTap: _kit.allOff,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.maroon, width: 2),
            ),
            child: Text('Turn all outputs off', style: ts(16, weight: FontWeight.w600, color: AppColors.maroon)),
          ),
        ),
      ],
      const SizedBox(height: 12),
      const Callout(CalloutKind.warn, 'Only the outputs used in the labs are available here. Turn outputs off before changing any wiring.'),
    ];
  }

  Widget _switchRow({
    required String title,
    required String status,
    required bool on,
    required ValueChanged<bool>? onChanged,
    WireColor? wire,
    String? subtitle,
    bool titleMono = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (wire != null) ...[
            Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: wire.fill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: wire.edge, width: 2),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(title, style: titleMono ? AppFonts.mono(size: 22) : ts(17, weight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(width: 8),
                      Text(subtitle, style: ts(12, color: AppColors.muted)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: ts(13, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? AppColors.green : AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          KitSwitch(value: on, onChanged: onChanged, label: '$title on or off'),
        ],
      ),
    );
  }
}
