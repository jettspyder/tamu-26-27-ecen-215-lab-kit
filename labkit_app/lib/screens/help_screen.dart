import 'package:flutter/material.dart';

import '../kit/kit_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _wires = [
    (WireColor.red, '+5 V output'),
    (WireColor.yellow, '−5 V output'),
    (WireColor.orange, '+0.5 V output'),
    (WireColor.green, 'Wave gen output'),
    (WireColor.black, 'Ground (all outputs)'),
    (WireColor.blue, 'Meter / probe +'),
    (WireColor.white, 'Meter / probe −'),
  ];

  static const _rules = [
    'Turn every output off before you change any wiring.',
    'Never let an output wire touch the black ground wire.',
    'Check your breadboard against the diagram before turning power on.',
    'Measure resistance, inductance and capacitance with the power off.',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const TabHeader(title: 'Help'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel('Wire colors'),
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final (c, use) in _wires)
                      SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            WireSwatch(c, width: 36),
                            const SizedBox(width: 14),
                            SizedBox(width: 64, child: Text(c.label, style: ts(15, weight: FontWeight.w700))),
                            Expanded(child: Text(use, style: ts(14, color: AppColors.text2))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text('Colors are placeholders until the final kit is built.', style: ts(12, color: AppColors.muted)),
              const SizedBox(height: 18),
              sectionLabel('Safety basics'),
              CardBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in _rules)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(r, style: ts(15, color: AppColors.text2, height: 1.45))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Callout(
                CalloutKind.info,
                "Something doesn't look right? Stop, turn the outputs off, and ask your TA before continuing.",
              ),
              const SizedBox(height: 18),
              Center(child: Text('ECEN 215 Lab Kit · app version 0.1 (simulated kit)', style: ts(12, color: AppColors.muted))),
            ],
          ),
        ),
      ],
    );
  }
}
