import 'package:flutter/material.dart';

import '../../models/tour_flow.dart';
import '../../shared/widgets/map_placeholder.dart';

/// Inspection Mode (mockup 6): pan a map of the tour's stops; on a real rig the
/// LG mirrors the navigation. Live sync is stubbed until the rig view is wired.
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key, required this.args});

  final TourFlowArgs args;

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  int _index = 0;

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    Text(loc.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: MapPlaceholder(
                  height: double.infinity,
                  markerCount: locations.length,
                  synced: true,
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
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(loc.type,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 8, color: Color(0xFF34A853)),
                              const SizedBox(width: 6),
                              Text('Synced with Liquid Galaxy',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF34A853),
                                  )),
                            ],
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
