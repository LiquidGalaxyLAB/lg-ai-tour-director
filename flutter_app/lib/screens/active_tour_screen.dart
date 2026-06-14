import 'package:flutter/material.dart';

class ActiveTourScreen extends StatelessWidget {
  const ActiveTourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Tour')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.blue),
            SizedBox(height: 20),
            Text('Tour in progress on Liquid Galaxy'),
          ],
        ),
      ),
    );
  }
}
