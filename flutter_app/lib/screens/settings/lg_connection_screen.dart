import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lg_connection.dart';
import '../../providers/ssh_provider.dart';

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
      messenger.showSnackBar(
        const SnackBar(content: Text('Connected to Liquid Galaxy')),
      );
    } else {
      final error =
          ref.read(sshConnectionProvider).errorMessage ?? 'Connection failed';
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _runUbuntuTest() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(sshConnectionProvider.notifier)
        .runCommand('echo "LG connected"');

    if (!mounted) return;

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
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Test failed. Are you connected?'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _sendTestKml() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sshConnectionProvider.notifier).sendTestKml();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Test KML sent to /var/www/html/test.kml')),
    );
  }

  Future<void> _cleanupLg() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sshConnectionProvider.notifier).cleanup();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Liquid Galaxy files cleaned up')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sshState = ref.watch(sshConnectionProvider);
    if (!_prefilled && sshState.connection.host.isNotEmpty) {
      _prefillFrom(sshState.connection);
    }

    final isConnecting = sshState.isConnecting;

    return Scaffold(
      appBar: AppBar(title: const Text('LG Connection Settings')),
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
                  decoration: const InputDecoration(
                    labelText: 'Host IP',
                    hintText: '192.168.0.10',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Host cannot be empty'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'SSH Port',
                    hintText: '22',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final port = int.tryParse((v ?? '').trim());
                    if (port == null) return 'Port must be a number';
                    if (port < 1 || port > 65535) return 'Port must be 1–65535';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'lg',
                    border: OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username cannot be empty'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                  decoration: const InputDecoration(
                    labelText: 'LG Screen Count',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 screens')),
                    DropdownMenuItem(value: 5, child: Text('5 screens')),
                    DropdownMenuItem(value: 7, child: Text('7 screens')),
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
                  label: Text(isConnecting ? 'Connecting…' : 'Connect to LG'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: sshState.isConnected ? _runUbuntuTest : null,
                  icon: const Icon(Icons.terminal),
                  label: const Text('Run Ubuntu Test (echo)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: sshState.isConnected ? _sendTestKml : null,
                  icon: const Icon(Icons.map),
                  label: const Text('Send Test KML (Pune)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: sshState.isConnected ? _cleanupLg : null,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Cleanup LG (Wipe KMLs)'),
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
      SshStatus.connected => (Colors.green, 'Connected'),
      SshStatus.connecting => (Colors.orange, 'Connecting…'),
      SshStatus.error => (Colors.red, 'Disconnected'),
      SshStatus.disconnected => (Colors.red, 'Disconnected'),
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
