import '../kit/kit_service.dart';
import 'lab_model.dart';

// Lab 1 · Ohm's Law and Kirchhoff's Laws (ECEN 215 Lab Manual, sections 1.3 – 1.4).
// Lab procedure only, not the prelab. Every step the student sees comes from this list.

const _leads = [WireRun(WireColor.blue, 'one leg'), WireRun(WireColor.white, 'the other leg')];

const _ohm = MeterMode.ohms;
const _volt = MeterMode.volts;

double _get(Map<String, double> rec, String k, double fallback) => rec[k] ?? fallback;

double _v1Calc(Map<String, double> rec) {
  final r1 = _get(rec, 'R1', 99.4), r2 = _get(rec, 'R2', 218.7), vs = _get(rec, 'Vs', 5.031);
  return vs * r1 / (r1 + r2);
}

double _v2Calc(Map<String, double> rec) {
  final r1 = _get(rec, 'R1', 99.4), r2 = _get(rec, 'R2', 218.7), vs = _get(rec, 'Vs', 5.031);
  return vs * r2 / (r1 + r2);
}

String _pctDiff(double? meas, double calc) {
  if (meas == null) return '—';
  return '${((meas - calc).abs() / calc * 100).toStringAsFixed(1)}%';
}

List<CompareRow> _compare(Map<String, double> rec) {
  final v1 = _v1Calc(rec), v2 = _v2Calc(rec);
  return [
    CompareRow('V1', '${v1.toStringAsFixed(3)} V', rec['V1'] == null ? '—' : '${rec['V1']!.toStringAsFixed(3)} V', _pctDiff(rec['V1'], v1)),
    CompareRow('V2', '${v2.toStringAsFixed(3)} V', rec['V2'] == null ? '—' : '${rec['V2']!.toStringAsFixed(3)} V', _pctDiff(rec['V2'], v2)),
  ];
}

final lab1 = LabDef(
  id: 'lab1',
  number: 1,
  title: "Ohm's Law & Kirchhoff's Laws",
  parts: const [
    PartItem('100 Ω resistor', 'brown, black, brown, gold', PartKind.r100),
    PartItem('220 Ω resistor', 'red, red, brown, gold', PartKind.r220),
    PartItem('10 kΩ resistor', 'brown, black, orange, gold', PartKind.r10k),
    PartItem('Photoresistor', 'flat disc with a squiggly line'),
    PartItem('Thermistor', 'small dark bead, two legs'),
    PartItem('Breadboard', 'from your kit'),
    PartItem('Piece of cardstock', 'any stiff paper works'),
    PartItem('Phone flashlight', 'for Part E'),
  ],
  questions: const [
    'Record the calculated and measured V1 and V2 and the percent difference for each.',
    "What happens to the photoresistor's resistance as the light level changes?",
    'What happens to the voltage across the photoresistor as the light level changes?',
    "What happens to the thermistor's resistance and voltage as the temperature changes?",
    'Describe a practical device that could use one of these circuits as its first stage.',
  ],
  compare: _compare,
  summary: [
    const SummaryGroup('Resistors (1.3 A)', [SummaryRow('R1 (100 Ω)', key: 'R1'), SummaryRow('R2 (220 Ω)', key: 'R2')]),
    SummaryGroup('Voltage divider (1.3 C–F)', [
      const SummaryRow('Vs', key: 'Vs'),
      const SummaryRow('V1 measured', key: 'V1'),
      SummaryRow('V1 calculated', compute: (r) => '${_v1Calc(r).toStringAsFixed(3)} V'),
      const SummaryRow('V2 measured', key: 'V2'),
      SummaryRow('V2 calculated', compute: (r) => '${_v2Calc(r).toStringAsFixed(3)} V'),
    ]),
    const SummaryGroup('Table 1 · Photoresistor resistance',
        [SummaryRow('Dark', key: 'PRdark'), SummaryRow('Room light', key: 'PRamb'), SummaryRow('Flashlight', key: 'PRbright')]),
    const SummaryGroup('Table 2 · Voltage across photoresistor',
        [SummaryRow('Dark', key: 'VPdark'), SummaryRow('Room light', key: 'VPamb'), SummaryRow('Flashlight', key: 'VPbright')]),
    const SummaryGroup('Table 3 · Thermistor resistance', [SummaryRow('Room temp', key: 'THamb'), SummaryRow('Warm', key: 'THwarm')]),
    const SummaryGroup('Table 4 · Voltage across thermistor', [SummaryRow('Room temp', key: 'VTamb'), SummaryRow('Warm', key: 'VTwarm')]),
  ],
  steps: const [
    // ---- Get ready ----
    LabStep(
      part: 'Get ready', ref: '1.3 A', title: 'Grab your parts', visual: StepVisual.parts,
      text: 'Find these in your component kit and lay them out on the table.',
      tip: 'Read resistor colors starting from the end farthest from the gold band.',
    ),
    LabStep(
      part: 'Get ready', ref: '—', title: 'Learn the wire colors', visual: StepVisual.legend,
      text: 'Your Lab Kit has color-coded wires. Every step tells you exactly which color goes where.',
      warn: "Never let the red and black wires touch while the kit is on. That's a short circuit and can damage the kit.",
    ),
    LabStep(
      part: 'Get ready', ref: '—', title: 'Turn on your kit', visual: StepVisual.connect,
      supply: SupplyRule.mustBeOff, connectCheck: true,
      text: 'Flip the power switch on the side of the kit to ON. The app connects to it automatically.',
    ),

    // ---- Part A · Resistors ----
    LabStep(
      part: 'Part A · Resistors', ref: '1.3 A', title: 'Measure R1 (100 Ω)', visual: StepVisual.loose,
      loose: LoosePart(PartKind.r100, 'R1 · brown, black, brown'), supply: SupplyRule.mustBeOff,
      text: 'Find the resistor with bands brown, black, brown, gold. This is R1.',
      how: 'Clip the blue wire to one leg and the white wire to the other leg, as shown above.', wires: _leads,
      tip: "Don't pinch both legs with your fingers while measuring. Your body changes the reading.",
      measurement: Measurement(key: 'R1', label: 'R1', simulated: 99.4, decimals: 1, mode: _ohm),
    ),
    LabStep(
      part: 'Part A · Resistors', ref: '1.3 A', title: 'Measure R2 (220 Ω)', visual: StepVisual.loose,
      loose: LoosePart(PartKind.r220, 'R2 · red, red, brown'), supply: SupplyRule.mustBeOff,
      text: 'Find the resistor with bands red, red, brown, gold. This is R2.',
      how: 'Clip the blue wire to one leg and the white wire to the other leg.', wires: _leads,
      measurement: Measurement(key: 'R2', label: 'R2', simulated: 218.7, decimals: 1, mode: _ohm),
    ),

    // ---- Part B · Build ----
    LabStep(
      part: 'Part B · Build', ref: '1.3 B · Fig 1.1d', title: "This is the circuit you'll build", visual: StepVisual.schematic,
      text: 'R1 and R2 connect end to end (in series) across the 5 V supply. The 5 V gets split between them. This is called a voltage divider.',
      tip: 'The gray row tags show where each point of the circuit goes on your breadboard.',
    ),
    LabStep(
      part: 'Part B · Build', ref: '1.3 B', title: 'Place R1 on the breadboard', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, highlightRows: [10, 15]), supply: SupplyRule.mustBeOff,
      text: 'Push one leg of R1 (100 Ω) into row 10 and the other leg into row 15. Use column b for both.',
      tip: 'All five holes in the same numbered row (a to e) are connected inside the breadboard.',
    ),
    LabStep(
      part: 'Part B · Build', ref: '1.3 B', title: 'Place R2 on the breadboard', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, r2: PartKind.r220, highlightRows: [15, 22]), supply: SupplyRule.mustBeOff,
      text: 'Push one leg of R2 (220 Ω) into row 15 and the other leg into row 22. Use column c for both.',
      tip: "R1 and R2 both have a leg in row 15, so they're now connected to each other.",
    ),
    LabStep(
      part: 'Part B · Build', ref: '1.3 B', title: 'Connect 5 V power and ground', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, r2: PartKind.r220, power: true, highlightRows: [10, 22]), supply: SupplyRule.mustBeOff,
      text: 'Connect the 5 V power to row 10 and ground to row 22.',
      how: 'To do this, use the red wire and the black wire as shown in the diagram above.',
      wires: [WireRun(WireColor.red, 'hole a10'), WireRun(WireColor.black, 'hole a22')],
      warn: 'Red and black must never go in the same row. That would short the 5 V supply.',
    ),
    LabStep(
      part: 'Part B · Build', ref: '1.3 B', title: 'Turn on the 5 V output', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, r2: PartKind.r220, power: true), supply: SupplyRule.mustBeOn,
      text: 'Compare your breadboard with the picture one more time. When it matches, turn on the 5 V output below.',
    ),

    // ---- Part C · Measure ----
    LabStep(
      part: 'Part C · Measure', ref: '1.3 C', title: 'Measure the supply voltage (Vs)', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, r2: PartKind.r220, power: true, probeRows: [10, 22]), supply: SupplyRule.mustBeOn,
      text: 'The 5 V supply is never exactly 5.00 V, so measure the real value.',
      how: 'Plug in the meter wires as shown in the diagram above.',
      wires: [WireRun(WireColor.blue, 'hole e10'), WireRun(WireColor.white, 'hole e22')],
      measurement: Measurement(key: 'Vs', label: 'Vs', simulated: 5.031, decimals: 3, mode: _volt),
    ),
    LabStep(
      part: 'Part C · Measure', ref: '1.3 E', title: 'Measure the voltage across R1 (V1)', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, r2: PartKind.r220, power: true, probeRows: [10, 15]), supply: SupplyRule.mustBeOn,
      text: 'Now measure across R1 only.',
      how: 'Leave the blue wire in e10. Move the white wire to e15.',
      wires: [WireRun(WireColor.blue, 'hole e10'), WireRun(WireColor.white, 'hole e15')],
      measurement: Measurement(key: 'V1', label: 'V1', simulated: 1.583, decimals: 3, mode: _volt),
    ),
    LabStep(
      part: 'Part C · Measure', ref: '1.3 E', title: 'Measure the voltage across R2 (V2)', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r100, r2: PartKind.r220, power: true, probeRows: [15, 22]), supply: SupplyRule.mustBeOn,
      text: 'Now measure across R2 only.',
      how: 'Move the blue wire to e15 and the white wire to e22.',
      wires: [WireRun(WireColor.blue, 'hole e15'), WireRun(WireColor.white, 'hole e22')],
      measurement: Measurement(key: 'V2', label: 'V2', simulated: 3.446, decimals: 3, mode: _volt),
    ),

    // ---- Part D · Compare ----
    LabStep(
      part: 'Part D · Compare', ref: '1.3 D, F', title: 'Calculated vs. measured', visual: StepVisual.compare,
      text: "The app plugged your measured R1, R2 and Vs into the voltage divider equations. Here's how close your measurements came.",
      tip: 'A difference of a few percent is normal. It comes from meter accuracy and resistance in the wires.',
      question: 'Record the calculated and measured V1 and V2 and the percent difference for each.',
    ),

    // ---- Part E · Photoresistor ----
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 A', title: 'Photoresistor in room light', visual: StepVisual.loose,
      loose: LoosePart(PartKind.photo, 'Photoresistor'), supply: SupplyRule.mustBeOff,
      text: 'Turn off the 5 V first. Leave your breadboard as it is. Take out the photoresistor: the flat disc with a squiggly line on top.',
      how: 'Clip the blue wire to one leg and the white wire to the other leg.', wires: _leads,
      measurement: Measurement(key: 'PRamb', label: 'Room light', simulated: 5230, decimals: 0, mode: _ohm),
    ),
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 A', title: 'Photoresistor in the dark', visual: StepVisual.loose,
      loose: LoosePart(PartKind.photo, 'Covered with cardstock'), supply: SupplyRule.mustBeOff,
      text: "Hold the cardstock about half an inch above the photoresistor so it's in shadow.",
      measurement: Measurement(key: 'PRdark', label: 'Dark', simulated: 38400, decimals: 0, mode: _ohm),
    ),
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 A–B', title: 'Photoresistor under a flashlight', visual: StepVisual.loose,
      loose: LoosePart(PartKind.photo, 'Under a flashlight'), supply: SupplyRule.mustBeOff,
      text: "Shine your phone's flashlight straight down onto the photoresistor.",
      measurement: Measurement(key: 'PRbright', label: 'Flashlight', simulated: 418, decimals: 0, mode: _ohm),
      question: "In 1–2 sentences: what happens to the photoresistor's resistance as the light level changes?",
    ),
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 C', title: 'Swap in the 10 kΩ and the photoresistor', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.photo, power: true, highlightRows: [10, 22]), supply: SupplyRule.mustBeOff,
      text: 'Take R1 out and put the 10 kΩ resistor (brown, black, orange, gold) in rows 10 to 15. Take R2 out and put the photoresistor in rows 15 to 22.',
      tip: 'Leave the red and black wires where they are.',
    ),
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 C', title: 'Voltage across the photoresistor: room light', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.photo, power: true, probeRows: [15, 22]), supply: SupplyRule.mustBeOn,
      text: 'Turn on the 5 V output, then measure across the photoresistor.',
      how: 'Plug in the meter wires as shown in the diagram above.',
      wires: [WireRun(WireColor.blue, 'hole e15'), WireRun(WireColor.white, 'hole e22')],
      measurement: Measurement(key: 'VPamb', label: 'Room light', simulated: 1.721, decimals: 3, mode: _volt),
    ),
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 C', title: 'Voltage across the photoresistor: dark', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.photo, power: true, probeRows: [15, 22]), supply: SupplyRule.mustBeOn,
      text: 'Keep the wires where they are. Hold the cardstock half an inch above the photoresistor.',
      measurement: Measurement(key: 'VPdark', label: 'Dark', simulated: 3.998, decimals: 3, mode: _volt),
    ),
    LabStep(
      part: 'Part E · Photoresistor', ref: '1.4.1 C–D', title: 'Voltage across the photoresistor: flashlight', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.photo, power: true, probeRows: [15, 22]), supply: SupplyRule.mustBeOn,
      text: "Shine your phone's flashlight straight down onto the photoresistor.",
      measurement: Measurement(key: 'VPbright', label: 'Flashlight', simulated: 0.202, decimals: 3, mode: _volt),
      question: 'In 1–2 sentences: what happens to the voltage as the light level changes?',
    ),

    // ---- Part F · Thermistor ----
    LabStep(
      part: 'Part F · Thermistor', ref: '1.4.2 A', title: 'Thermistor at room temperature', visual: StepVisual.loose,
      loose: LoosePart(PartKind.therm, 'Thermistor'), supply: SupplyRule.mustBeOff,
      text: 'Turn off the 5 V first. Take out the thermistor: the small dark bead with two legs.',
      how: 'Clip the blue wire to one leg and the white wire to the other leg.', wires: _leads,
      measurement: Measurement(key: 'THamb', label: 'Room temp', simulated: 10120, decimals: 0, mode: _ohm),
    ),
    LabStep(
      part: 'Part F · Thermistor', ref: '1.4.2 A–B', title: 'Thermistor when warm', visual: StepVisual.loose,
      loose: LoosePart(PartKind.therm, 'Warmed between palms'), supply: SupplyRule.mustBeOff,
      text: 'Unclip the wires. Rub the thermistor between your palms for about 20 seconds, then clip the wires back on and measure right away.',
      measurement: Measurement(key: 'THwarm', label: 'Warm', simulated: 8640, decimals: 0, mode: _ohm),
      question: "In 1–2 sentences: what happens to the thermistor's resistance as the temperature changes?",
    ),
    LabStep(
      part: 'Part F · Thermistor', ref: '1.4.2 C', title: 'Swap in the thermistor', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.therm, power: true, highlightRows: [15, 22]), supply: SupplyRule.mustBeOff,
      text: 'Take the photoresistor out of rows 15 to 22 and put the thermistor in its place. Keep the 10 kΩ resistor where it is.',
    ),
    LabStep(
      part: 'Part F · Thermistor', ref: '1.4.2 C', title: 'Voltage across the thermistor: room temp', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.therm, power: true, probeRows: [15, 22]), supply: SupplyRule.mustBeOn,
      text: 'Turn on the 5 V output, then measure across the thermistor.',
      how: 'Plug in the meter wires as shown in the diagram above.',
      wires: [WireRun(WireColor.blue, 'hole e15'), WireRun(WireColor.white, 'hole e22')],
      measurement: Measurement(key: 'VTamb', label: 'Room temp', simulated: 2.512, decimals: 3, mode: _volt),
    ),
    LabStep(
      part: 'Part F · Thermistor', ref: '1.4.2 C–D', title: 'Voltage across the thermistor: warm', visual: StepVisual.board,
      board: BoardState(r1: PartKind.r10k, r2: PartKind.therm, power: true, probeRows: [15, 22]), supply: SupplyRule.mustBeOn,
      text: "Pinch the thermistor between your fingertips for about 20 seconds while it's in the breadboard, then measure. 5 V is safe to touch.",
      measurement: Measurement(key: 'VTwarm', label: 'Warm', simulated: 2.318, decimals: 3, mode: _volt),
      question: 'In 1–2 sentences: what happens to the voltage as the temperature changes?',
    ),

    // ---- Finish ----
    LabStep(
      part: 'Finish', ref: '1.4.2 E', title: 'Lab 1 done! Power down', visual: StepVisual.summary, supply: SupplyRule.mustBeOff,
      text: "Turn off the 5 V output and flip the kit's power switch to OFF. Here's everything you recorded.",
      question: 'In 2–3 sentences, describe a practical device that could use one of these circuits as its first stage.',
    ),
  ],
);
