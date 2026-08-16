import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/location.dart';
import '../../providers/ai_film_provider.dart';
import '../../providers/ssh_provider.dart';
import 'map_sync_test_screen.dart';

// Advanced LG Controls: the grid of rig commands wired to the SSH provider,
// plus a testing section (debug builds show extra rig test tools).
class AdvancedLgControlsScreen extends ConsumerWidget {
  const AdvancedLgControlsScreen({super.key});

  Future<bool> _confirm(BuildContext context, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('$action Liquid Galaxy?'),
            content: Text('Are you sure you want to $action the rig?'),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(action),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sshConnectionProvider.notifier);
    final connected = ref.watch(
      sshConnectionProvider.select((s) => s.isConnected),
    );
    final messenger = ScaffoldMessenger.of(context);

    void toast(String msg) =>
        messenger.showSnackBar(SnackBar(content: Text(msg)));

    Future<void> run(
      String action,
      Future<void> Function() fn, {
      bool destructive = false,
    }) async {
      if (!connected) {
        toast('Connect to Liquid Galaxy first');
        return;
      }
      if (destructive && !await _confirm(context, action)) return;
      await fn();
      toast('$action sent');
    }

    // Runs the full AI Film pipeline on 3 hardcoded locations (same code path
    // as a real tour), without generating a tour or needing the rig.
    void testAiFilm() {
      if (!ref.read(aiFilmProvider).settings.isConfigured) {
        toast('Configure AI Film in Settings first');
        return;
      }
      const testLocations = <TourLocation>[
        TourLocation(
          name: 'Shaniwar Wada',
          type: 'historical',
          whySignificant: 'A historic 18th century fort in Pune.',
          suggestedDurationSeconds: 25,
          address: 'Pune, Maharashtra, India',
        ),
        TourLocation(
          name: 'Taj Mahal',
          type: 'historical',
          whySignificant: 'An iconic marble mausoleum built in 1632.',
          suggestedDurationSeconds: 25,
          address: 'Agra, Uttar Pradesh, India',
        ),
        TourLocation(
          name: 'Red Fort',
          type: 'historical',
          whySignificant:
              'A Mughal-era fort that served as the main residence of '
              'emperors.',
          suggestedDurationSeconds: 25,
          address: 'Delhi, India',
        ),
      ];
      // The progress screen owns generateFilm(), errors, and navigation,
      // identical to the real post-tour flow.
      context.push('/tour/ai-film-progress', extra: testLocations);
    }

    final tiles = <_Tile>[
      _Tile(
        'Relaunch LG',
        Icons.refresh_rounded,
        AppColors.tileRelaunch,
        () => run('Relaunch', notifier.relaunchLg, destructive: true),
      ),
      _Tile(
        'Shutdown LG',
        Icons.power_settings_new_rounded,
        AppColors.tileShutdown,
        () => run('Shutdown', notifier.shutdownLg, destructive: true),
      ),
      _Tile(
        'Reboot LG',
        Icons.restart_alt_rounded,
        AppColors.tileReboot,
        () => run('Reboot', notifier.rebootLg, destructive: true),
      ),
      _Tile(
        'Send Logos',
        Icons.image_outlined,
        AppColors.tileSendLogos,
        () => run('Send Logos', notifier.setLogos),
      ),
      _Tile(
        'Set Refresh',
        Icons.sync_rounded,
        AppColors.tileSetRefresh,
        () => run('Set Refresh', notifier.setRefresh, destructive: true),
      ),
      _Tile(
        'Clear Logo',
        Icons.layers_clear_rounded,
        AppColors.tileClearLogo,
        () => run('Clear Logo', notifier.clearLogos),
      ),
      _Tile(
        'Reset Refresh',
        Icons.sync_disabled_rounded,
        AppColors.tileResetRefresh,
        () => run('Reset Refresh', notifier.resetRefresh, destructive: true),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced LG Controls')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [for (final t in tiles) _ControlTile(tile: t)],
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'DEVELOPER TESTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sample KML / camera moves and the AI Film pipeline test.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: testAiFilm,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: const Text('Test AI Film (3 clips)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => run('Send Test KML', notifier.sendTestKml),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Send Test KML (Shaniwar Wada)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => run('FlyTo Pune', notifier.flyToPune),
                  icon: const Icon(Icons.flight_takeoff_rounded),
                  label: const Text('FlyTo Pune'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => run('Test Orbit', notifier.testOrbit),
                  icon: const Icon(Icons.threesixty_rounded),
                  label: const Text('Test Orbit (Shaniwar Wada)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      run('Test Landmark Ring', notifier.testLandmarkRing),
                  icon: const Icon(Icons.blur_circular_rounded),
                  label: const Text('Test Landmark Ring (Shaniwar Wada)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => run('Test Balloon', notifier.testBalloon),
                  icon: const Icon(Icons.web_asset_rounded),
                  label: const Text('Test Balloon (auto-clears in 10s)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MapSyncTestScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: const Text('Test Map Sync'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => run('Clean up', notifier.cleanup),
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Clear KML files'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({required this.tile});
  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tile.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tile.icon, color: Colors.white, size: 30),
                const SizedBox(height: 10),
                Text(
                  tile.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
