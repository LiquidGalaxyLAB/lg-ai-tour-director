import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/ssh_provider.dart';

// Advanced LG Controls (mockup 19): the 2×3 grid of rig commands, moved out of
// Home. Relaunch/Reboot/Shutdown/Clear are wired to the SSH provider; Send
// Logos and Set Refresh are stubbed until those LG commands are implemented
class AdvancedLgControlsScreen extends ConsumerWidget {
  const AdvancedLgControlsScreen({super.key});

  Future<bool> _confirm(BuildContext context, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('$action Liquid Galaxy?'),
            content: Text('Are you sure you want to $action the rig?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
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
                'Send a sample KML / camera move to verify the rig connection.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
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
                onPressed: () => run('Clean up', notifier.cleanup),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Clear KML files'),
              ),
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
