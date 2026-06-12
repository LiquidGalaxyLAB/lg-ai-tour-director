import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/gemini/gemini_service.dart';

class GenerationScreen extends StatefulWidget {
  final String prompt;

  const GenerationScreen({super.key, required this.prompt});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  List<TourLocation>? _locations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateTour();
  }

  Future<void> _generateTour() async {
    try {
      final locations = await GeminiService.instance.extractLocations(
        widget.prompt,
      );
      if (mounted) {
        setState(() {
          _locations = locations;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating Tour')),
      body: Center(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error generating tour:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
                _generateTour();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_locations != null) {
      return ListView.builder(
        itemCount: _locations!.length,
        itemBuilder: (context, index) {
          final loc = _locations![index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(loc.name),
            subtitle: Text(
              '${loc.type} • ${loc.suggestedDurationSeconds}s\n${loc.whySignificant}',
            ),
            isThreeLine: true,
          );
        },
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Gemini is crafting a tour for:\n"${widget.prompt}"',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
