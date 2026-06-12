import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/ssh_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sshState = ref.watch(sshConnectionProvider);
    final isConnected = sshState.isConnected;

    Future<void> runUbuntuTest() async {
      final result = await ref
          .read(sshConnectionProvider.notifier)
          .runCommand('echo "LG connected"');

      if (!context.mounted) return;

      if (result != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ubuntu Test Result'),
            content: Text('Response: $result'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test failed. Are you connected?'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Future<void> sendTestKml() async {
      await ref.read(sshConnectionProvider.notifier).sendTestKml();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test KML sent to /var/www/html/test.kml'),
        ),
      );
    }

    Future<void> runFlyToTest() async {
      await ref.read(sshConnectionProvider.notifier).flyToPune();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('FlyTo Pune command sent')));
    }

    Future<void> cleanupLg() async {
      await ref.read(sshConnectionProvider.notifier).cleanup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liquid Galaxy files cleaned up')),
      );
    }

    Future<bool> confirm(String action) async {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Confirm $action'),
              content: Text('Are you sure you want to $action Liquid Galaxy?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    action,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ) ??
          false;
    }

    Future<void> relaunchLg() async {
      if (!await confirm('Relaunch')) return;
      await ref.read(sshConnectionProvider.notifier).relaunchLg();
    }

    Future<void> rebootLg() async {
      if (!await confirm('Reboot')) return;
      await ref.read(sshConnectionProvider.notifier).rebootLg();
    }

    Future<void> shutdownLg() async {
      if (!await confirm('Shutdown')) return;
      await ref.read(sshConnectionProvider.notifier).shutdownLg();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tour Director'),
        actions: [_ConnectionDot(isConnected: isConnected)],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'AI Tour Director',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Tour Library'),
              onTap: () {
                context.pop();
                context.push('/library');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: const Text('LG Connection Settings'),
              onTap: () {
                context.pop();
                context.push('/settings/lg');
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('App Language'),
              onTap: () {
                context.pop();
                context.push('/settings/language');
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('App Theme'),
              onTap: () {
                context.pop();
                context.push('/settings/theme');
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Where to next?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'e.g. Historical places in Pune...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {
                    // Placeholder for mic action
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mic placeholder tapped')),
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  context.push('/generation', extra: value.trim());
                }
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Launch',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Historic Forts'),
                  onPressed: () => context.push(
                    '/generation',
                    extra: 'Historic Forts in India',
                  ),
                  avatar: const Icon(Icons.castle, size: 16),
                ),
                ActionChip(
                  label: const Text('World Wonders'),
                  onPressed: () =>
                      context.push('/generation', extra: 'World Wonders'),
                  avatar: const Icon(Icons.public, size: 16),
                ),
                ActionChip(
                  label: const Text('Hidden Cities'),
                  onPressed: () => context.push(
                    '/generation',
                    extra: 'Hidden Cities around the globe',
                  ),
                  avatar: const Icon(Icons.location_city, size: 16),
                ),
                ActionChip(
                  label: const Text('Random Discovery'),
                  onPressed: () => context.push(
                    '/generation',
                    extra: 'Random amazing places on Earth',
                  ),
                  avatar: const Icon(Icons.explore, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Developer Tests',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isConnected ? runUbuntuTest : null,
              icon: const Icon(Icons.terminal),
              label: const Text('Run Ubuntu Test (echo)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isConnected ? sendTestKml : null,
              icon: const Icon(Icons.map),
              label: const Text('Send Test KML (Pune)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isConnected ? runFlyToTest : null,
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Run FlyTo Pune'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isConnected ? cleanupLg : null,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Cleanup LG (Wipe KMLs)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'System Controls',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected ? relaunchLg : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Relaunch'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected ? rebootLg : null,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reboot'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isConnected ? shutdownLg : null,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Shutdown Rig'),
              style: FilledButton.styleFrom(backgroundColor: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
