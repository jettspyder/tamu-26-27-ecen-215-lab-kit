import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../labs/catalog.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'lab_screen.dart' show SummaryCard;

/// Saved results: lab folders → export attempts → one attempt's data.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, required this.signal, this.focusLab, this.justSaved});

  /// Changes whenever the shell wants this tab to jump somewhere.
  final int signal;
  final String? focusLab;

  /// Attempt number that was just exported (plays the saving → check animation).
  final int? justSaved;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String? _lab;
  int? _attempt;
  int? _spinFor;
  bool _spinDone = false;
  Timer? _spinTimer;

  @override
  void didUpdateWidget(covariant SavedScreen old) {
    super.didUpdateWidget(old);
    if (old.signal != widget.signal) {
      _spinTimer?.cancel();
      _lab = widget.focusLab;
      _attempt = null;
      _spinFor = widget.justSaved;
      _spinDone = false;
      if (_spinFor != null) {
        _spinTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _spinDone = true);
        });
      }
    }
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  LabListing _listing(String id) => labCatalog.firstWhere((l) => l.id == id);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (_lab == null) return _folders(app);
    final listing = _listing(_lab!);
    final attempts = app.attemptsFor(listing.id);
    if (_attempt != null) {
      final a = attempts.where((x) => x.number == _attempt).toList();
      if (a.isNotEmpty) return _attemptView(listing, a.first);
    }
    return _labView(listing, attempts);
  }

  Widget _folders(AppState app) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const TabHeader(title: 'Saved'),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Callout(CalloutKind.info, 'Every export is kept on this phone. Tap a lab to see all of its export attempts.'),
        ),
        for (final l in labCatalog)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _folderRow(l, app.attemptsFor(l.id)),
          ),
      ],
    );
  }

  Widget _folderRow(LabListing l, List<ExportAttempt> attempts) {
    final has = attempts.isNotEmpty;
    final sub = has
        ? '${attempts.length} export ${attempts.length == 1 ? 'attempt' : 'attempts'} · latest ${attempts.last.timeLabel}'
        : 'Nothing saved yet';
    final row = CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: has ? AppColors.maroonTint : AppColors.divider, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.folder_outlined, size: 20, color: has ? AppColors.maroon : AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lab ${l.number} · ${l.title}', style: ts(15, weight: has ? FontWeight.w700 : FontWeight.w600)),
                Text(sub, style: ts(13, color: AppColors.muted)),
              ],
            ),
          ),
          if (has) const Icon(Icons.chevron_right, color: AppColors.faint),
        ],
      ),
    );
    if (!has) return row;
    return Pressable(onTap: () => setState(() => _lab = l.id), child: row);
  }

  Widget _labView(LabListing l, List<ExportAttempt> attempts) {
    final newest = attempts.isEmpty ? null : attempts.last;
    final showSaving = _spinFor != null && newest != null && newest.number == _spinFor;
    return Column(
      children: [
        BackHeader(
          kicker: 'SAVED',
          title: 'Lab ${l.number} · ${l.title}',
          onBack: () => setState(() {
            _lab = null;
            _spinFor = null;
          }),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (showSaving) ...[
                _savingCard(l, newest!),
                const SizedBox(height: 16),
              ],
              sectionLabel('Export attempts'),
              if (attempts.isEmpty)
                Text('No exports yet. Finish the lab and tap Export results.', style: ts(14, color: AppColors.muted)),
              for (final a in attempts.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Pressable(
                    onTap: () => setState(() => _attempt = a.number),
                    child: CardBox(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: AppColors.maroon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Export Attempt ${a.number}', style: ts(15, weight: FontWeight.w700)),
                                Text('${a.dateLabel} · ${a.timeLabel}', style: ts(13, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          if (a.number == newest?.number) const Pill('Latest'),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: AppColors.faint),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _savingCard(LabListing l, ExportAttempt a) {
    return CardBox(
      borderColor: AppColors.maroon,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: _spinDone
                ? Container(
                    key: const ValueKey('done'),
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 34),
                  )
                : const SizedBox(
                    key: ValueKey('spin'),
                    width: 64,
                    height: 64,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        color: AppColors.maroon,
                        backgroundColor: Color(0xFFEDE3E3),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(_spinDone ? 'Export Attempt ${a.number} saved' : 'Saving Export Attempt ${a.number}…',
              style: ts(16, weight: FontWeight.w700)),
          if (_spinDone) ...[
            const SizedBox(height: 2),
            Text('${a.dateLabel} · ${a.timeLabel}', style: ts(13, color: AppColors.muted)),
            const SizedBox(height: 12),
            _exportButtons(l, a),
          ],
        ],
      ),
    );
  }

  Widget _exportButtons(LabListing l, ExportAttempt a) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Copy CSV',
            height: 48,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: a.toCsv('Lab ${l.number} · ${l.title}')));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied. Paste it into Excel or Google Sheets.')),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton(
            label: 'PDF',
            primary: false,
            height: 48,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF export is coming in the next build.')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attemptView(LabListing l, ExportAttempt a) {
    final questions = l.def?.questions ?? const <String>[];
    TextStyle head() => ts(12, weight: FontWeight.w600, color: AppColors.muted);
    return Column(
      children: [
        BackHeader(
          kicker: 'LAB ${l.number} · SAVED',
          title: 'Export Attempt ${a.number}',
          onBack: () => setState(() => _attempt = null),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('Saved ${a.dateLabel} · ${a.timeLabel}', style: ts(14, color: AppColors.muted)),
              const SizedBox(height: 12),
              _exportButtons(l, a),
              const SizedBox(height: 18),
              sectionLabel('Measurements'),
              for (final s in a.sections)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: SummaryCard(title: s.title, rows: s.rows)),
              if (a.compare.isNotEmpty) ...[
                const SizedBox(height: 4),
                sectionLabel('Calculated vs. measured'),
                CardBox(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Column(
                    children: [
                      Row(children: [
                        const Expanded(child: SizedBox()),
                        Expanded(child: Text('Calculated', style: head())),
                        Expanded(child: Text('Measured', style: head())),
                        Expanded(child: Text('% diff', style: head())),
                      ]),
                      const SizedBox(height: 6),
                      for (final c in a.compare)
                        Container(
                          constraints: const BoxConstraints(minHeight: 38),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                          child: Row(children: [
                            Expanded(child: Text(c.label, style: ts(14, weight: FontWeight.w700))),
                            Expanded(child: Text(c.calc, style: AppFonts.mono(size: 13, weight: FontWeight.w500))),
                            Expanded(child: Text(c.meas, style: AppFonts.mono(size: 13, weight: FontWeight.w500))),
                            Expanded(child: Text(c.diff, style: AppFonts.mono(size: 13, color: AppColors.green))),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
              if (questions.isNotEmpty) ...[
                const SizedBox(height: 16),
                sectionLabel('Report questions'),
                CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < questions.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 22, child: Text('${i + 1}', style: ts(14, weight: FontWeight.w700, color: AppColors.maroon))),
                              Expanded(child: Text(questions[i], style: ts(14, height: 1.45))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
