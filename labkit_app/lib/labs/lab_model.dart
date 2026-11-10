import 'package:flutter/material.dart';

import '../kit/kit_service.dart';

/// Resistor band colors used by the diagrams.
class BandColors {
  static const brown = Color(0xFF7B4A26);
  static const black = Color(0xFF1A1A1F);
  static const red = Color(0xFFD7263D);
  static const orange = Color(0xFFF28C1E);
  static const gold = Color(0xFFC9A227);
}

/// Physical parts that appear in diagrams.
enum PartKind {
  r100('100 Ω', [BandColors.brown, BandColors.black, BandColors.brown]),
  r220('220 Ω', [BandColors.red, BandColors.red, BandColors.brown]),
  r10k('10 kΩ', [BandColors.brown, BandColors.black, BandColors.orange]),
  photo('Photoresistor', []),
  therm('Thermistor', []);

  const PartKind(this.label, this.bands);
  final String label;
  final List<Color> bands;
  bool get isResistor => bands.isNotEmpty;
}

/// Which picture a step shows above its instructions.
enum StepVisual { parts, legend, connect, loose, schematic, board, compare, summary, none }

/// What the 5 V output must be before the student may continue.
enum SupplyRule { none, mustBeOff, mustBeOn }

class WireRun {
  const WireRun(this.color, this.to);
  final WireColor color;
  final String to;
}

/// Breadboard drawing state for a step.
class BoardState {
  const BoardState({this.r1, this.r2, this.power = false, this.probeRows, this.highlightRows = const []});
  final PartKind? r1;
  final PartKind? r2;
  final bool power;
  final List<int>? probeRows; // [blue row, white row]
  final List<int> highlightRows;
}

class LoosePart {
  const LoosePart(this.kind, this.label);
  final PartKind kind;
  final String label;
}

class Measurement {
  const Measurement({
    required this.key,
    required this.label,
    required this.simulated,
    required this.decimals,
    required this.mode,
  });
  final String key;
  final String label;
  final double simulated; // value the simulator reads back
  final int decimals;
  final MeterMode mode;
}

class LabStep {
  const LabStep({
    required this.part,
    required this.ref,
    required this.title,
    required this.text,
    this.visual = StepVisual.none,
    this.how,
    this.tip,
    this.warn,
    this.question,
    this.supply = SupplyRule.none,
    this.connectCheck = false,
    this.loose,
    this.board,
    this.wires = const [],
    this.measurement,
  });

  final String part;
  final String ref;
  final String title;
  final String text;
  final StepVisual visual;
  final String? how;
  final String? tip;
  final String? warn;
  final String? question;
  final SupplyRule supply;
  final bool connectCheck;
  final LoosePart? loose;
  final BoardState? board;
  final List<WireRun> wires;
  final Measurement? measurement;
}

class PartItem {
  const PartItem(this.name, this.hint, [this.kind]);
  final String name;
  final String hint;
  final PartKind? kind;
}

class SummaryRow {
  const SummaryRow(this.label, {this.key, this.compute});
  final String label;
  final String? key;
  final String Function(Map<String, double> rec)? compute;
}

class SummaryGroup {
  const SummaryGroup(this.title, this.rows);
  final String title;
  final List<SummaryRow> rows;
}

class CompareRow {
  const CompareRow(this.label, this.calc, this.meas, this.diff);
  final String label;
  final String calc;
  final String meas;
  final String diff;
}

class LabDef {
  const LabDef({
    required this.id,
    required this.number,
    required this.title,
    required this.steps,
    required this.parts,
    required this.summary,
    required this.compare,
    required this.questions,
  });

  final String id;
  final int number;
  final String title;
  final List<LabStep> steps;
  final List<PartItem> parts;
  final List<SummaryGroup> summary;
  final List<CompareRow> Function(Map<String, double> rec) compare;
  final List<String> questions;

  Measurement? measurementFor(String key) {
    for (final s in steps) {
      if (s.measurement?.key == key) return s.measurement;
    }
    return null;
  }

  /// Turns saved readings into labelled rows (what the summary step and exports show).
  List<({String title, List<({String label, String value})> rows})> buildSummary(Map<String, double> rec) {
    return [
      for (final g in summary)
        (
          title: g.title,
          rows: [
            for (final r in g.rows)
              (
                label: r.label,
                value: r.compute != null
                    ? r.compute!(rec)
                    : formatSaved(rec[r.key], measurementFor(r.key ?? '')),
              ),
          ],
        ),
    ];
  }
}

/// Formats a reading for display.
String formatReading(double v, MeterMode mode, int decimals) {
  switch (mode) {
    case MeterMode.volts:
      return '${v.toStringAsFixed(decimals)} V';
    case MeterMode.ohms:
      if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(2)} kΩ';
      return '${v.toStringAsFixed(decimals)} Ω';
    case MeterMode.inductance:
      return '${v.toStringAsFixed(2)} mH';
    case MeterMode.capacitance:
      return '${v.toStringAsFixed(2)} µF';
  }
}

String formatSaved(double? v, Measurement? m) {
  if (v == null || m == null) return '—';
  return formatReading(v, m.mode, m.decimals);
}
