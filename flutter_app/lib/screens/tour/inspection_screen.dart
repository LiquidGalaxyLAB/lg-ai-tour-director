import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tour_flow.dart';
import '../../providers/ssh_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../shared/widgets/sync_map_view.dart';
import 'fullscreen_map_screen.dart';

/// Inspection Mode (mockup 6): step through the tour's stops on a real satellite
/// map; the map flies to each stop (and mirrors to the LG rig in real time).
class InspectionScreen extends ConsumerStatefulWidget {
  const InspectionScreen({super.key, required this.args});

  final TourFlowArgs args;

  @override
  ConsumerState<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends ConsumerState<InspectionScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Free exploration screen → mirror the phone map to the rig while open.
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
    final theme = Theme.of(context);
    final locations = widget.args.locations;
    final loc = locations[_index];

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Mode')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'INSPECTING SCENE ${(_index + 1).toString().padLeft(2, '0')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      loc.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SyncMapView(
                  locations: locations,
                  frameAllLocations: false,
                  focusLocation: loc, // flies to the inspected stop
                  showSyncChip: false,
                  onExpand: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FullscreenMapScreen(locations: locations, focus: loc),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Move the map to explore locations. The Liquid Galaxy rig will '
                'mirror your navigation in real time.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(_index + 1).toString().padLeft(2, '0')} ${loc.name}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            loc.type,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _index == 0
                          ? null
                          : () => setState(() => _index--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _index == locations.length - 1
                          ? null
                          : () => setState(() => _index++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
