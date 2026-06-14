import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Language')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('English'),
            trailing: Icon(Icons.check, color: Colors.blue),
          ),
          ListTile(title: Text('Spanish')),
          ListTile(title: Text('French')),
        ],
      ),
    );
  }
}
