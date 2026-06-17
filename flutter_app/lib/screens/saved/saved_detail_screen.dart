import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/saved_tour.dart';
import '../../providers/library_provider.dart';
import '../../shared/widgets/map_placeholder.dart';

/// Saved tour detail (mockups 15 & 16): hero, replay, highlights album, route
/// path, and Share / Export KML / Remove. Replay re-sends the saved KML to LG
/// (wired when the KML engine + deploy path land).
class SavedDetailScreen extends ConsumerWidget {
  const SavedDetailScreen({super.key, required this.tour});

  final SavedTour tour;

  void _stub(BuildContext context, String label) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label — coming soon')),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Reflect live favourite/state from the library; fall back to the passed-in
    // tour (e.g. sample data that isn't in the store).
    final tours = ref.watch(savedToursProvider).value ?? const <SavedTour>[];
    final tour = tours.firstWhere((t) => t.id == this.tour.id,
        orElse: () => this.tour);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: () =>
                    ref.read(savedToursProvider.notifier).toggleFavourite(tour.id),
                icon: Icon(
                  tour.isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => _stub(context, 'Share'),
                icon: const Icon(Icons.share),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.googleBlue, AppColors.googleBlueBright],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('HISTORICAL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  letterSpacing: 1)),
                        ),
                        const SizedBox(height: 8),
                        Text(tour.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text('${tour.durationMin} min',
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(width: 12),
                            const Icon(Icons.straighten,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text('${tour.distanceKm} km',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(children: [
              FilledButton.icon(
                onPressed: () => _stub(context, 'Virtual replay'),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Start Virtual Replay'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _stub(context, 'Replay on rig'),
                icon: const Icon(Icons.cast),
                label: const Text('Replay on Liquid Galaxy'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Highlights Album', style: theme.textTheme.titleMedium),
                  Text('View All (${tour.stopCount})',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tour.locations.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _HighlightCard(index: i + 1, name: tour.locations[i].name),
                ),
              ),
              const SizedBox(height: 24),
              Text('Route Path', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              MapPlaceholder(height: 180, markerCount: tour.stopCount),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Action(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () => _stub(context, 'Share'),
                  ),
                  _Action(
                    icon: Icons.download,
                    label: 'Export KML',
                    onTap: () => _stub(context, 'Export KML'),
                  ),
                  _Action(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: theme.colorScheme.error,
                    onTap: () {
                      ref.read(savedToursProvider.notifier).remove(tour.id);
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from library')),
                      );
                    },
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.index, required this.name});
  final int index;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.googleBlueBright, AppColors.googleGreen],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.photo_outlined, color: Colors.white24),
          ),
          const SizedBox(height: 6),
          Text('STOP ${index.toString().padLeft(2, '0')}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: c),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: c)),
          ],
        ),
      ),
    );
  }
}
