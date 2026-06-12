import 'package:flutter/material.dart';

class GenerationScreen extends StatelessWidget {
  const GenerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating Tour')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Gemini is crafting your tour...'),
          ],
        ),
      ),
    );
  }
}
