import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/location.dart';
import '../../models/tour_flow.dart';
import '../../providers/ssh_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/film_dialog.dart';
import '../../shared/widgets/sync_map_view.dart';
import 'fullscreen_map_screen.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.args});

  final TourFlowArgs args;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  // The stop the map is focused on (set by tapping a location card). Null = the
  // opening "frame all stops" view.
  TourLocation? _focus;

  @override
  void dispose() {
    // Leaving the preview → stop mirroring the phone map to the rig.
    MapSyncService.instance.disable();
    super.dispose();
  }

  /// Preview must NOT mirror to the rig (Andreu: pre-tour exploration stays on
  /// the phone). The map still pans/animates locally — MapSyncService simply
  /// stays disabled, so its idle handler is a silent no-op and nothing reaches
  /// LG. We proactively turn it off here in case a previous screen (e.g.
  /// Inspection) left it enabled.
  void _ensureSyncOff() {
    if (MapSyncService.instance.isEnabled) MapSyncService.instance.disable();
  }

  Future<void> _start(BuildContext context) async {
    if (!ref.read(sshConnectionProvider).isConnected) {
      await _showConnectDialog(context);
      return;
    }

    final choice = await showFilmDialog(context);
    if (choice == null || !context.mounted) return; // cancelled

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deploying tour to Liquid Galaxy…')),
    );
    unawaited(
      ref
          .read(sshConnectionProvider.notifier)
          .flyGeneratedTour(widget.args.locations)
          .catchError((Object e) {
            debugPrint('Preview: rig flight error: $e');
            return 0;
          }),
    );

    if (!context.mounted) return;
    context.push(
      '/home/active',
      extra: widget.args.copyWith(generateFilm: choice),
    );
  }

  Future<void> _showConnectDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cast_connected_rounded),
        title: const Text('Connect to Liquid Galaxy'),
        content: const Text(
          'Connect to your Liquid Galaxy rig first via LG Connection Settings '
          'to start the immersive tour.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/settings/lg');
                  },
                  child: const Text('LG Connection Settings'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations = widget.args.locations;
    _ensureSyncOff();

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'Your tour is ready',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Preview the journey before launching it on Liquid Galaxy.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SyncMapView(
                  locations: locations,
                  height: 200,
                  focusLocation: _focus,
                  showSyncChip: false, // preview doesn't mirror to LG
                  onExpand: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FullscreenMapScreen(
                        locations: locations,
                        focus: _focus,
                        syncToLg: false, // stay on the phone during preview
                        title: 'Explore locations',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.push('/home/inspection', extra: widget.args),
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: const Text('Inspect locations'),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: locations.length,
                  itemBuilder: (_, i) => _LocationCard(
                    index: i + 1,
                    location: locations[i],
                    selected: identical(_focus, locations[i]),
                    onTap: locations[i].latitude == null
                        ? null
                        : () => setState(() => _focus = locations[i]),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text('Start Immersive Tour'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.index,
    required this.location,
    this.onTap,
    this.selected = false,
  });

  final int index;
  final TourLocation location;
  final VoidCallback? onTap;
  final bool selected;

  static const _colors = [
    AppColors.googleRed,
    AppColors.googleYellow,
    AppColors.googleGreen,
    AppColors.googleBlueBright,
    AppColors.tileClearLogo,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colors[(index - 1) % _colors.length];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place, color: color),
          const Spacer(),
          Text(
            index.toString().padLeft(2, '0'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            location.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            location.type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          ],
        ),
      ),
    );
  }
}
