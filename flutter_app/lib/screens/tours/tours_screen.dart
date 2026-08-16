import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tour_history_entry.dart';
import '../../providers/library_provider.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/empty_state.dart';

/// Tours tab (mockup 12): chronological history of every generated tour.
/// Lightweight — no KML. Persisted via [tourHistoryProvider].
class ToursScreen extends ConsumerStatefulWidget {
  const ToursScreen({super.key});

  @override
  ConsumerState<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends ConsumerState<ToursScreen> {
  int _filter = 0; // 0 All · 1 Today · 2 This Week
  static const _filters = ['All', 'Today', 'This Week'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(tourHistoryProvider).value ?? const [];

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text('Tours', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  "A timeline of the tours you've generated and explored.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search tours...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < _filters.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_filters[i]),
                          selected: _filter == i,
                          onSelected: (_) => setState(() => _filter = i),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'HISTORY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No tours yet',
                    message:
                        'Tours you generate will appear here as a timeline.',
                  )
                else ...[
                  for (final e in entries) _HistoryCard(entry: e),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final TourHistoryEntry entry;

  static const _months = [
    'Jan',
    'Feb',
    'March',
    'April',
    'May',
    'June',
    'July',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ampm';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          _HistoryDetailsSheet(entry: entry, formatDate: _formatDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'View details',
                onPressed: () => _showDetails(context),
              ),
            ],
          ),
          Text(
            _formatDate(entry.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _StatChip(
                icon: Icons.place_outlined,
                label: '${entry.stopCount} Stops',
              ),
              _StatChip(
                icon: Icons.straighten,
                label: '${entry.distanceKm} km',
              ),
              _StatChip(
                icon: Icons.schedule,
                label: '${entry.durationMin} min',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.locationNames.join(' · '),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showDetails(context),
              child: const Text('View Details →'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing the full details of a history entry, plus a shortcut to
/// regenerate the same tour from its original prompt. History is lightweight (no
/// KML), so this is read-only detail — replaying on the rig happens from Saved.
class _HistoryDetailsSheet extends StatelessWidget {
  const _HistoryDetailsSheet({required this.entry, required this.formatDate});

  final TourHistoryEntry entry;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatDate(entry.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  icon: Icons.place_outlined,
                  label: '${entry.stopCount} Stops',
                ),
                _StatChip(
                  icon: Icons.straighten,
                  label: '${entry.distanceKm} km',
                ),
                _StatChip(
                  icon: Icons.schedule,
                  label: '${entry.durationMin} min',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'PROMPT',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(entry.prompt, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            Text(
              'STOPS',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < entry.locationNames.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              child: Text(
                                '${i + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.locationNames[i],
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Generate this tour again'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/home/generation', extra: entry.prompt);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
