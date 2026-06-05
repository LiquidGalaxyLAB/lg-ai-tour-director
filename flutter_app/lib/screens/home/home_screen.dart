import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/ssh_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(
      sshConnectionProvider.select((s) => s.isConnected),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tour Director'),
        actions: [
          _ConnectionDot(isConnected: isConnected),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'LG Connection Settings',
            onPressed: () => context.go('/settings/lg'),
          ),
        ],
      ),
      body: const Center(child: Text('Where to next?')),
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
