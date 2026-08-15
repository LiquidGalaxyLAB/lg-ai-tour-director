import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/ai_film_provider.dart';
import '../../models/video_generation_result.dart';
import '../../models/video_generation_settings.dart';
import '../../services/video/video_cost.dart';
import '../../services/video/video_provider_factory.dart';

class AiFilmSettingsScreen extends ConsumerStatefulWidget {
  const AiFilmSettingsScreen({super.key, this.returnToTour = false});

  final bool returnToTour;

  @override
  ConsumerState<AiFilmSettingsScreen> createState() =>
      _AiFilmSettingsScreenState();
}

// Live fal.ai text-to-video endpoints (verified Aug 2026), best quality first.
// Approx 720p pricing: Kling v3 ~$0.084/s, WAN 2.2 ~$0.08/s,
// Hailuo 02 ~$0.045/s, LTX ~$0.02/clip.
const _falModels = <(String, String)>[
  ('Kling v3', 'fal-ai/kling-video/v3/standard/text-to-video'),
  ('WAN 2.2', 'fal-ai/wan/v2.2-a14b/text-to-video'),
  ('Hailuo 02', 'fal-ai/minimax/hailuo-02/standard/text-to-video'),
  ('LTX Video', 'fal-ai/ltx-video'),
];

const _typicalTourStops = 5;

class _AiFilmSettingsScreenState extends ConsumerState<AiFilmSettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController(); // Kling only
  final _baseUrlController = TextEditingController(); // vLLM / Custom
  final _modelController = TextEditingController(); // fal custom / Custom

  VideoProviderType _provider = VideoProviderType.falAi;
  int _duration = 8;
  bool _enabled = false;
  bool _obscureKey = true;
  bool _obscureSecret = true;
  int _falModelIndex = 0; // == _falModels.length → custom model field
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s =
        await VideoGenerationSettings.load() ?? const VideoGenerationSettings();
    if (!mounted) return;
    setState(() {
      _provider = s.providerType;
      _duration = s.durationPerLocationSeconds.clamp(5, 500);
      _enabled = s.isEnabled;
      _baseUrlController.text = s.baseUrl;
      _modelController.text = s.modelId;
      if (s.providerType == VideoProviderType.klingDirect) {
        final parts = s.apiKey.split(':');
        _apiKeyController.text = parts.isNotEmpty ? parts.first : '';
        _secretKeyController.text = parts.length > 1 ? parts[1] : '';
      } else {
        _apiKeyController.text = s.apiKey;
      }
      if (s.providerType == VideoProviderType.falAi) {
        final idx = _falModels.indexWhere((m) => m.$2 == s.modelId);
        // Fresh setup defaults to the first preset (Kling v3); an unknown saved
        // id falls to the custom field.
        _falModelIndex = idx >= 0
            ? idx
            : (s.modelId.isEmpty ? 0 : _falModels.length);
      }
    });
  }

  static String _providerEndpoint(VideoProviderType t) {
    switch (t) {
      case VideoProviderType.falAi:
        return 'https://queue.fal.run';
      case VideoProviderType.veo3:
        return 'https://generativelanguage.googleapis.com';
      case VideoProviderType.runway:
        return 'https://api.runwayml.com';
      case VideoProviderType.klingDirect:
        return 'https://api.klingai.com';
      case VideoProviderType.vllmOmni:
      case VideoProviderType.custom:
        return ''; // user-entered
    }
  }

  bool get _keyOptional =>
      _provider == VideoProviderType.vllmOmni ||
      _provider == VideoProviderType.custom;

  bool get _usesBaseUrlField =>
      _provider == VideoProviderType.vllmOmni ||
      _provider == VideoProviderType.custom;

  String _effectiveBaseUrl() => _usesBaseUrlField
      ? _baseUrlController.text.trim()
      : _providerEndpoint(_provider);

  String _effectiveApiKey() {
    if (_provider == VideoProviderType.vllmOmni) return '';
    if (_provider == VideoProviderType.klingDirect) {
      final a = _apiKeyController.text.trim();
      final s = _secretKeyController.text.trim();
      return (a.isEmpty && s.isEmpty) ? '' : '$a:$s';
    }
    return _apiKeyController.text.trim();
  }

  String _effectiveModelId() {
    if (_provider == VideoProviderType.falAi) {
      return _falModelIndex < _falModels.length
          ? _falModels[_falModelIndex].$2
          : _modelController.text.trim();
    }
    if (_provider == VideoProviderType.custom) {
      return _modelController.text.trim();
    }
    return '';
  }

  VideoGenerationSettings _buildSettings() => VideoGenerationSettings(
    providerType: _provider,
    baseUrl: _effectiveBaseUrl(),
    apiKey: _effectiveApiKey(),
    modelId: _effectiveModelId(),
    durationPerLocationSeconds: _provider == VideoProviderType.veo3
        ? 8
        : _duration,
    isEnabled: _enabled,
  );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? scheme.error : const Color(0xFF34A853),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    var ok = false;
    String? err;
    try {
      final provider = VideoProviderFactory.create(_buildSettings());
      ok = await provider.testConnection();
    } on VideoGenerationException catch (e) {
      err = e.userMessage;
    } catch (e) {
      err = e.toString();
    }
    if (!mounted) return;
    setState(() => _testing = false);
    ok
        ? _snack('provider_ready'.tr())
        : _snack(err ?? 'connection_failed'.tr(), error: true);
  }

  Future<void> _save() async {
    final settings = _buildSettings();
    if (_usesBaseUrlField && settings.baseUrl.isEmpty) {
      _snack('enter_base_url'.tr(), error: true);
      return;
    }
    if (_provider == VideoProviderType.klingDirect &&
        (_apiKeyController.text.trim().isEmpty ||
            _secretKeyController.text.trim().isEmpty)) {
      _snack('enter_access_and_secret_key'.tr(), error: true);
      return;
    }
    if (!_keyOptional && settings.apiKey.isEmpty) {
      _snack('enter_api_key'.tr(), error: true);
      return;
    }
    await ref.read(aiFilmProvider.notifier).saveSettings(settings);
    if (!mounted) return;
    _snack('ai_film_configured'.tr());
    if (widget.returnToTour) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ai_film'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _enabledToggle(),
          const SizedBox(height: 16),
          _whatIsAiFilm(),
          const SizedBox(height: 16),
          // Sections 2–4 grey out when AI Film is off.
          Opacity(
            opacity: _enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !_enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _providerSection(),
                  const SizedBox(height: 20),
                  _durationSection(),
                  const SizedBox(height: 20),
                  _testAndSave(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _enabledToggle() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        value: _enabled,
        onChanged: (v) async {
          setState(() => _enabled = v);
          // Persist the toggle immediately; the Save button greys out when
          // disabled, so it can't write the OFF value itself.
          await ref
              .read(aiFilmProvider.notifier)
              .saveSettings(_buildSettings());
        },
        title: Text(
          'ai_film'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _enabled
              ? 'ai_film_on_desc'.tr()
              : 'ai_film_off_desc'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        secondary: const Icon(Icons.movie_creation_outlined),
      ),
    );
  }

  // Section 1
  Widget _whatIsAiFilm() {
    final theme = Theme.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ai_film'.tr(), style: theme.textTheme.titleLarge),
          Text(
            'ai_film_tagline'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ai_film_description'.tr(),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeatureChip('🎬', 'cinematic_quality'.tr()),
              _FeatureChip('🔑', 'your_own_api_key'.tr()),
              _FeatureChip('✂️', 'auto_stitched'.tr()),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => context.push('/settings/help'),
            child: Text(
              'ai_film_help_link'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4285F4),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF4285F4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section 2
  Widget _providerSection() {
    final theme = Theme.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('video_provider'.tr()),
          const SizedBox(height: 8),
          DropdownButtonFormField<VideoProviderType>(
            initialValue: _provider,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final t in VideoProviderType.values)
                DropdownMenuItem(
                  value: t,
                  child: Text(
                    t == VideoProviderType.falAi
                        ? '${t.label} (recommended)'
                        : t.label,
                  ),
                ),
            ],
            onChanged: (t) {
              if (t == null) return;
              setState(() {
                _provider = t;
                if (t == VideoProviderType.veo3) _duration = 8;
              });
            },
          ),
          const SizedBox(height: 16),
          ..._providerFields(theme),
        ],
      ),
    );
  }

  List<Widget> _providerFields(ThemeData theme) {
    switch (_provider) {
      case VideoProviderType.falAi:
        return [
          _keyField('api_key'.tr(), 'sk-...', 'get_key_fal'.tr()),
          const SizedBox(height: 16),
          _label('model'.tr()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _falModels.length; i++)
                ChoiceChip(
                  label: Text(_falModels[i].$1),
                  selected: _falModelIndex == i,
                  onSelected: (_) => setState(() => _falModelIndex = i),
                ),
              ChoiceChip(
                label: Text('custom_model'.tr()),
                selected: _falModelIndex == _falModels.length,
                onSelected: (_) =>
                    setState(() => _falModelIndex = _falModels.length),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _hint('fal_model_pricing_hint'.tr(), theme),
          if (_falModelIndex == _falModels.length) ...[
            const SizedBox(height: 12),
            _urlField(
              'model_id'.tr(),
              'fal-ai/wan/v2.2-a14b/text-to-video',
              null,
              _modelController,
            ),
          ],
        ];
      case VideoProviderType.veo3:
        return [
          _keyField(
            'gemini_api_key'.tr(),
            'AIza...',
            'get_key_aistudio'.tr(),
          ),
          const SizedBox(height: 12),
          _note(
            const Color(0xFF1A73E8),
            'veo3_note'.tr(),
          ),
        ];
      case VideoProviderType.runway:
        return [
          _keyField('api_key'.tr(), 'key_...', 'get_key_runway'.tr()),
          const SizedBox(height: 12),
          _note(
            theme.colorScheme.primary,
            'runway_note'.tr(),
          ),
        ];
      case VideoProviderType.klingDirect:
        return [
          _keyField('api_key_access_key_id'.tr(), 'access-key-id', null),
          const SizedBox(height: 12),
          _keyField(
            'secret_key'.tr(),
            'secret-key',
            'get_keys_kling'.tr(),
            controller: _secretKeyController,
            obscure: _obscureSecret,
            onToggle: () => setState(() => _obscureSecret = !_obscureSecret),
          ),
          const SizedBox(height: 12),
          _note(
            theme.colorScheme.primary,
            'kling_note'.tr(),
          ),
        ];
      case VideoProviderType.vllmOmni:
        return [
          _urlField(
            'base_url'.tr(),
            'http://localhost:8080',
            'vllm_serve_hint'.tr(),
            _baseUrlController,
          ),
          const SizedBox(height: 12),
          _note(
            const Color(0xFF34A853),
            'vllm_note'.tr(),
          ),
        ];
      case VideoProviderType.custom:
        return [
          _urlField(
            'base_url'.tr(),
            'https://your-provider.com/v1',
            null,
            _baseUrlController,
          ),
          const SizedBox(height: 12),
          _keyField(
            'api_key_optional'.tr(),
            'sk-...',
            'leave_empty_unauthenticated'.tr(),
          ),
          const SizedBox(height: 12),
          _urlField('model_id'.tr(), 'model-name', null, _modelController),
          const SizedBox(height: 12),
          _note(
            const Color(0xFFF29900),
            'custom_endpoint_note'.tr(),
          ),
        ];
    }
  }

  // Section 3
  Widget _durationSection() {
    final theme = Theme.of(context);
    final provider = VideoProviderFactory.create(_buildSettings());
    final isVeo = _provider == VideoProviderType.veo3;
    final duration = isVeo ? 8 : _duration;
    final maxClip = provider.maxClipDurationSeconds;
    final needsChunking = !isVeo && duration > maxClip;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('duration_per_location'.tr()),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: duration.toDouble().clamp(5, 500),
                  min: 5,
                  max: 500,
                  divisions: 99,
                  label: '$duration seconds',
                  onChanged: isVeo
                      ? null
                      : (v) => setState(() => _duration = v.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${duration}s',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (isVeo)
            _hint('veo3_eight_second_only'.tr(), theme)
          else if (needsChunking)
            _hint(
              '${provider.providerName} max is ${maxClip}s per clip. Will '
              'generate ${VideoProviderFactory.chunksNeeded(provider, duration)} '
              'clips per location and stitch them.',
              theme,
            ),
          const SizedBox(height: 16),
          _costCard(duration),
        ],
      ),
    );
  }

  Widget _costCard(int duration) {
    final theme = Theme.of(context);
    final rate = VideoCost.rate(_provider, _effectiveModelId());
    final totalSeconds = duration * _typicalTourStops;
    final estimate = VideoCost.estimateUsd(
      type: _provider,
      modelId: _effectiveModelId(),
      durationPerLocation: duration,
      locationCount: _typicalTourStops,
    );
    final ps = rate.perSecond;
    final rateText = ps == null
        ? 'unknown'.tr()
        : ps == 0
        ? 'free'.tr()
        // Sub-cent rates (e.g. LTX ~$0.004/s) need 3 decimals or they read $0.00.
        : '\$${ps < 0.1 ? ps.toStringAsFixed(3) : ps.toStringAsFixed(2)}'
              '/sec (${rate.label})';
    final totalText = estimate == null
        ? '—'
        : estimate == 0
        ? 'free'.tr()
        : '~\$${estimate.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'estimated_cost'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _costRow('duration_per_location'.tr(), '${duration}s'),
          _costRow('locations_in_typical_tour'.tr(), '$_typicalTourStops'),
          _costRow('total_video'.tr(), '$totalSeconds seconds'),
          _costRow('provider_rate'.tr(), rateText),
          const Divider(height: 18),
          _costRow('estimated_total'.tr(), totalText, bold: true),
          const SizedBox(height: 8),
          Text(
            'cost_disclaimer'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value, {bool bold = false}) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }

  // Section 4
  Widget _testAndSave() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: Text(_testing ? 'testing'.tr() : 'test_connection'.tr()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: Text('save_configuration'.tr()),
        ),
      ],
    );
  }

  // Small shared pieces

  Widget _card({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _hint(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _keyField(
    String label,
    String hint,
    String? helper, {
    TextEditingController? controller,
    bool? obscure,
    VoidCallback? onToggle,
  }) {
    final ctrl = controller ?? _apiKeyController;
    final isObscured = obscure ?? _obscureKey;
    final toggle = onToggle ?? () => setState(() => _obscureKey = !_obscureKey);
    return TextField(
      controller: ctrl,
      obscureText: isObscured,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
          onPressed: toggle,
        ),
      ),
    );
  }

  Widget _urlField(
    String label,
    String hint,
    String? helper,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.url,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _note(Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.emoji, this.label);
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji  $label',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
