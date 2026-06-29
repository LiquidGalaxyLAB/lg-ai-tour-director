import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_header.dart';

/// Home tab (mockups 1/2): prompt entry + mic, a "Try" suggestion, the
/// Quick Launch grid, and the Generate Tour CTA. The connection dot and gear
/// live in [AppHeader].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _promptController = TextEditingController();

  // On-device speech recognition (speech_to_text) for the mic button.
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  static const _suggestion = 'Lost empires of Rajasthan';

  static const _quickLaunch = <_QuickLaunch>[
    _QuickLaunch(
      'Historic Forts',
      Icons.castle_rounded,
      AppColors.googleRed,
      'Historic Forts in India',
    ),
    _QuickLaunch(
      'World Wonders',
      Icons.public_rounded,
      AppColors.googleBlueBright,
      'The Seven Wonders of the World',
    ),
    _QuickLaunch(
      'Hidden Cities',
      Icons.visibility_off_rounded,
      AppColors.googleGreen,
      'Hidden ancient cities of the world',
    ),
    _QuickLaunch(
      'Random Discovery',
      Icons.shuffle_rounded,
      AppColors.tileSetRefresh,
      'Surprise me with a fascinating destination',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _speechReady = false;
    }
  }

  /// Toggles dictation into the prompt box. Requests mic permission on first
  /// use (handled by the plugin) and streams partial results live.
  Future<void> _toggleListen() async {
    if (_speech.isListening) {
      await _speech.stop();
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize();
      if (!_speechReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is unavailable on this device.'),
          ),
        );
        return;
      }
    }
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    // Replace the box with the recognised text and keep the caret at the end.
    _promptController.value = TextEditingValue(
      text: words,
      selection: TextSelection.collapsed(offset: words.length),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _promptController.dispose();
    super.dispose();
  }

  void _generate([String? preset]) {
    final prompt = (preset ?? _promptController.text).trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe a place or theme to begin.')),
      );
      return;
    }
    context.push('/home/generation', extra: prompt);
    _promptController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text('Where to next?', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Describe your dream journey',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _PromptCard(
                  controller: _promptController,
                  suggestion: _suggestion,
                  isListening: _listening,
                  onSuggestionTap: () {
                    _promptController.text = _suggestion;
                  },
                  onMic: _toggleListen,
                ),
                const SizedBox(height: 28),
                Text(
                  'QUICK LAUNCH',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    for (final q in _quickLaunch)
                      _QuickLaunchCard(
                        item: q,
                        onTap: () => _generate(q.prompt),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _generate(),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text('Generate Tour'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.controller,
    required this.suggestion,
    required this.isListening,
    required this.onSuggestionTap,
    required this.onMic,
  });

  final TextEditingController controller;
  final String suggestion;
  final bool isListening;
  final VoidCallback onSuggestionTap;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Start your adventure with a prompt...',
                  ),
                ),
              ),
              IconButton(
                icon: Icon(isListening ? Icons.mic : Icons.mic_none_rounded),
                color: isListening
                    ? AppColors.googleRed
                    : theme.colorScheme.primary,
                tooltip: isListening ? 'Stop' : 'Speak your prompt',
                onPressed: onMic,
              ),
            ],
          ),
          const Divider(height: 1),
          InkWell(
            onTap: onSuggestionTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Try: $suggestion',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLaunch {
  const _QuickLaunch(this.label, this.icon, this.color, this.prompt);
  final String label;
  final IconData icon;
  final Color color;
  final String prompt;
}

class _QuickLaunchCard extends StatelessWidget {
  const _QuickLaunchCard({required this.item, required this.onTap});

  final _QuickLaunch item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [item.color, item.color.withValues(alpha: 0.72)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -6,
                top: -6,
                child: Icon(
                  item.icon,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: Colors.white, size: 18),
                    ),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
