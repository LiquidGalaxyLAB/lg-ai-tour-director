import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';
import '../models/tour_flow.dart';
import '../services/gemini/llm_service.dart';
import '../services/llm/llm_client.dart';
import '../services/llm/llm_exception.dart';
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
  String? _tourTitle; // short title the model chose for the whole tour
  String? _error;
  bool _setupIssue =
      false; // error is fixable in AI Configuration → offer guide
  String _statusMessage = 'Your AI model is crafting your tour...';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _generateTour();
  }

  Future<List<TourLocation>> _extractLocations(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl =
        prefs.getString(LLMService.prefBaseUrl) ?? LLMService.defaultBaseUrl;
    final key = prefs.getString(LLMService.prefApiKey) ?? '';
    final model =
        prefs.getString(LLMService.prefModel) ?? LLMService.defaultModel;

    if (baseUrl.trim().isEmpty) {
      throw LlmException(
        'AI not configured. Set your model endpoint in '
        'Settings → AI Configuration.',
        isSetupIssue: true,
      );
    }

    debugPrint(
      'Generation: extracting locations via $baseUrl ($model) for "$prompt"',
    );

    final raw = await LLMClient(
      baseUrl: baseUrl,
      apiKey: key,
      model: model,
    ).extractLocations(prompt);

    final jsonStr = JsonParser.extractJson(raw);

    List<dynamic>? list;
    if (jsonStr != null) {
      try {
        final parsed = jsonDecode(jsonStr);
        if (parsed is List) {
          list = parsed;
        } else if (parsed is Map) {
          final locs = parsed['locations'];
          if (locs is List) list = locs;
          final title = parsed['tour_title'];
          if (title is String && title.trim().isNotEmpty) {
            _tourTitle = title.trim();
          }
        }
      } catch (_) {}
    }
    if (list == null) {
      throw LlmException(
        "The AI model returned a response we couldn't read (it may not output "
        'clean JSON). Try a model like deepseek/deepseek-chat.',
        isSetupIssue: true,
      );
    }
    final locations = list
        .whereType<Map<String, dynamic>>()
        .map(TourLocation.fromJson)
        .toList();
    debugPrint(
      'Generation: parsed ${locations.length} locations: '
      '${locations.map((l) => l.name).join(', ')}',
    );
    return locations;
  }

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
        final coords = await GeocodingService.instance.getCoordinates(loc.name);

        if (coords == null) {
          debugPrint(
            'Generation: no coordinates for "${loc.name}" — keeping it un-geocoded',
          );
        }

        final placeDetails = coords != null
            ? await PlacesService.instance.getPlaceDetails(loc.name)
            : null;

        final media = await LocationMediaResolver.instance.resolve(loc);
        final imageUrl = media.imageUrl.isEmpty ? null : media.imageUrl;

        enrichedLocations.add(
          loc.copyWith(
            latitude: coords?['lat'],
            longitude: coords?['lng'],
            placeId: placeDetails?['place_id'] as String?,
            address: placeDetails?['formatted_address'] as String?,
            imageUrl: imageUrl,
          ),
        );
      }

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
          _error = e is LlmException ? e.message : e.toString();
          _setupIssue = e is LlmException && e.isSetupIssue;
        });
      }
    }
  }

  void _cancelGeneration() {
    _navigated = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  int get _step {
    if (_locations != null) return 4;
    if (_statusMessage.contains('Enriching')) return 2;
    if (_statusMessage.contains('Extracting')) return 1;
    return 0;
  }

  String _titleFromPrompt() {
    final title = _tourTitle?.trim() ?? '';
    if (title.isNotEmpty) {
      return title.length > 40 ? '${title.substring(0, 40)}…' : title;
    }
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '🎬 Your tour is designed! ${_locations!.length} '
                'stops ready to explore.',
              ),
              behavior: SnackBarBehavior.floating,
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
                    showSetupGuide: _setupIssue,
                    onRetry: () {
                      setState(() {
                        _error = null;
                        _setupIssue = false;
                      });
                      _generateTour();
                    },
                    onSetupGuide: () => context.push('/help/ai-setup'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Text(
                        'generating_your_immersive_tour'.tr(),
                        style: theme.textTheme.headlineSmall,
                      ),
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
                        child: Text(
                          '"${widget.prompt}"',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: (_step / 4).clamp(0.05, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 20),
                      _Step(
                        label: 'selecting_meaningful_landmarks'.tr(),
                        done: _step > 1,
                        active: _step == 1,
                      ),
                      _Step(
                        label: 'fetching_geographic_coordinates'.tr(),
                        done: _step > 2,
                        active: _step == 2,
                      ),
                      _Step(
                        label: 'constructing_immersive_tour'.tr(),
                        done: _step > 2,
                        active: _step == 2,
                      ),
                      _Step(
                        label: 'preparing_map_preview'.tr(),
                        done: _step >= 4,
                        active: false,
                      ),
                    ],
                  ),
          ),

          if (_error == null && _locations == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),

                child: TextButton(
                  onPressed: _cancelGeneration,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text('cancel_tour_generation'.tr()),
                ),
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
      leading = Icon(
        Icons.check_circle,
        color: theme.colorScheme.primary,
        size: 22,
      );
    } else if (active) {
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      leading = Icon(
        Icons.radio_button_unchecked,
        color: theme.colorScheme.outline,
        size: 22,
      );
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
  const _ErrorView({
    required this.error,
    required this.onRetry,
    this.showSetupGuide = false,
    this.onSetupGuide,
  });

  final String error;
  final VoidCallback onRetry;
  final bool showSetupGuide;
  final VoidCallback? onSetupGuide;

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
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 24),
            if (showSetupGuide && onSetupGuide != null) ...[
              FilledButton.icon(
                onPressed: onSetupGuide,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text('open_setup_guide'.tr()),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text('retry'.tr())),
            ] else
              FilledButton(onPressed: onRetry, child: Text('retry'.tr())),
          ],
        ),
      ),
    );
  }
}
