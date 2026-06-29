import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';
import '../models/tour_flow.dart';
import '../services/gemini/llm_service.dart'; // pref keys (Gemini stays dormant)
import '../services/llm/open_router_service.dart';
import '../services/maps/geocoding_service.dart';
import '../services/maps/places_service.dart';
import '../services/media/location_media_resolver.dart';
// ignore: unused_import
import '../services/validation/auditor_service.dart'; // kept for re-enabling auditing later
import '../shared/widgets/app_header.dart';
import '../utils/json_parser.dart';

class GenerationScreen extends StatefulWidget {
  final String prompt;

  const GenerationScreen({super.key, required this.prompt});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  List<TourLocation>? _locations;
  String? _error;
  String _statusMessage = 'Your AI model is crafting your tour...';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _generateTour();
  }

  /// Calls the configured OpenRouter model and parses its (possibly chatty)
  /// JSON into locations. Gemini is intentionally not called here — it stays
  /// dormant but intact in [GeminiService].
  Future<List<TourLocation>> _extractLocations(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(LLMService.prefApiKey) ?? '';
    final model = prefs.getString(LLMService.prefModel) ?? LLMService.defaultModel;

    if (key.isEmpty) {
      throw Exception(
        'AI not configured. Go to Settings → AI Configuration to add your '
        'OpenRouter API key.',
      );
    }

    final raw =
        await OpenRouterService(apiKey: key, model: model).extractLocations(prompt);
    final jsonStr = JsonParser.extractJson(raw);
    if (jsonStr == null) {
      throw Exception('The AI model returned an unreadable response. Try again.');
    }

    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) {
      throw Exception('The AI model did not return a list of locations.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(TourLocation.fromJson)
        .toList();
  }

  // ── Working pipeline. Location extraction routes through OpenRouter; the
  // enrichment (geocoding → places → Wikimedia) below is unchanged. ──────────
  Future<void> _generateTour() async {
    try {
      if (mounted) {
        setState(
          () => _statusMessage = 'Extracting locations via your AI model...',
        );
      }
      final initialLocations = await _extractLocations(widget.prompt);

      if (mounted) {
        setState(
          () => _statusMessage =
              'Enriching locations with Google Maps & Wikimedia...',
        );
      }

      final enrichedLocations = <TourLocation>[];
      for (var loc in initialLocations) {
        final coords =
            await GeocodingService.instance.getCoordinates(loc.name);

        // No Gemini alternative-name fallback for now (saves API credits).
        // If geocoding fails, keep the location but log that it has no coords.
        if (coords == null) {
          debugPrint(
            'Generation: no coordinates for "${loc.name}" — keeping it un-geocoded',
          );
        }

        // Keep every Gemini location. Attach coords/place/image when available,
        // but don't drop a location just because geocoding failed.
        final placeDetails = coords != null
            ? await PlacesService.instance.getPlaceDetails(loc.name)
            : null;
        // Full media chain (Wikipedia → Unsplash → text-only), cached by name
        // so the rig balloon and in-app images reuse it with no repeat calls.
        final media = await LocationMediaResolver.instance.resolve(loc);
        final imageUrl = media.imageUrl.isEmpty ? null : media.imageUrl;

        enrichedLocations.add(loc.copyWith(
          latitude: coords?['lat'],
          longitude: coords?['lng'],
          placeId: placeDetails?['place_id'] as String?,
          address: placeDetails?['formatted_address'] as String?,
          imageUrl: imageUrl,
        ));
      }

      // TODO: Auditing temporarily skipped — geocoding is unreliable right now.
      // Re-enable AuditorService.instance.validateLocations() once geocoding
      // consistently returns coordinates.
      final validLocations = enrichedLocations;

      if (validLocations.isEmpty) {
        throw Exception('No locations returned from the AI model.');
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
  // ──────────────────────────────────────────────────────────────────────────

  /// Maps the pipeline's status message to a step index (0..3) for the checklist.
  int get _step {
    if (_locations != null) return 4;
    if (_statusMessage.contains('Enriching')) return 2;
    if (_statusMessage.contains('Extracting')) return 1;
    return 0;
  }

  String _titleFromPrompt() {
    final p = widget.prompt.trim();
    if (p.isEmpty) return 'Custom Tour';
    final first = p[0].toUpperCase() + p.substring(1);
    return first.length > 40 ? '${first.substring(0, 40)}…' : first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // On success, hand off to the preview screen (once).
    if (_locations != null && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.pushReplacement(
          '/home/preview',
          extra: TourFlowArgs(
            title: _titleFromPrompt(),
            prompt: widget.prompt,
            locations: _locations!,
          ),
        );
      });
    }

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: _error != null
                ? _ErrorView(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _generateTour();
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Text('Generating your immersive tour',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('"${widget.prompt}"',
                            style: theme.textTheme.bodyMedium),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: (_step / 4).clamp(0.05, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 20),
                      _Step(label: 'Selecting meaningful landmarks', done: _step > 1, active: _step == 1),
                      _Step(label: 'Fetching geographic coordinates', done: _step > 2, active: _step == 2),
                      _Step(label: 'Constructing immersive tour', done: _step > 2, active: _step == 2),
                      _Step(label: 'Preparing map preview', done: _step >= 4, active: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, required this.active});
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget leading;
    if (done) {
      leading = Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 22);
    } else if (active) {
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      leading = Icon(Icons.radio_button_unchecked,
          color: theme.colorScheme.outline, size: 22);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 22, child: Center(child: leading)),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: (done || active)
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error generating tour:\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
