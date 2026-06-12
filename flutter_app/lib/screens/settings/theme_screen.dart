import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Theme')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('System Default'),
            trailing: Icon(Icons.check, color: Colors.blue),
          ),
          ListTile(title: Text('Light Mode'), leading: Icon(Icons.light_mode)),
          ListTile(title: Text('Dark Mode'), leading: Icon(Icons.dark_mode)),
        ],
      ),
    );
  }
}
