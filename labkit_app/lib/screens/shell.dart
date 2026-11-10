import 'package:flutter/material.dart';

import '../navigation/swipe_route.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'connect_screen.dart';
import 'help_screen.dart';
import 'home_screen.dart';
import 'instruments_screen.dart';
import 'lab_screen.dart';
import 'saved_screen.dart';

/// The four main tabs plus every page transition that starts from them.
///
/// Opening a lab: logo shrinks → whole page shrinks into a card → swipes off left
/// while the lab swipes in from the right and grows. Going back is the exact reverse.
/// Switching tabs only animates the logo.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with TickerProviderStateMixin {
  late final AnimationController _logo = AnimationController(vsync: this, duration: Motion.logo); // 1 = square
  late final AnimationController _shrink = AnimationController(vsync: this, duration: Motion.shrink);
  late final AnimationController _swipe = AnimationController(vsync: this, duration: Motion.swipe);

  int _tab = 0;
  bool _busy = false;

  // Tells the Saved tab which lab folder to open (and whether to play the "saving" check).
  String? _savedLab;
  int? _savedJust;
  int _savedSignal = 0;

  bool _instrumentsNote = false;

  @override
  void dispose() {
    _logo.dispose();
    _shrink.dispose();
    _swipe.dispose();
    super.dispose();
  }

  Future<void> _leaveInstrumentsIfNeeded() async {
    final kit = AppScope.read(context).kit;
    if (_tab == 2 && kit.anythingOn) {
      await kit.allOff();
      _instrumentsNote = true;
    }
  }

  Future<void> _selectTab(int i) async {
    if (_busy) return;
    if (i == _tab) {
      if (i == 1) {
        setState(() {
          _savedLab = null;
          _savedJust = null;
          _savedSignal++;
        });
      }
      return;
    }
    await _leaveInstrumentsIfNeeded();
    if (!mounted) return;
    if (_tab == 0) {
      // Leaving home: shrink the full logo into the ATM square first.
      _busy = true;
      await _logo.forward();
      _busy = false;
      if (!mounted) return;
      setState(() => _tab = i);
    } else if (i == 0) {
      // Back to home: start from the square and stretch out to the full logo.
      _logo.value = 1;
      setState(() => _tab = 0);
      _logo.reverse();
    } else {
      setState(() => _tab = i);
    }
  }

  Future<void> _open(Widget page) async {
    if (_busy) return;
    _busy = true;
    _logo.forward();
    await Future<void>.delayed(Motion.logoOverlap);
    if (!mounted) return;
    await _shrink.forward();
    if (!mounted) return;
    _swipe.forward();
    final result = await Navigator.of(context).push<Object?>(SwipeRoute<Object?>(builder: (_) => page));
    if (!mounted) return;

    if (result is LabExitResult && result.exportedAttempt != null) {
      setState(() {
        _tab = 1;
        _savedLab = result.labId;
        _savedJust = result.exportedAttempt;
        _savedSignal++;
      });
    }

    // The page shrinks first; slide back in as it starts moving away.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    await _swipe.reverse();
    if (!mounted) return;
    await _shrink.reverse();
    if (!mounted) return;
    if (_tab == 0) await _logo.reverse();
    _busy = false;
  }

  void _viewResults(String labId) {
    setState(() {
      _logo.value = 1;
      _tab = 1;
      _savedLab = labId;
      _savedJust = null;
      _savedSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(
              logo: _logo,
              onOpenLab: (lab) => _open(LabScreen(lab: lab)),
              onOpenConnect: () => _open(const ConnectScreen()),
              onViewResults: _viewResults,
            ),
            SavedScreen(signal: _savedSignal, focusLab: _savedLab, justSaved: _savedJust),
            InstrumentsScreen(
              showOffNote: _instrumentsNote,
              onClearNote: () => setState(() => _instrumentsNote = false),
            ),
            const HelpScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(index: _tab, onSelect: _selectTab),
    );

    return ColoredBox(
      color: AppColors.stage,
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: Listenable.merge([_shrink, _swipe]),
          child: page,
          builder: (context, child) {
            final s = Motion.curve.transform(_shrink.value);
            final x = Motion.curve.transform(_swipe.value);
            return Transform.translate(
              offset: Offset(-1.12 * box.maxWidth * x, 0),
              child: Transform.scale(
                scale: 1 - 0.12 * s,
                child: PageCard(amount: s, child: child!),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.science_outlined, 'Labs'),
    (Icons.folder_outlined, 'Saved'),
    (Icons.show_chart, 'Instruments'),
    (Icons.help_outline, 'Help'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Pressable(
                    onTap: () => onSelect(i),
                    semanticLabel: _items[i].$2,
                    child: SizedBox(
                      height: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_items[i].$1, size: 22, color: i == index ? AppColors.maroon : AppColors.muted),
                          const SizedBox(height: 4),
                          Text(
                            _items[i].$2,
                            style: ts(12,
                                weight: i == index ? FontWeight.w600 : FontWeight.w400,
                                color: i == index ? AppColors.maroon : AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
