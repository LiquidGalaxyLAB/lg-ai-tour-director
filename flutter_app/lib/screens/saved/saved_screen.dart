import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/saved_tour.dart';
import '../../providers/library_provider.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/location_image.dart';

/// Saved tab (mockups 13/14): the library of tours the user persisted (with
/// KML). Persisted via [savedToursProvider]. Filters Offline/Curated and the
/// playlist categories are stubbed ("coming soon") until those features land.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  int _filter = 0;
  static const _filters = [
    'filter_all_tours',
    'filter_recent',
    'filter_offline',
    'filter_curated',
  ];
  static const _stubFilters = {2, 3}; // Offline, Curated

  static const _categories = <(String, IconData, Color)>[
    (
      'category_museums',
      Icons.account_balance_rounded,
      AppColors.googleBlueBright,
    ),
    ('category_temples', Icons.temple_hindu_rounded, AppColors.tileSetRefresh),
    ('category_food_walks', Icons.restaurant_rounded, AppColors.googleRed),
    ('category_nature', Icons.forest_rounded, AppColors.googleGreen),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tours = ref.watch(savedToursProvider).value ?? const <SavedTour>[];
    final locationCount = tours.fold<int>(0, (sum, t) => sum + t.stopCount);

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Center(
                  child: Text(
                    'saved_tours_title'.tr(),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'saved_tours_subtitle'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.folder_outlined,
                        label: '${tours.length} Tours',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.place_outlined,
                        label: '$locationCount Locations',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _filters.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_filters[i].tr()),
                            selected: _filter == i,
                            onSelected: _stubFilters.contains(i)
                                ? null
                                : (_) => setState(() => _filter = i),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('playlist_categories'.tr()),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    for (final (label, icon, color) in _categories)
                      _CategoryTile(label: label, icon: icon, color: color),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionLabel('saved_tour_library'.tr()),
                const SizedBox(height: 12),
                if (tours.isEmpty)
                  EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'no_saved_tours_yet'.tr(),
                    message: 'no_saved_tours_message'.tr(),
                  )
                else ...[
                  for (final t in tours)
                    _SavedCard(
                      tour: t,
                      onTap: () => context.push('/saved/detail', extra: t),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        letterSpacing: 1,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(
            label.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.tour, required this.onTap});
  final SavedTour tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Real thumbnail of the first stop (Wikipedia→Unsplash, cached);
                // LocationImage shows its own placeholder while loading / if none
                if (tour.locations.isNotEmpty)
                  LocationImage(
                    location: tour.locations.first,
                    height: 150,
                    width: double.infinity,
                    borderRadius:
                        0, // outer Container already clips the corners
                  )
                else
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.googleBlueBright,
                          AppColors.googleBlue,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_outlined,
                      color: Colors.white24,
                      size: 48,
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Badge(label: '${tour.stopCount} Stops'),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 16,
                    child: Icon(
                      tour.isFavourite ? Icons.favorite : Icons.favorite_border,
                      color: AppColors.googleRed,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'saved_tour'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
