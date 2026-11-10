import 'dart:async';

import 'package:flutter/material.dart';

import '../kit/kit_service.dart';
import '../labs/lab_model.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/diagrams.dart';

/// What the lab tells the home screen when it closes.
class LabExitResult {
  const LabExitResult({required this.labId, this.exportedAttempt});
  final String labId;
  final int? exportedAttempt;
}

/// Walks a student through one lab, step by step, from a [LabDef].
class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.lab});

  final LabDef lab;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  static const _rail = Rail.p5; // Lab 1 uses the +5 V output

  int _step = 0;
  Map<String, double> _rec = {};
  bool _autoOff = false;
  bool _ready = false;
  bool _closed = false;
  Timer? _timer;
  double _live = 0;

  LabDef get lab => widget.lab;
  LabStep get _s => lab.steps[_step];
  AppState get _app => AppScope.read(context);
  KitService get _kit => _app.kit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final p = _app.progressFor(lab.id);
    _step = p.step.clamp(0, lab.steps.length - 1).toInt();
    _rec = Map.of(p.readings);
    _autoOff = p.autoOff;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMeter();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted && _s.measurement != null) setState(_readLive);
    });
    _readLive();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _readLive() {
    final m = _s.measurement;
    if (m == null) return;
    final needsPower = m.mode == MeterMode.volts;
    _live = needsPower && !_kit.railOn(_rail) ? 0 : _kit.readMeter(m.mode, expected: m.simulated);
  }

  /// Puts the kit's meter in the right mode for the current step.
  void _syncMeter() {
    final m = _s.measurement;
    if (m != null) {
      _kit.setMeter(true, m.mode);
    } else if (_kit.meterOn) {
      _kit.setMeter(false, _kit.meterMode);
    }
  }

  void _save() => _app.saveProgress(lab.id, LabProgress(step: _step, readings: _rec, autoOff: _autoOff));

  void _goTo(int i) {
    setState(() {
      _step = i;
      _readLive();
    });
    _syncMeter();
    _save();
  }

  /// Leaving the lab always turns the kit off. If the 5 V was on, the student is asked
  /// to turn it back on when they return.
  void _shutdown() {
    if (_closed) return;
    _closed = true;
    final wasOn = _kit.railOn(_rail);
    _kit.allOff();
    _app.saveProgress(lab.id, LabProgress(step: _step, readings: _rec, autoOff: _autoOff || wasOn));
  }

  void _back() {
    _shutdown();
    Navigator.of(context).pop(LabExitResult(labId: lab.id));
  }

  void _export() {
    final rec = Map.of(_rec);
    final attempt = _app.addAttempt(
      lab.id,
      sections: lab.buildSummary(rec),
      compare: [for (final c in lab.compare(rec)) (label: c.label, calc: c.calc, meas: c.meas, diff: c.diff)],
    );
    _closed = true;
    _kit.allOff();
    _app.clearProgress(lab.id);
    Navigator.of(context).pop(LabExitResult(labId: lab.id, exportedAttempt: attempt.number));
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild when the kit changes
    final s = _s;
    final total = lab.steps.length;
    final last = _step == total - 1;
    final on = _kit.railOn(_rail);

    final supplyOk = switch (s.supply) {
      SupplyRule.none => true,
      SupplyRule.mustBeOff => !on,
      SupplyRule.mustBeOn => on,
    };
    final m = s.measurement;
    final measOk = m == null || _rec.containsKey(m.key);
    final canNext = supplyOk && measOk && !last;
    final canExport = last && supplyOk;

    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _shutdown();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              BackHeader(kicker: 'LAB ${lab.number}', title: lab.title, onBack: _back),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Step ${_step + 1} of $total', style: ts(13, weight: FontWeight.w600)),
                        const Spacer(),
                        Flexible(
                          child: Text(s.part, style: ts(12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < total; i++)
                          Expanded(
                            child: Container(
                              height: 5,
                              margin: EdgeInsets.only(right: i == total - 1 ? 0.0 : 3.0),
                              decoration: BoxDecoration(
                                color: i <= _step ? AppColors.maroon : AppColors.segmentOff,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: _stepBody(s, on),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(label: 'Back', primary: false, onTap: _step == 0 ? null : () => _goTo(_step - 1)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: last ? 'Export results' : (m != null && !measOk ? 'Save a reading to continue' : 'Next step'),
                        onTap: canExport ? _export : (canNext ? () => _goTo(_step + 1) : null),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepBody(LabStep s, bool on) {
    final gap = const SizedBox(height: 14);
    final out = <Widget>[
      Text(s.title, style: ts(22, weight: FontWeight.w700, height: 1.25)),
      const SizedBox(height: 6),
      Text('Lab manual ${s.ref}', style: ts(12, color: AppColors.muted)),
      gap,
    ];

    final visual = _visual(s);
    if (visual != null) out.addAll([visual, gap]);

    out.add(Text(s.text, style: ts(16, color: AppColors.body, height: 1.5)));

    if (s.how != null || s.wires.isNotEmpty) {
      out.add(gap);
      if (s.how != null) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(s.how!, style: ts(15, color: AppColors.body, height: 1.45)),
        ));
      }
      for (final w in s.wires) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CardBox(
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                WireSwatch(w.color),
                const SizedBox(width: 12),
                SizedBox(width: 96, child: Text('${w.color.label} wire', style: ts(15, weight: FontWeight.w700))),
                const Icon(Icons.arrow_forward, size: 18, color: AppColors.faint),
                const SizedBox(width: 10),
                Expanded(child: Text(w.to, style: ts(15, weight: FontWeight.w600, color: AppColors.maroon))),
              ],
            ),
          ),
        ));
      }
    }

    if (s.tip != null) out.addAll([gap, Callout(CalloutKind.info, s.tip!)]);
    if (s.warn != null) out.addAll([gap, Callout(CalloutKind.warn, s.warn!)]);

    final check = _kitCheck(s, on);
    if (check != null) out.addAll([gap, check]);

    if (s.measurement != null) out.addAll([gap, _meterCard(s.measurement!)]);
    if (s.visual == StepVisual.compare) out.addAll([gap, _compareCard()]);
    if (s.visual == StepVisual.summary) out.addAll([gap, _summary()]);

    if (s.question != null) {
      out.addAll([
        gap,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB9B9C2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FOR YOUR LAB REPORT',
                  style: ts(12, weight: FontWeight.w700, color: AppColors.maroon).copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(s.question!, style: ts(14, color: AppColors.body, height: 1.45)),
            ],
          ),
        ),
      ]);
    }
    return out;
  }

  Widget? _visual(LabStep s) {
    switch (s.visual) {
      case StepVisual.parts:
        return CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < lab.parts.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    border: i == lab.parts.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        child: lab.parts[i].kind != null && lab.parts[i].kind!.isResistor
                            ? ResistorIcon(lab.parts[i].kind!)
                            : const SizedBox(height: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lab.parts[i].name, style: ts(15, weight: FontWeight.w600)),
                              Text(lab.parts[i].hint, style: ts(12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case StepVisual.legend:
        const legend = [
          (WireColor.red, '5 V power (+)'),
          (WireColor.black, 'Ground (−)'),
          (WireColor.blue, 'Meter probe (+)'),
          (WireColor.white, 'Meter probe (−)'),
        ];
        return CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (c, use) in legend)
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      WireSwatch(c, width: 46, height: 12),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label, style: ts(16, weight: FontWeight.w700)),
                          Text(use, style: ts(13, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case StepVisual.connect:
        return CardBox(
          child: SizedBox(
            height: 118,
            child: Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.maroonTint, shape: BoxShape.circle),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                    child: const Icon(Icons.bluetooth, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        );
      case StepVisual.loose:
        return CardBox(padding: const EdgeInsets.all(10), child: LoosePartDiagram(s.loose!));
      case StepVisual.schematic:
        return const CardBox(padding: EdgeInsets.all(10), child: DividerSchematic());
      case StepVisual.board:
        return CardBox(padding: const EdgeInsets.all(10), child: BreadboardDiagram(s.board!));
      case StepVisual.compare:
      case StepVisual.summary:
      case StepVisual.none:
        return null;
    }
  }

  Widget? _kitCheck(LabStep s, bool on) {
    if (s.supply == SupplyRule.none) return null;
    final wantOff = s.supply == SupplyRule.mustBeOff;
    final ok = wantOff ? !on : on;
    if (ok) {
      final msg = wantOff
          ? (s.connectCheck
              ? 'connected to ${_kit.name}${_kit.simulated ? ' (simulated)' : ''}. 5 V output is OFF.'
              : '5 V output is OFF. Safe to touch the circuit.')
          : '5 V output is ON.';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.check, size: 20, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Kit check: ', style: ts(14, weight: FontWeight.w700, color: AppColors.greenText)),
                  TextSpan(text: msg, style: ts(14, color: AppColors.greenText)),
                ]),
              ),
            ),
          ],
        ),
      );
    }
    final msg = wantOff
        ? 'The 5 V output is ON. Turn it off before you touch the circuit.'
        : (_autoOff
            ? 'The 5 V output turned off automatically when you left the lab. Turn it back on when your wiring matches the diagram.'
            : 'The 5 V output is off. Turn it on when your wiring matches the diagram.');
    return CardBox(
      borderColor: AppColors.maroon,
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Kit check: ', style: ts(14, weight: FontWeight.w700, height: 1.45)),
            TextSpan(text: msg, style: ts(14, height: 1.45)),
          ])),
          const SizedBox(height: 12),
          AppButton(
            label: wantOff ? 'Turn off 5 V output' : 'Turn on 5 V output',
            height: 48,
            onTap: () {
              _kit.setRail(_rail, !on);
              setState(() => _autoOff = false);
              _save();
            },
          ),
        ],
      ),
    );
  }

  Widget _meterCard(Measurement m) {
    final saved = _rec[m.key];
    final recorded = saved != null;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Live meter reading', style: ts(13, weight: FontWeight.w600, color: AppColors.muted)),
              const Spacer(),
              Pill(m.mode == MeterMode.ohms ? 'Ω  resistance' : 'DC volts', fg: AppColors.maroon, bg: AppColors.maroonTint),
            ],
          ),
          const SizedBox(height: 10),
          Text(formatReading(_live, m.mode, m.decimals), style: AppFonts.mono(size: 38)),
          if (saved != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 18, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Saved ', style: ts(14, color: AppColors.greenText)),
                      TextSpan(
                        text: '${m.label} = ${formatReading(saved, m.mode, m.decimals)}',
                        style: ts(14, weight: FontWeight.w700, color: AppColors.greenText),
                      ),
                    ])),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Pressable(
            onTap: () {
              setState(() => _rec[m.key] = double.parse(_live.toStringAsFixed(m.decimals)));
              _save();
            },
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: recorded ? Colors.white : AppColors.maroon,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.maroon, width: 2),
              ),
              child: Text(
                recorded ? 'Save again' : 'Save ${m.label} reading',
                style: ts(16, weight: FontWeight.w600, color: recorded ? AppColors.maroon : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareCard() {
    final rows = lab.compare(_rec);
    TextStyle head() => ts(12, weight: FontWeight.w600, color: AppColors.muted);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Text('V1 = Vs × R1 ÷ (R1 + R2)\nV2 = Vs × R2 ÷ (R1 + R2)',
                style: AppFonts.mono(size: 13, weight: FontWeight.w500, color: AppColors.text2).copyWith(height: 1.6)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: SizedBox()),
            Expanded(child: Text('Calculated', style: head())),
            Expanded(child: Text('Measured', style: head())),
            Expanded(child: Text('% diff', style: head())),
          ]),
          for (final r in rows)
            Container(
              constraints: const BoxConstraints(minHeight: 40),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
              child: Row(children: [
                Expanded(child: Text(r.label, style: ts(14, weight: FontWeight.w700))),
                Expanded(child: Text(r.calc, style: AppFonts.mono(size: 13, weight: FontWeight.w500))),
                Expanded(child: Text(r.meas, style: AppFonts.mono(size: 13, weight: FontWeight.w500))),
                Expanded(child: Text(r.diff, style: AppFonts.mono(size: 13, color: AppColors.green))),
              ]),
            ),
          const SizedBox(height: 6),
          Text('Using your saved R1, R2 and Vs.', style: ts(12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _summary() {
    return Column(
      children: [
        for (final g in lab.buildSummary(_rec))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SummaryCard(title: g.title, rows: g.rows),
          ),
      ],
    );
  }
}

/// A titled table of label / value rows (used by the summary step and Saved).
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.title, required this.rows});

  final String title;
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(title, style: ts(13, weight: FontWeight.w700, color: AppColors.maroon)),
          ),
          for (final r in rows)
            Container(
              constraints: const BoxConstraints(minHeight: 36),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Expanded(child: Text(r.label, style: ts(14))),
                  Text(r.value, style: AppFonts.mono(size: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
