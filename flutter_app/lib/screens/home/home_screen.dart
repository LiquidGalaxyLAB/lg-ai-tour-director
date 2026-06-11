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

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tour Director'),
        actions: [
          _ConnectionDot(isConnected: isConnected),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'LG Connection Settings',
            onPressed: () => context.push('/settings/lg'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Where to next?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
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
