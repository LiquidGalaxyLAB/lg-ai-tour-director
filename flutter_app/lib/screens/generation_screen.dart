import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/gemini/gemini_service.dart';
import '../services/maps/geocoding_service.dart';
import '../services/maps/places_service.dart';
import '../services/media/wikimedia_service.dart';
import '../services/validation/auditor_service.dart';

class GenerationScreen extends StatefulWidget {
  final String prompt;

  const GenerationScreen({super.key, required this.prompt});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  List<TourLocation>? _locations;
  String? _error;
  String _statusMessage = 'Gemini is crafting your tour...';

  @override
  void initState() {
    super.initState();
    _generateTour();
  }

  Future<void> _generateTour() async {
    try {
      if (mounted) {
        setState(() => _statusMessage = 'Extracting locations via Gemini...');
      }
      final initialLocations = await GeminiService.instance.extractLocations(
        widget.prompt,
      );

      if (mounted) {
        setState(
          () => _statusMessage =
              'Enriching locations with Google Maps & Wikimedia...',
        );
      }

      final enrichedLocations = <TourLocation>[];
      for (var loc in initialLocations) {
        var currentName = loc.name;
        Map<String, double>? coords = await GeocodingService.instance
            .getCoordinates(currentName);

        // Fallback logic
        if (coords == null) {
          final altName = await GeminiService.instance.getAlternativeName(
            currentName,
          );
          if (altName != null && altName.isNotEmpty) {
            currentName = altName;
            coords = await GeocodingService.instance.getCoordinates(
              currentName,
            );
          }
        }

        if (coords != null) {
          final placeDetails = await PlacesService.instance.getPlaceDetails(
            currentName,
          );
          final imageUrl = await WikimediaService.instance.getImageUrl(
            currentName,
          );

          enrichedLocations.add(
            loc.copyWith(
              name: currentName,
              latitude: coords['lat'],
              longitude: coords['lng'],
              placeId: placeDetails?['place_id'] as String?,
              address: placeDetails?['formatted_address'] as String?,
              imageUrl: imageUrl,
            ),
          );
        }
      }

      if (mounted) {
        setState(() => _statusMessage = 'Auditing generated coordinates...');
      }
      final validLocations = AuditorService.instance.validateLocations(
        enrichedLocations,
      );

      if (validLocations.isEmpty) {
        throw Exception('No valid locations found after auditing.');
      }

      if (mounted) {
        setState(() {
          _locations = validLocations;
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
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: loc.imageUrl != null
                  ? Image.network(
                      loc.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported),
                    )
                  : const CircleAvatar(child: Icon(Icons.place)),
              title: Text(loc.name),
              subtitle: Text(
                '${loc.type} • ${loc.suggestedDurationSeconds}s\n'
                '${loc.address ?? 'No address'}\n'
                'Coords: ${loc.latitude?.toStringAsFixed(4)}, ${loc.longitude?.toStringAsFixed(4)}\n\n'
                '${loc.whySignificant}',
              ),
              isThreeLine: true,
            ),
          );
        },
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            '$_statusMessage\n\nPrompt: "${widget.prompt}"',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
