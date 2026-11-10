import 'lab1.dart';
import 'lab_model.dart';

class LabListing {
  const LabListing(this.number, this.title, [this.def]);
  final int number;
  final String title;
  final LabDef? def; // null = not built yet

  String get id => 'lab$number';
}

/// Every lab in the ECEN 215 manual. Add a LabDef here as each walkthrough is written.
final List<LabListing> labCatalog = [
  LabListing(1, lab1.title, lab1),
  const LabListing(2, 'Node Voltages & Equivalent Circuits'),
  const LabListing(3, 'Introduction to Op Amps'),
  const LabListing(4, 'First Order RL & RC Transients'),
  const LabListing(5, 'Introduction to AC Signals'),
  const LabListing(6, 'Frequency Response'),
  const LabListing(7, 'Op Amp Integrator & Active Filter'),
  const LabListing(8, 'Introduction to Logic Gates'),
  const LabListing(9, 'Introduction to Microcontrollers'),
];
