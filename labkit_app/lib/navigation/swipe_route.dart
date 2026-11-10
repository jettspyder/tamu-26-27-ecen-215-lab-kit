import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Timings shared by the home screen and the pages it opens, so the two halves
/// of each transition line up.
class Motion {
  static const logo = Duration(milliseconds: 280);
  static const logoOverlap = Duration(milliseconds: 250); // shrink starts before the logo finishes
  static const shrink = Duration(milliseconds: 300);
  static const swipe = Duration(milliseconds: 420);
  static const route = Duration(milliseconds: 700); // swipe-in (0–60%) then grow (57–100%)
  static const curve = Curves.easeInOutCubic;
}

double _interval(double t, double begin, double end) =>
    Motion.curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0).toDouble());

/// Opens a page by sliding it in from the right as a rounded card, then growing it to full screen.
/// Going back plays the exact reverse: shrink, then slide out to the right.
class SwipeRoute<T> extends PageRouteBuilder<T> {
  SwipeRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: Motion.route,
          reverseTransitionDuration: Motion.route,
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            return LayoutBuilder(
              builder: (context, box) => AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) {
                  final slide = _interval(animation.value, 0, 0.6);
                  final grow = _interval(animation.value, 0.57, 1);
                  return Transform.translate(
                    offset: Offset(1.12 * box.maxWidth * (1 - slide), 0),
                    child: Transform.scale(
                      scale: 0.88 + 0.12 * grow,
                      child: PageCard(amount: 1 - grow, child: child!),
                    ),
                  );
                },
              ),
            );
          },
        );
}
