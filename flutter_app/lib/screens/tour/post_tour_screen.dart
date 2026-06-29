import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../models/saved_tour.dart';
import '../../models/tour_flow.dart';
import '../../models/tour_history_entry.dart';
import '../../providers/library_provider.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/map_placeholder.dart';

/// Post-tour (mockups 10 & 11). If an AI film was requested it "produces" while
/// the user explores the recap, then reveals the player. Either way the user is
/// offered **Save Tour (KML)**. Veo + real video are stubbed; persistence is via
/// the library providers.
class PostTourScreen extends ConsumerStatefulWidget {
  const PostTourScreen({super.key, required this.args});

  final TourFlowArgs args;

  @override
  ConsumerState<PostTourScreen> createState() => _PostTourScreenState();
}

class _PostTourScreenState extends ConsumerState<PostTourScreen> {
  Timer? _timer;
  final FlutterTts _tts = FlutterTts();
  double _filmProgress = 0;
  bool _saved = false;
  final String _tourId = const Uuid().v4();

  bool get _film => widget.args.generateFilm;
  bool get _filmReady => _filmProgress >= 1.0;

  @override
  void initState() {
    super.initState();
    // Every completed tour is recorded in the Tours history.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordHistory());
    _sayThankYou();
    if (_film) {
      // Simulate Veo producing the film in the background (~6s).
      _timer = Timer.periodic(const Duration(milliseconds: 300), (t) {
        setState(() => _filmProgress = (_filmProgress + 0.05).clamp(0.0, 1.0));
        if (_filmReady) t.cancel();
      });
    }
  }

  /// Hardcoded closing narration (not from the LLM). Respects the Voice
  /// Narration preference so it stays consistent with the tour.
  Future<void> _sayThankYou() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('pref_voice_narration') ?? true)) return;
      await _tts.stop();
      await _tts.speak(
        'Thank you for exploring with Tour Director. '
        'We hope you enjoyed the journey.',
      );
    } catch (_) {
      // TTS is best-effort; ignore failures (e.g. no engine on web).
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  /// Total geographic span of the route (km) from any geocoded stops.
  double _distanceKm() {
    final pts = widget.args.locations
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += _haversineKm(
        pts[i - 1].latitude!,
        pts[i - 1].longitude!,
        pts[i].latitude!,
        pts[i].longitude!,
      );
    }
    return double.parse(total.toStringAsFixed(1));
  }

  static double _haversineKm(double a1, double o1, double a2, double o2) {
    const r = 6371.0;
    final dLat = (a2 - a1) * math.pi / 180;
    final dLon = (o2 - o1) * math.pi / 180;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a1 * math.pi / 180) *
            math.cos(a2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  int _durationMin() {
    final secs = widget.args.locations.fold<int>(
      0,
      (s, l) => s + l.suggestedDurationSeconds,
    );
    return (secs / 60).ceil().clamp(1, 999);
  }

  void _recordHistory() {
    final args = widget.args;
    ref
        .read(tourHistoryProvider.notifier)
        .add(
          TourHistoryEntry(
            id: _tourId,
            title: args.title,
            prompt: args.prompt,
            createdAt: DateTime.now(),
            stopCount: args.locations.length,
            distanceKm: _distanceKm(),
            durationMin: _durationMin(),
            locationNames: args.locations.map((l) => l.name).toList(),
          ),
        );
  }

  Future<void> _saveKml() async {
    final args = widget.args;
    final images = args.locations
        .map((l) => l.imageUrl)
        .whereType<String>()
        .toList();
    await ref
        .read(savedToursProvider.notifier)
        .save(
          SavedTour(
            id: _tourId, // same id as the history entry → promotes it
            title: args.title,
            prompt: args.prompt,
            createdAt: DateTime.now(),
            locations: args.locations,
            kml: '', // real KML comes from the KML engine later
            imageUrls: images,
            distanceKm: _distanceKm(),
            durationMin: _durationMin(),
          ),
        );
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tour saved to your library')));
  }

  void _stub(String label) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label — coming soon')));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const _ThankYouHero(),
                const SizedBox(height: 20),
                Text(widget.args.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  _film && !_filmReady
                      ? 'Explore the recap while your film is being produced.'
                      : 'Your journey is complete.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                if (_film && _filmReady)
                  _VideoPlayerCard(onPlay: () => _stub('Video playback'))
                else
                  const MapPlaceholder(
                    height: 200,
                    label: 'Recap · drag to explore',
                  ),

                if (_film && !_filmReady) ...[
                  const SizedBox(height: 16),
                  _ProducingCard(progress: _filmProgress),
                ],

                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saved ? null : _saveKml,
                  icon: Icon(
                    _saved ? Icons.check_rounded : Icons.bookmark_add_outlined,
                  ),
                  label: Text(_saved ? 'Saved to Library' : 'Save Tour (KML)'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Save tours to your library to revisit the immersive '
                    'experience anytime.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                if (_film && _filmReady) ...[
                  const SizedBox(height: 12),
                  Text(
                    'SHARE RECORDING',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ShareRow(onTap: _stub),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _stub('Download video'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF202124),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Video'),
                  ),
                ],

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThankYouHero extends StatefulWidget {
  const _ThankYouHero();

  @override
  State<_ThankYouHero> createState() => _ThankYouHeroState();
}

class _ThankYouHeroState extends State<_ThankYouHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.googleBlue,
        Color.lerp(AppColors.googleBlue, Colors.black, 0.35)!,
      ],
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final fade = Curves.easeOut.transform(_c.value);
        final pop = Curves.easeOutBack.transform(_c.value);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, (1 - fade) * 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Transform.scale(
                    scale: 0.7 + 0.3 * pop,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Thank You!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We hope you enjoyed the journey across Liquid Galaxy.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProducingCard extends StatelessWidget {
  const _ProducingCard({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Producing the film…',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 5),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerCard extends StatelessWidget {
  const _VideoPlayerCard({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.googleBlue, AppColors.googleGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: IconButton(
                iconSize: 56,
                onPressed: onPlay,
                icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              ),
            ),
            const Positioned(left: 12, bottom: 12, child: _Pill(text: '02:38')),
            const Positioned(
              right: 12,
              bottom: 12,
              child: _Pill(text: '1080p'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.onTap});
  final void Function(String) onTap;

  static const _items = <(String, IconData, Color)>[
    ('WhatsApp', Icons.chat_rounded, Color(0xFF25D366)),
    ('YouTube', Icons.smart_display_rounded, Color(0xFFFF0000)),
    ('Drive', Icons.add_to_drive_rounded, AppColors.googleBlueBright),
    ('Gmail', Icons.mail_rounded, AppColors.googleRed),
    ('Share', Icons.share_rounded, AppColors.googleGreen),
    ('More', Icons.more_horiz_rounded, Color(0xFF5F6368)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      children: [
        for (final (label, icon, color) in _items)
          GestureDetector(
            onTap: () => onTap(label),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 4),
                Text(label, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}
