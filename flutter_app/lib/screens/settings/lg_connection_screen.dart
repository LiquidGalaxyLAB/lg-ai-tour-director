import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/lg_connection.dart';
import '../../providers/ssh_provider.dart';
import 'qr_scan_screen.dart';

class LgConnectionScreen extends ConsumerStatefulWidget {
  const LgConnectionScreen({super.key});

  @override
  ConsumerState<LgConnectionScreen> createState() => _LgConnectionScreenState();
}

class _LgConnectionScreenState extends ConsumerState<LgConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  int _screenCount = 3;
  bool _obscurePassword = true;
  bool _prefilled = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _prefillFrom(LGConnection c) {
    if (_prefilled) return;
    _prefilled = true;
    _hostController.text = c.host;
    _portController.text = c.port.toString();
    _usernameController.text = c.username;
    _passwordController.text = c.password;
    _screenCount = c.screenCount;
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final connection = LGConnection(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      screenCount: _screenCount,
    );

    final ok = await ref
        .read(sshConnectionProvider.notifier)
        .connect(connection);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text('connected_to_lg'.tr())));
    } else {
      final error =
          ref.read(sshConnectionProvider).errorMessage ??
          'connection_failed'.tr();
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sshConnectionProvider.notifier).disconnect();
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('disconnected_from_lg'.tr())));
  }

  Future<void> _scanQr() async {
    FocusScope.of(context).unfocus();
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (raw == null || !mounted) return;

    final conn = _parseQr(raw);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (conn == null) {
      messenger.showSnackBar(SnackBar(content: Text('qr_invalid'.tr())));
      return;
    }
    setState(() {
      _hostController.text = conn.host;
      _portController.text = conn.port.toString();
      _usernameController.text = conn.username;
      _passwordController.text = conn.password;
      _screenCount = conn.screenCount;
    });
    messenger.showSnackBar(SnackBar(content: Text('qr_scanned_ok'.tr())));
  }

  LGConnection? _parseQr(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('{')) {
      try {
        final m = jsonDecode(text) as Map<String, dynamic>;
        final host = (m['host'] ?? m['ip'] ?? '').toString().trim();
        if (host.isEmpty) return null;
        return LGConnection(
          host: host,
          port: int.tryParse('${m['port'] ?? 22}') ?? 22,
          username: (m['username'] ?? m['user'] ?? 'lg').toString().trim(),
          password: (m['password'] ?? m['pass'] ?? 'lg').toString(),
          screenCount:
              int.tryParse(
                '${m['screenCount'] ?? m['screens'] ?? _screenCount}',
              ) ??
              _screenCount,
        );
      } catch (_) {
        return null;
      }
    }

    final parts = text
        .split(RegExp(r'[\n;,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 4) {
      final host = parts[2];
      if (host.isEmpty) return null;
      return LGConnection(
        username: parts[0],
        password: parts[1],
        host: host,
        port: int.tryParse(parts[3]) ?? 22,
        screenCount: parts.length >= 5
            ? (int.tryParse(parts[4]) ?? _screenCount)
            : _screenCount,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sshState = ref.watch(sshConnectionProvider);
    if (!_prefilled && sshState.connection.host.isNotEmpty) {
      _prefillFrom(sshState.connection);
    }

    final isConnecting = sshState.isConnecting;

    return Scaffold(
      appBar: AppBar(
        title: Text('lg_connection_settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusIndicator(status: sshState.status),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    labelText: 'host_ip'.tr(),
                    hintText: '192.168.0.10',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'host_cannot_be_empty'.tr()
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: 'ssh_port'.tr(),
                    hintText: '22',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final port = int.tryParse((v ?? '').trim());
                    if (port == null) return 'port_must_be_number'.tr();
                    if (port < 1 || port > 65535)
                      return 'port_range_invalid'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'username'.tr(),
                    hintText: 'lg',
                    border: const OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'username_cannot_be_empty'.tr()
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _screenCount,
                  decoration: InputDecoration(
                    labelText: 'lg_screen_count'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 3, child: Text('screens_3'.tr())),
                    DropdownMenuItem(value: 5, child: Text('screens_5'.tr())),
                    DropdownMenuItem(value: 7, child: Text('screens_7'.tr())),
                  ],
                  onChanged: isConnecting
                      ? null
                      : (v) => setState(() => _screenCount = v ?? 3),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: isConnecting ? null : _connect,
                  icon: isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    isConnecting ? 'connecting'.tr() : 'connect_to_lg'.tr(),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (sshState.isConnected) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text('disconnect'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or'.tr(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text('scan_qr_to_connect'.tr()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final SshStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SshStatus.connected => (Colors.green, 'connected'.tr()),
      SshStatus.connecting => (Colors.orange, 'connecting'.tr()),
      SshStatus.error => (Colors.red, 'disconnected'.tr()),
      SshStatus.disconnected => (Colors.red, 'disconnected'.tr()),
    };

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
