import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/gemini/llm_service.dart'; // pref keys
import '../../services/llm/llm_client.dart';
import '../../services/llm/llm_exception.dart';

class AiModelScreen extends StatefulWidget {
  const AiModelScreen({super.key});

  @override
  State<AiModelScreen> createState() => _AiModelScreenState();
}

class _Preset {
  const _Preset(this.label, this.baseUrl, this.model, {this.clearsKey = false});
  final String label;
  final String baseUrl;
  final String model;
  final bool clearsKey;
}

class _AiModelScreenState extends State<AiModelScreen> {
  static const _presets = <_Preset>[
    _Preset(
      'DeepSeek via OpenRouter',
      'https://openrouter.ai/api/v1',
      'deepseek/deepseek-chat',
    ),
    _Preset(
      'GPT-4o-mini via OpenRouter',
      'https://openrouter.ai/api/v1',
      'openai/gpt-4o-mini',
    ),
    _Preset(
      'Llama 3 Free via OpenRouter',
      'https://openrouter.ai/api/v1',
      'meta-llama/llama-3.1-8b-instruct:free',
    ),
    _Preset(
      'Ollama (local)',
      'http://localhost:11434/v1',
      'llama3',
      clearsKey: true,
    ),
    _Preset(
      'LM Studio (local)',
      'http://localhost:1234/v1',
      'local-model',
      clearsKey: true,
    ),
    _Preset('Groq', 'https://api.groq.com/openai/v1', 'llama-3.1-8b-instant'),
  ];

  final _baseUrlController = TextEditingController(
    text: LLMService.defaultBaseUrl,
  );
  final _keyController = TextEditingController();
  final _modelController = TextEditingController(text: LLMService.defaultModel);

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
    _baseUrlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _baseUrlController.text =
          prefs.getString(LLMService.prefBaseUrl) ?? LLMService.defaultBaseUrl;
      _keyController.text = prefs.getString(LLMService.prefApiKey) ?? '';
      _modelController.text =
          prefs.getString(LLMService.prefModel) ?? LLMService.defaultModel;
      _loading = false;
    });
  }

  String get _baseUrl => _baseUrlController.text.trim();
  String get _model => _modelController.text.trim();

  void _applyPreset(_Preset p) {
    setState(() {
      _baseUrlController.text = p.baseUrl;
      _modelController.text = p.model;

      if (p.clearsKey) _keyController.text = '';
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_baseUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('API URL is required.')),
      );
      return;
    }
    if (_model.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Model ID is required.')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LLMService.prefBaseUrl, _baseUrl);
    await prefs.setString(LLMService.prefApiKey, _keyController.text.trim());
    await prefs.setString(LLMService.prefModel, _model);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Configuration saved.')),
    );
    context.pop();
  }

  Future<void> _testConnection() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_baseUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('API URL is required.')),
      );
      return;
    }
    if (_model.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Model ID is required.')),
      );
      return;
    }
    setState(() => _testing = true);
    String message;
    try {
      await LLMClient(
        baseUrl: _baseUrl,
        apiKey: _keyController.text.trim(),
        model: _model,
      ).testConnection();
      message = 'Connected — $_model responded.';
    } on LlmException catch (e) {
      message = 'Connection failed : ${e.message}';
    } catch (_) {
      message = 'Connection failed : check URL and API key.';
    }
    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Configure any AI model endpoint',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Point Tour Director at any AI provider like OpenRouter, '
                    'Groq or Together.ai, or a local model with Ollama or '
                    'LM Studio. Pick a preset below or enter your own.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push('/help/ai-setup'),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Setup guide'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text('Quick presets', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _presets)
                        ActionChip(
                          label: Text(
                            p.label,
                            style: theme.textTheme.labelSmall,
                          ),
                          onPressed: () => _applyPreset(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Base URL.
                  TextField(
                    controller: _baseUrlController,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'https://openrouter.ai/api/v1',
                      helperText: 'The base URL of your LLM provider',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // API key.
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-or-... or leave empty for local models',
                      helperText: 'Leave empty for local models like Ollama',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
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
                      helperText: 'The model identifier for your provider',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

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

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Works with OpenRouter, Ollama, LM Studio, Groq, '
                    'Together.ai, and most other AI providers.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
