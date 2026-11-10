import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _scanning = false;
  Timer? _scanTimer;

  // Simulated scan results. The Bluetooth version fills this from a real scan.
  static const _nearby = [('Lab Kit #18', 'Strong signal'), ('Lab Kit #07', 'Weak signal')];

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  void _scan() {
    setState(() => _scanning = true);
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _pick(String name) async {
    await AppScope.read(context).kit.connect(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kit = AppScope.of(context).kit;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(kicker: 'ECEN 215 LAB KIT', title: 'Connect your kit', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  CardBox(
                    child: SizedBox(
                      height: 138,
                      child: Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: const BoxDecoration(color: AppColors.maroonTint, shape: BoxShape.circle),
                          child: Center(
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                              child: const Icon(Icons.bluetooth, color: Colors.white, size: 30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _numbered(1, 'Turn on the kit. The blue light should blink.'),
                  const SizedBox(height: 10),
                  _numbered(2, "Tap Find my kit and pick the number printed on your kit's label."),
                  const SizedBox(height: 18),
                  sectionLabel(_scanning ? 'Searching…' : 'Kits nearby'),
                  if (_scanning)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.maroon)),
                    )
                  else
                    for (final (name, signal) in _nearby)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Pressable(
                          onTap: () => _pick(name),
                          child: CardBox(
                            borderColor: name == kit.name ? AppColors.maroon : null,
                            radius: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: ts(16, weight: FontWeight.w600)),
                                      Text(name == kit.name ? 'Connected' : signal, style: ts(13, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                Text(name == kit.name ? 'Connected' : 'Connect',
                                    style: ts(14, weight: FontWeight.w600, color: AppColors.maroon)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  if (kit.simulated) ...[
                    const SizedBox(height: 6),
                    const Callout(CalloutKind.info, 'This build uses a simulated kit, so no real Bluetooth device is needed.'),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(label: 'Find my kit', onTap: _scanning ? null : _scan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numbered(int n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
          child: Text('$n', style: ts(13, weight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: ts(15, color: AppColors.text2, height: 1.45))),
      ],
    );
  }
}
