import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/location.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tour_state_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../shared/widgets/sync_map_view.dart';

class FullscreenMapScreen extends ConsumerStatefulWidget {
  const FullscreenMapScreen({
    super.key,
    required this.locations,
    this.focus,
    this.pauseTour = false,
    this.syncToLg = true,
    this.title = 'Explore · move the map to fly LG',
  });

  final List<TourLocation> locations;
  final TourLocation? focus;
  final bool pauseTour;

  final bool syncToLg;
  final String title;

  @override
  ConsumerState<FullscreenMapScreen> createState() =>
      _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends ConsumerState<FullscreenMapScreen> {
  bool _didPause = false;

  @override
  void initState() {
    super.initState();
    final ssh = ref.read(sshConnectionProvider);
    if (widget.syncToLg && ssh.isConnected) {
      MapSyncService.instance.updateRigCount(ssh.config.totalScreens);
      MapSyncService.instance.enable();
    } else {
      MapSyncService.instance.disable();
    }
    // Pause the flight while exploring (only if it wasn't already paused).
    if (widget.pauseTour) {
      final tour = ref.read(tourStateProvider.notifier);
      if (ref.read(tourStateProvider).isRunning &&
          !ref.read(tourStateProvider).isPaused) {
        tour.pause();
        _didPause = true;
      }
    }
  }

  @override
  void dispose() {
    MapSyncService.instance.disable();
    // Resume only the pause WE caused, so we don't override a user-held pause.
    if (_didPause) {
      ref.read(tourStateProvider.notifier).resume();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SyncMapView(
        locations: widget.locations,
        focusLocation: widget.focus,
        frameAllLocations: widget.focus == null,
        showSyncChip: widget.syncToLg, // no "Synced" chip when phone-only
      ),
    );
  }
}
