import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/location.dart';
import '../../models/tour_flow.dart';
import '../../models/video_generation_result.dart';
import '../../providers/ai_film_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tour_draft_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../services/video/video_provider_factory.dart';
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
  // Stop the map is focused on; null = the "frame all stops" view.
  TourLocation? _focus;

  @override
  void initState() {
    super.initState();
    // Stash the generated tour so it survives the route being popped; Home's
    // "continue your tour" banner re-opens Preview from this draft.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(tourDraftProvider.notifier).set(widget.args);
    });
  }

  @override
  void dispose() {
    // Leaving the preview → stop mirroring the phone map to the rig.
    MapSyncService.instance.disable();
    super.dispose();
  }

  /// Preview must not mirror to the rig (pre-tour exploration stays on the
  /// phone), so sync is proactively disabled here.
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

    var generateFilm = choice;
    if (choice == true) {
      // Verify the AI Film connection before the tour starts; on failure the
      // user can fix settings, view help, or start without a film.
      final decision = await _verifyFilmConnection(context);
      if (decision == null || !context.mounted) return; // abort start
      generateFilm = decision; // true = verified ok; false = start without film
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('deploying_tour_to_lg'.tr())),
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
      extra: widget.args.copyWith(generateFilm: generateFilm),
    );
  }

  /// Live connection test for the AI Film provider. Returns true (start with
  /// film), false (start without film), or null (abort the tour start).
  Future<bool?> _verifyFilmConnection(BuildContext context) async {
    final settings = ref.read(aiFilmProvider).settings;

    // Not turned on → there's nothing to test; guide the user to set it up.
    if (!settings.isEnabled) {
      return _showFilmErrorDialog(context, 'ai_film_not_enabled_msg'.tr());
    }

    // Blocking spinner while we hit the provider.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VerifyingDialog(),
    );

    var ok = false;
    String? error;
    try {
      final provider = VideoProviderFactory.create(settings);
      ok = await provider.testConnection();
    } on VideoGenerationException catch (e) {
      error = e.userMessage;
    } catch (e) {
      error = e.toString();
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close the spinner
    }
    if (!context.mounted) return null;

    if (ok) return true;
    return _showFilmErrorDialog(context, error ?? 'connection_failed'.tr());
  }

  /// Error dialog when the AI Film connection can't be verified. Returns false
  /// for "start without film", otherwise null (abort).
  Future<bool?> _showFilmErrorDialog(BuildContext context, String message) {
    final theme = Theme.of(context);
    return showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
        title: Text('ai_film_connection_failed_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Text(
              'ai_film_help_suggestion'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
                    Navigator.pop(ctx); // abort start (null)
                    context.push('/settings/ai-film?returnToTour=true');
                  },
                  child: Text('open_ai_film_settings'.tr()),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // abort start (null)
                    context.push('/settings/help');
                  },
                  child: Text('view_help'.tr()),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // start w/o film
                child: Text('start_without_film'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx), // abort (null)
                child: Text('cancel'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConnectDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cast_connected_rounded),
        title: Text('connect_to_liquid_galaxy'.tr()),
        content: Text('connect_to_lg_rig_first'.tr()),
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
                  child: Text('lg_connection_settings'.tr()),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr()),
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
                  'your_tour_is_ready'.tr(),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'preview_journey_before_launching'.tr(),
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
                        title: 'explore_locations'.tr(),
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
                    label: Text('inspect_locations'.tr()),
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
                  label: Text('start_immersive_tour'.tr()),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // Explicit discard: drop the saved draft so Home stops
                    // offering the "continue your tour" banner.
                    ref.read(tourDraftProvider.notifier).clear();
                    context.pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text('cancel'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyingDialog extends StatelessWidget {
  const _VerifyingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 18),
          Expanded(child: Text('verifying_ai_film'.tr())),
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
