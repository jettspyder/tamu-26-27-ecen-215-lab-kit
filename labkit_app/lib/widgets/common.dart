import 'package:flutter/material.dart';

import '../kit/kit_service.dart';
import '../theme.dart';

/// Wraps anything tappable with the "click" look: it sinks slightly and greys out while pressed.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  static const _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

  // Brightness 0.9 with 30% desaturation.
  static const _pressed = <double>[
    0.7487, 0.1610, 0.0163, 0, 0, //
    0.0477, 0.8621, 0.0163, 0, 0, //
    0.0477, 0.1610, 0.7973, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 90),
          offset: Offset(0, _down ? 0.01 : 0.0),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: _down ? 0.97 : 1.0,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_down ? _pressed : _identity),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Large maroon (or outlined) button.
class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, this.onTap, this.primary = true, this.height = 52});

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: primary ? AppColors.maroon : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: primary ? null : Border.all(color: AppColors.buttonBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: ts(16, weight: FontWeight.w600, color: primary ? Colors.white : AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a thin border.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor, this.radius = 16});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border, width: borderColor == null ? 1.0 : 2.0),
      ),
      child: child,
    );
  }
}

enum CalloutKind { tip, warn, info }

/// The tip / warning boxes used throughout the labs.
class Callout extends StatelessWidget {
  const Callout(this.kind, this.text, {super.key});

  final CalloutKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final warn = kind == CalloutKind.warn;
    final bg = warn ? AppColors.warnBg : AppColors.infoBg;
    final border = warn ? AppColors.warnBorder : AppColors.infoBorder;
    final icon = warn ? AppColors.warnIcon : AppColors.infoIcon;
    final fg = warn ? AppColors.warnText : AppColors.infoText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline, size: 20, color: icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ts(14, color: fg, height: 1.45))),
        ],
      ),
    );
  }
}

/// A short colored bar that shows a wire color.
class WireSwatch extends StatelessWidget {
  const WireSwatch(this.color, {super.key, this.width = 36, this.height = 10});

  final WireColor color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.edge, width: 2),
      ),
    );
  }
}

/// On/off switch styled for the kit outputs.
class KitSwitch extends StatelessWidget {
  const KitSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      label: label,
      child: Pressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 60,
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AppColors.maroon : AppColors.switchOff,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Texas A&M logo. [t] = 1 shows the full logo, 0 shows only the ATM square.
/// In between, the words are trimmed from the right.
class TamuLogo extends StatelessWidget {
  const TamuLogo({super.key, this.t = 0});

  final double t;

  static const double height = 38;
  static const double fullWidth = 178;
  static const double squareWidth = 37.6;

  @override
  Widget build(BuildContext context) {
    final k = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    final w = squareWidth + (fullWidth - squareWidth) * k;
    return Semantics(
      label: 'Texas A&M University',
      image: true,
      child: Container(
        width: w,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: fullWidth,
            maxWidth: fullWidth,
            child: Image.asset('assets/images/tamu_full.png', width: fullWidth, height: height, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}

/// "ECEN 215 Lab Kit" kicker + big title + logo, used at the top of each tab.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.logoT = 0});

  final String title;
  final double logoT;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ECEN 215 LAB KIT', style: ts(13, weight: FontWeight.w600, color: AppColors.maroon).copyWith(letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(title, style: ts(28, weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TamuLogo(t: logoT),
        ],
      ),
    );
  }
}

/// Header with a back arrow, used on pushed screens.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.kicker, required this.title, required this.onBack, this.trailing});

  final String kicker;
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 0),
      child: Row(
        children: [
          Pressable(
            onTap: onBack,
            semanticLabel: 'Back',
            child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left, size: 28, color: AppColors.text)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker, style: ts(12, weight: FontWeight.w600, color: AppColors.maroon).copyWith(letterSpacing: 0.5)),
                Text(title, style: ts(16, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          const SizedBox(width: 6),
          const TamuLogo(),
        ],
      ),
    );
  }
}

/// Rounded "card" look a whole page takes while it shrinks during a transition.
class PageCard extends StatelessWidget {
  const PageCard({super.key, required this.amount, required this.child});

  /// 0 = normal full-screen page, 1 = fully shrunk card.
  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28 * amount),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25 * amount), blurRadius: 40, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(28 * amount), child: child),
    );
  }
}

/// Small status pill, e.g. "Simulated".
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.fg = AppColors.green, this.bg = AppColors.greenTint});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: ts(12, weight: FontWeight.w600, color: fg)),
    );
  }
}

Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: ts(14, weight: FontWeight.w600, color: AppColors.muted)),
    );
