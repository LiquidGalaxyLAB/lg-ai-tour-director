import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/location.dart';
import '../../providers/ssh_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../shared/widgets/sync_map_view.dart';

class VirtualReplayScreen extends ConsumerStatefulWidget {
  const VirtualReplayScreen({
    super.key,
    required this.title,
    required this.locations,
  });

  final String title;
  final List<TourLocation> locations;

  @override
  ConsumerState<VirtualReplayScreen> createState() =>
      _VirtualReplayScreenState();
}

class _VirtualReplayScreenState extends ConsumerState<VirtualReplayScreen> {
  @override
  void initState() {
    super.initState();
    // Turn sync on for the exploration session if the rig is connected.
    final ssh = ref.read(sshConnectionProvider);
    if (ssh.isConnected) {
      MapSyncService.instance.updateRigCount(ssh.config.totalScreens);
      MapSyncService.instance.enable();
    }
  }

  @override
  void dispose() {
    MapSyncService.instance.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SyncMapView(locations: widget.locations, frameAllLocations: true),
    );
  }
}
