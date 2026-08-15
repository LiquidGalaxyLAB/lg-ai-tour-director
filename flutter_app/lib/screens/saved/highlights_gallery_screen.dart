import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/location.dart';
import '../../shared/widgets/location_image.dart';

class HighlightsGalleryScreen extends StatefulWidget {
  const HighlightsGalleryScreen({
    super.key,
    required this.title,
    required this.locations,
    this.initialIndex = 0,
  });

  final String title;
  final List<TourLocation> locations;
  final int initialIndex;

  @override
  State<HighlightsGalleryScreen> createState() =>
      _HighlightsGalleryScreenState();
}

class _HighlightsGalleryScreenState extends State<HighlightsGalleryScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.locations.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.locations.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _GalleryPage(
              index: i,
              total: total,
              location: widget.locations[i],
            ),
          ),

          // Top bar: back + tour title + counter.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // Page-indicator dots.
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPage extends StatelessWidget {
  const _GalleryPage({
    required this.index,
    required this.total,
    required this.location,
  });

  final int index;
  final int total;
  final TourLocation location;

  bool get _hasCoords =>
      location.latitude != null && location.longitude != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed image (reuses the app's resolver + fallback chain).
        LocationImage(location: location, fit: BoxFit.cover, borderRadius: 0),

        // Bottom scrim so text stays legible over any image.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
        ),

        // Text content.
        Align(
          alignment: Alignment.bottomLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STOP ${(index + 1).toString().padLeft(2, '0')} OF '
                  '${total.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  location.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(blurRadius: 10, color: Colors.black),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (location.type.trim().isNotEmpty &&
                        location.type.toLowerCase() != 'unknown')
                      _Pill(
                        icon: Icons.category_outlined,
                        label: location.type.toUpperCase(),
                      ),
                    if (_hasCoords)
                      _Pill(
                        icon: Icons.place_outlined,
                        label:
                            '${location.latitude!.toStringAsFixed(3)}, '
                            '${location.longitude!.toStringAsFixed(3)}',
                      ),
                  ],
                ),
                if (location.whySignificant.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    location.whySignificant,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
