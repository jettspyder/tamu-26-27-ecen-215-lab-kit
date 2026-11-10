import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit/kit_service.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Swap this for the Bluetooth kit once the firmware's BLE service is ready.
  // Every screen talks to KitService, so nothing else needs to change.
  final KitService kit = SimulatedKit();

  runApp(LabKitApp(state: AppState(prefs, kit)));
}

class LabKitApp extends StatelessWidget {
  const LabKitApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'ECEN 215 Lab Kit',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) => _PhoneFrame(child: child ?? const SizedBox()),
        home: const Shell(),
      ),
    );
  }
}

/// On a laptop or tablet, shows the app inside a phone-sized frame for demos.
/// On a real phone it fills the screen as normal.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 600) return child;
    final h = min(860.0, mq.size.height - 40);
    const w = 400.0;
    return ColoredBox(
      color: const Color(0xFF2B2B30),
      child: Center(
        child: Container(
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16))],
          ),
          child: MediaQuery(
            data: mq.copyWith(size: Size(w, h), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
            child: child,
          ),
        ),
      ),
    );
  }
}
