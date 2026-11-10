import 'package:flutter/material.dart';

import '../kit/kit_service.dart';
import '../theme.dart';
import 'common.dart';

/// The safety pop-up shown before anything on the kit turns on.
/// Returns true only if the student taps the confirm button.
Future<bool> confirmPower(
  BuildContext context, {
  required String title,
  required List<(WireColor, String)> wires,
  required List<String> points,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8014141A),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.warnBg, shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warnIcon),
            ),
            const SizedBox(height: 14),
            Text(title, style: ts(20, weight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  for (final (color, role) in wires)
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          WireSwatch(color, width: 30),
                          const SizedBox(width: 12),
                          SizedBox(width: 70, child: Text(color.label, style: ts(14, weight: FontWeight.w700))),
                          Expanded(child: Text(role, style: ts(14, color: AppColors.text2))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                    Expanded(child: Text(p, style: ts(15, color: AppColors.text2, height: 1.45))),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: AppButton(label: 'Cancel', primary: false, height: 50, onTap: () => Navigator.of(ctx).pop(false))),
                const SizedBox(width: 10),
                Expanded(child: AppButton(label: confirmLabel, height: 50, onTap: () => Navigator.of(ctx).pop(true))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
