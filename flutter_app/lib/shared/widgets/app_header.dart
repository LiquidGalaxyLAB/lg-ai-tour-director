import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ssh_provider.dart';
import 'connection_dot.dart';
import 'settings_sheet.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      sshConnectionProvider.select((s) => s.isConnected),
    );
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/logos/lg-logo-for-app.png',
            height: 34,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(width: 40, height: 34),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tour Director',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConnectionDot(connected: connected, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      (connected ? 'connected'.tr() : 'disconnected'.tr())
                          .toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => showSettingsSheet(context),
          ),
        ],
      ),
    );
  }
}
