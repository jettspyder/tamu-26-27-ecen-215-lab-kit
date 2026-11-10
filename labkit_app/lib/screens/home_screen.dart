import 'package:flutter/material.dart';

import '../labs/catalog.dart';
import '../labs/lab_model.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.logo,
    required this.onOpenLab,
    required this.onOpenConnect,
    required this.onViewResults,
  });

  /// 0 = full logo, 1 = ATM square.
  final Animation<double> logo;
  final ValueChanged<LabDef> onOpenLab;
  final VoidCallback onOpenConnect;
  final ValueChanged<String> onViewResults;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final kit = app.kit;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AnimatedBuilder(
          animation: logo,
          builder: (context, _) => TabHeader(title: 'Your labs', logoT: 1 - Curves.easeInOutCubic.transform(logo.value)),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Pressable(
            onTap: onOpenConnect,
            child: CardBox(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.maroonTint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.bluetooth, color: AppColors.maroon),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kit.name, style: ts(16, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(kit.connected ? 'Connected' : 'Not connected', style: ts(13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  if (kit.simulated) const Pill('Simulated'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _UpNextCard(
            listing: labCatalog.first,
            onOpenLab: onOpenLab,
            onViewResults: onViewResults,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
          child: Text('All labs', style: ts(14, weight: FontWeight.w600, color: AppColors.muted)),
        ),
        for (final l in labCatalog)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _LabRow(listing: l, onOpenLab: onOpenLab),
          ),
      ],
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.listing, required this.onOpenLab, required this.onViewResults});

  final LabListing listing;
  final ValueChanged<LabDef> onOpenLab;
  final ValueChanged<String> onViewResults;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final lab = listing.def!;
    final p = app.progressFor(lab.id);
    final attempts = app.attemptsFor(lab.id);
    final total = lab.steps.length;

    String kicker, detail, button;
    double pct;
    VoidCallback onButton;
    final showStartOver = p.started || attempts.isNotEmpty;
    if (p.started) {
      final n = (p.step + 1).clamp(1, total).toInt();
      kicker = 'Continue where you left off';
      detail = 'Step $n of $total · ${lab.steps[n - 1].title}';
      pct = n / total;
      button = 'Resume';
      onButton = () => onOpenLab(lab);
    } else if (attempts.isNotEmpty) {
      kicker = 'Lab ${lab.number} complete';
      detail = '${attempts.length} ${attempts.length == 1 ? 'export' : 'exports'} saved';
      pct = 1;
      button = 'View results';
      onButton = () => onViewResults(lab.id);
    } else {
      kicker = 'Up next';
      detail = '$total steps, one at a time';
      pct = 0;
      button = 'Start';
      onButton = () => onOpenLab(lab);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker, style: ts(13, color: const Color(0xD9FFFFFF))),
          const SizedBox(height: 8),
          Text('Lab ${lab.number} · ${lab.title}', style: ts(20, weight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(detail, style: ts(14, color: Colors.white, height: 1.4)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0x40FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (showStartOver)
                Pressable(
                  onTap: () {
                    final a = AppScope.read(context);
                    a.clearProgress(lab.id);
                    if (!p.started) onOpenLab(lab);
                  },
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        'Start over',
                        style: ts(14, weight: FontWeight.w500, color: const Color(0xD9FFFFFF))
                            .copyWith(decoration: TextDecoration.underline, decorationColor: const Color(0xD9FFFFFF)),
                      ),
                    ),
                  ),
                )
              else
                Text('Lab procedure only', style: ts(13, color: const Color(0xD9FFFFFF))),
              const Spacer(),
              Pressable(
                onTap: onButton,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Text(button, style: ts(15, weight: FontWeight.w600, color: AppColors.maroon)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabRow extends StatelessWidget {
  const _LabRow({required this.listing, required this.onOpenLab});

  final LabListing listing;
  final ValueChanged<LabDef> onOpenLab;

  @override
  Widget build(BuildContext context) {
    final def = listing.def;
    final app = AppScope.of(context);
    String sub;
    bool active = def != null;
    if (def == null) {
      sub = 'Coming soon';
    } else {
      final p = app.progressFor(def.id);
      final n = app.attemptsFor(def.id).length;
      if (p.started) {
        sub = 'In progress · ${(p.step + 1).clamp(1, def.steps.length).toInt()} of ${def.steps.length}';
      } else if (n > 0) {
        sub = 'Completed · $n ${n == 1 ? 'export' : 'exports'}';
      } else {
        sub = 'Ready · ${def.steps.length} steps';
      }
    }

    final row = CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 14,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? AppColors.maroonTint : AppColors.divider, shape: BoxShape.circle),
            child: Text('${listing.number}',
                style: ts(14, weight: FontWeight.w700, color: active ? AppColors.maroon : AppColors.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, style: ts(15, weight: FontWeight.w600)),
                Text(sub, style: ts(13, color: AppColors.muted)),
              ],
            ),
          ),
          if (active) const Icon(Icons.chevron_right, color: AppColors.faint),
        ],
      ),
    );

    if (def == null) return row;
    return Pressable(onTap: () => onOpenLab(def), child: row);
  }
}
