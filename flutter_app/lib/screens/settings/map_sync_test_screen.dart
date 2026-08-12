import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/location.dart';
import '../../providers/ssh_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../shared/widgets/sync_map_view.dart';

class MapSyncTestScreen extends ConsumerStatefulWidget {
  const MapSyncTestScreen({super.key});

  @override
  ConsumerState<MapSyncTestScreen> createState() => _MapSyncTestScreenState();
}

class _MapSyncTestScreenState extends ConsumerState<MapSyncTestScreen> {
  static const _start = TourLocation(
    name: 'Shaniwar Wada',
    type: 'Test',
    whySignificant: '',
    suggestedDurationSeconds: 0,
    latitude: 18.5195,
    longitude: 73.8553,
  );

  @override
  void initState() {
    super.initState();
    final ssh = ref.read(sshConnectionProvider);
    MapSyncService.instance.updateRigCount(ssh.config.totalScreens);
    MapSyncService.instance.enable();
  }

  @override
  void dispose() {
    MapSyncService.instance.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Map Sync')),
      body: const SyncMapView(locations: [_start], frameAllLocations: false),
    );
  }
}
