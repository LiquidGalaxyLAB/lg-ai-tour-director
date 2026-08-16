import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Styled stand-in for the interactive map, used where the real
/// `google_maps_flutter` view isn't available (e.g. web without a Maps SDK key).
/// so the screens stay faithful and runnable everywhere.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({
    super.key,
    this.height = 200,
    this.markerCount = 0,
    this.synced = false,
    this.label,
  });

  final double height;
  final int markerCount;
  final bool synced;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE8EDF2),
              const Color(0xFFDDE6EE),
              AppColors.googleGreen.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Faint "roads"
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(theme.colorScheme)),
            ),
            if (markerCount > 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 14,
                  children: [
                    for (var i = 1; i <= markerCount; i++) _PinChip(number: i),
                  ],
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label ?? 'Map preview',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (synced)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.connected,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Synced with Liquid Galaxy',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinChip extends StatelessWidget {
  const _PinChip({required this.number});
  final int number;

  // Brand color cycle for pins.
  static const _colors = [
    AppColors.googleRed,
    AppColors.googleBlueBright,
    AppColors.googleGreen,
    AppColors.tileSetRefresh,
    AppColors.tileClearLogo,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[(number - 1) % _colors.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const Icon(Icons.arrow_drop_down, size: 14, color: Colors.black26),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.scheme);
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 6;
    // A couple of diagonal "roads".
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.2),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height),
      Offset(size.width, size.height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.3),
      Offset(size.width, size.height * 0.8),
      paint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
