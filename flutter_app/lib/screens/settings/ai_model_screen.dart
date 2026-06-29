import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/gemini/llm_service.dart';
import '../../services/gemini/open_router_service.dart';

// AI Model settings (Settings → AI Model Settings)

// for my testing keeping a default Gemini flow of my model on

// OpenRouter (DeepSeek, GPT, Claude, Llama, …).
class AiModelScreen extends StatefulWidget {
  const AiModelScreen({super.key});

  @override
  State<AiModelScreen> createState() => _AiModelScreenState();
}

class _AiModelScreenState extends State<AiModelScreen> {
  static const _commonModels = <String>[
    'deepseek/deepseek-chat',
    'openai/gpt-4o-mini',
    'anthropic/claude-3-haiku',
    'meta-llama/llama-3.1-8b-instruct:free',
  ];

  final _keyController = TextEditingController();
  final _modelController = TextEditingController(text: LLMService.defaultModel);

  bool _useOpenRouter = false;
  bool _obscureKey = true;
  bool _loading = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _useOpenRouter = prefs.getBool(LLMService.prefUseOpenRouter) ?? false;
      _keyController.text = prefs.getString(LLMService.prefApiKey) ?? '';
      _modelController.text =
          prefs.getString(LLMService.prefModel) ?? LLMService.defaultModel;
      _loading = false;
    });
  }

  String get _model => _modelController.text.trim().isEmpty
      ? LLMService.defaultModel
      : _modelController.text.trim();

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LLMService.prefUseOpenRouter, _useOpenRouter);
    await prefs.setString(LLMService.prefApiKey, _keyController.text.trim());
    await prefs.setString(LLMService.prefModel, _model);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useOpenRouter
              ? 'Saved — generation will use $_model via OpenRouter.'
              : 'Saved — using the default Gemini model.',
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (key.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your OpenRouter API key first.')),
      );
      return;
    }
    setState(() => _testing = true);
    final reply = await OpenRouterService(
      apiKey: key,
      model: _model,
    ).generate('You are a connectivity test.', 'Reply with OK');
    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          (reply != null && reply.trim().isNotEmpty)
              ? 'Connected — $_model responded.'
              : 'No response — check the API key and model ID.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Model Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Choose which AI model generates your tours. Gemini is the '
                    'built-in default; testers can use their own model instead.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),

                  RadioGroup<bool>(
                    groupValue: _useOpenRouter,
                    onChanged: (v) => setState(() => _useOpenRouter = v!),
                    child: const Column(
                      children: [
                        // Section 1 — Gemini (default).
                        RadioListTile<bool>(
                          value: false,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Use Gemini (Default)'),
                          subtitle: Text(
                            "Uses the app's built-in Gemini configuration",
                          ),
                        ),
                        // Section 2 — OpenRouter (custom).
                        RadioListTile<bool>(
                          value: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Use Custom Model (OpenRouter)'),
                          subtitle: Text(
                            'Supports DeepSeek, GPT-4, Claude, Llama and 300+ '
                            'models',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _useOpenRouter ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !_useOpenRouter,
                      child: _openRouterFields(theme),
                    ),
                  ),

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _openRouterFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // API key.
        TextField(
          controller: _keyController,
          obscureText: _obscureKey,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'OpenRouter API Key',
            hintText: 'sk-or-...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            Clipboard.setData(
              const ClipboardData(text: 'https://openrouter.ai/keys'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied: openrouter.ai/keys')),
            );
          },
          child: Text(
            'Get a key at openrouter.ai/keys',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Model id.
        TextField(
          controller: _modelController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Model ID',
            hintText: 'deepseek/deepseek-chat',
            helperText: 'Find model IDs at openrouter.ai/models',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _commonModels)
              ActionChip(
                label: Text(m, style: theme.textTheme.labelSmall),
                onPressed: () => setState(() => _modelController.text = m),
              ),
          ],
        ),
        const SizedBox(height: 16),

        OutlinedButton.icon(
          onPressed: _testing ? null : _testConnection,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: Text(_testing ? 'Testing…' : 'Test Connection'),
        ),
      ],
    );
  }
}
