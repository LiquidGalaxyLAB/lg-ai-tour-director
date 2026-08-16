import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_colors.dart';
import '../../models/tour_flow.dart';
import '../../providers/tour_draft_provider.dart';
import '../../providers/tour_state_provider.dart';
import '../../services/gemini/llm_service.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/quick_tips_sheet.dart';
import '../../shared/widgets/showcase_video_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _promptController = TextEditingController();

  // On-device speech recognition (speech_to_text) for the mic button.
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  static const _suggestion = 'Lost empires of Rajasthan';

  static final _quickLaunch = <_QuickLaunch>[
    _QuickLaunch(
      'quick_historic_forts'.tr(),
      Icons.castle_rounded,
      AppColors.googleRed,
      'Historic Forts in India',
    ),
    _QuickLaunch(
      'quick_world_wonders'.tr(),
      Icons.public_rounded,
      AppColors.googleBlueBright,
      'The Seven Wonders of the World',
    ),
    _QuickLaunch(
      'quick_hidden_cities'.tr(),
      Icons.visibility_off_rounded,
      AppColors.googleGreen,
      'Hidden ancient cities of the world',
    ),
    _QuickLaunch(
      'quick_random_discovery'.tr(),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('speech_unavailable'.tr())));
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

  /// Confirmation gate for the typed prompt: Enter or Generate Tour ask first,
  /// then generate on Yes. (Quick Launch chips call [_generate] directly.)
  Future<void> _confirmAndGenerate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('describe_place_to_begin'.tr())));
      return;
    }
    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          icon: Icon(
            Icons.rocket_launch_rounded,
            color: theme.colorScheme.primary,
            size: 32,
          ),
          title: Text('start_with_tour_q'.tr()),
          content: Text('generate_immersive_prompt'.tr()),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          // Stacked full-width actions so they never wrap out of line.
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text('yes_start_tour'.tr()),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('go_back'.tr()),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (start == true) await _generate();
  }

  Future<void> _generate([String? preset]) async {
    final prompt = (preset ?? _promptController.text).trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('describe_place_to_begin'.tr())));
      return;
    }
    // Gate on AI setup so a missing model/key is caught before generating.
    if (!await LLMService.isConfigured()) {
      if (!mounted) return;
      _showSetupRequiredDialog();
      return;
    }
    if (!mounted) return;
    context.push('/home/generation', extra: prompt);
    _promptController.clear();
  }

  void _showSetupRequiredDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.smart_toy_outlined),
        title: Text('setup_ai_first'.tr()),
        content: Text('setup_ai_body'.tr()),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.push('/settings/ai');
                  },
                  child: Text('setup_ai_model'.tr()),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('cancel'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
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
                Text(
                  'where_to_next'.tr(),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'describe_dream_journey'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: Icon(
                      Icons.tips_and_updates_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text('before_you_start'.tr()),
                    onPressed: () => showQuickTipsSheet(context),
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
                  onSubmit: _confirmAndGenerate,
                ),
                const SizedBox(height: 16),
                // Right under the prompt so typing to generating needs no scroll.
                FilledButton.icon(
                  onPressed: _confirmAndGenerate,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: Text('generate_tour'.tr()),
                ),
                const SizedBox(height: 28),
                Text(
                  'quick_launch'.tr(),
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
                const SizedBox(height: 28),
                Text(
                  'showcase_label'.tr(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const ShowcaseVideoCard(),
              ],
            ),
          ),

          _ReturnToTourBanner(
            info: ref.watch(
              tourStateProvider.select(
                (s) => (
                  running: s.isRunning,
                  progress: s.progress,
                  percent: s.percent,
                ),
              ),
            ),
            onTap: () {
              final args = ref.read(tourStateProvider).args;
              if (args != null) context.push('/home/active', extra: args);
            },
          ),

          // A generated-but-not-yet-started tour, shown only when none is
          // running, to return to Preview after the route was popped.
          _ContinueTourBanner(
            draft: ref.watch(tourStateProvider.select((s) => s.isRunning))
                ? null // running tour → its own banner above takes priority
                : ref.watch(tourDraftProvider),
            onTap: (args) => context.push('/home/preview', extra: args),
          ),
        ],
      ),
    );
  }
}

class _ContinueTourBanner extends StatelessWidget {
  const _ContinueTourBanner({required this.draft, required this.onTap});

  final TourFlowArgs? draft;
  final void Function(TourFlowArgs args) onTap;

  @override
  Widget build(BuildContext context) {
    final args = draft;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child: args == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Material(
                color: AppColors.googleBlueBright,
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(args),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'continue_your_tour'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                args.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ReturnToTourBanner extends StatelessWidget {
  const _ReturnToTourBanner({required this.info, required this.onTap});

  final ({bool running, double progress, int percent}) info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final track = Color.lerp(AppColors.googleGreen, Colors.black, 0.28)!;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child: !info.running
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Material(
                color: AppColors.googleGreen,
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${info.percent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: info.progress,
                            minHeight: 4,
                            backgroundColor: track,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'return_to_tour'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.replay_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String suggestion;
  final bool isListening;
  final VoidCallback onSuggestionTap;
  final VoidCallback onMic;
  final VoidCallback onSubmit;

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
                  // Enter submits instead of adding a newline; text soft-wraps.
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'prompt_hint'.tr(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(isListening ? Icons.mic : Icons.mic_none_rounded),
                color: isListening
                    ? AppColors.googleRed
                    : theme.colorScheme.primary,
                tooltip: isListening ? 'stop'.tr() : 'speak_your_prompt'.tr(),
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
