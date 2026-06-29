import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/gemini/llm_service.dart'; // pref keys
import '../../services/llm/llm_exception.dart';
import '../../services/llm/open_router_service.dart';

/// AI Configuration (Settings → AI Configuration). Testers set their own model
/// via OpenRouter. (Gemini stays wired internally but is not shown here; adding
/// one radio option re-exposes it.)
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
    await prefs.setString(LLMService.prefApiKey, _keyController.text.trim());
    await prefs.setString(LLMService.prefModel, _model);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved. Tours will be generated with $_model.')),
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
    String message;
    try {
      await OpenRouterService(apiKey: key, model: _model).testConnection();
      message = 'Connected — $_model responded.';
    } on LlmException catch (e) {
      message = e.message;
    } catch (e) {
      message = 'Connection failed: $e';
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
                    'Configure your AI model via OpenRouter',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OpenRouter supports DeepSeek, GPT-4, Claude, Llama and 300+ '
                    'models with one API key. Get yours free at openrouter.ai',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push('/help/openrouter-setup'),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Setup guide'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

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
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
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
                        const SnackBar(
                          content: Text('Link copied: openrouter.ai/keys'),
                        ),
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
                          onPressed: () =>
                              setState(() => _modelController.text = m),
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
}
