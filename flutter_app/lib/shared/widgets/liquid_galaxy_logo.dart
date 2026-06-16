import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The small 4-bar "liquid galaxy" brand mark shown in the app header,
/// optionally with the lowercase wordmark beneath it (as in the mockups).
class LiquidGalaxyLogo extends StatelessWidget {
  const LiquidGalaxyLogo({super.key, this.barHeight = 22, this.showWordmark = true});

  final double barHeight;
  final bool showWordmark;

  // Brand colors + relative bar heights (equalizer-style, per the mockup).
  static const _bars = <(Color, double)>[
    (AppColors.googleBlueBright, 0.72),
    (AppColors.googleRed, 1.0),
    (AppColors.googleYellow, 0.58),
    (AppColors.googleGreen, 0.86),
  ];

  @override
  Widget build(BuildContext context) {
    final barWidth = barHeight * 0.22;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: barHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (color, h) in _bars) ...[
                Container(
                  width: barWidth,
                  height: barHeight * h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(barWidth / 2),
                  ),
                ),
                SizedBox(width: barWidth * 0.5),
              ],
            ],
          ),
        ),
        if (showWordmark)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'liquid galaxy',
              style: TextStyle(
                fontSize: barHeight * 0.32,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}
