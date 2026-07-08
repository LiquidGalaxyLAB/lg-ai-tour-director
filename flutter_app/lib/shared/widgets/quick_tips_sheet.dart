import 'package:flutter/material.dart';

Future<void> showQuickTipsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _QuickTipsSheet(),
  );
}

class _QuickTipsSheet extends StatelessWidget {
  const _QuickTipsSheet();

  static const _tips = <(IconData, String, String)>[
    (
      Icons.wifi_rounded,
      'Same WiFi network',
      'Your phone and the Liquid Galaxy rig must be on the SAME WiFi. Mobile '
          'data or a different / guest network will not connect.',
    ),
    (
      Icons.lan_rounded,
      'Use the Bridged adapter',
      'If the rig runs in VirtualBox, set its network to Bridged so it gets an '
          'IP on your real network. Host-only and NAT addresses are not '
          'reachable from your phone.',
    ),
    (
      Icons.cable_rounded,
      'Connect to the rig first',
      'Settings → LG Connection: enter the rig IP (run "hostname -I" on the '
          'master to find it), port 22, username and password "lg". The status '
          'dot turns green when connected.',
    ),
    (
      Icons.sync_rounded,
      'Tap Set Refresh once',
      'Before sending the logo or flying a tour, tap Set Refresh in Advanced '
          'LG Controls once per session, so the rig loads overlays and KML live.',
    ),
    (
      Icons.smart_toy_outlined,
      'Set up your AI model',
      'For tour generation, open Settings → AI Configuration and set a base '
          'URL, API key and model ID (or point it at a local model), then Test '
          'Connection. See the AI Setup Guide in Help & Support.',
    ),
    (
      Icons.rocket_launch_rounded,
      'Start needs a connection',
      'Start Immersive Tour only runs when the rig is connected. Connect first, '
          'then generate and start the tour.',
    ),
    (
      Icons.phone_android_rounded,
      'Use a real Android device',
      'The rig features and geocoding work best on a physical Android device; '
          'some location lookups fail on the web preview.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Before you start',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'A quick checklist to get Tour Director working with your rig.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _tips.length,
                  separatorBuilder: (_, _) => const Divider(height: 20),
                  itemBuilder: (context, i) {
                    final (icon, title, body) = _tips[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                body,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
