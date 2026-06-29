import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class OpenRouterSetupScreen extends StatelessWidget {
  const OpenRouterSetupScreen({super.key});

  static const _steps = <(String, String)>[
    (
      'Create an OpenRouter account',
      'Go to openrouter.ai and sign up (Google, GitHub or email). It is free '
          'to create an account.',
    ),
    (
      'Create an API key',
      'Open openrouter.ai/keys → "Create Key" → copy the key (it starts with '
          '"sk-or-"). Keep it private and treat it like a password.',
    ),
    (
      'Credits or a free model',
      'Some models cost a few cents per run. To test for free, use the model '
          'meta-llama/llama-3.1-8b-instruct:free. For paid models (DeepSeek, '
          'GPT, Claude) add a small amount of credit on openrouter.ai.',
    ),
    (
      'Pick a model ID',
      'Browse openrouter.ai/models and copy the EXACT model ID, including the '
          'provider prefix e.g. "deepseek/deepseek-chat", "openai/gpt-4o-mini". '
          'A bare name like "gemini-2.0-flash" will fail.',
    ),
    (
      'Enter it in the app',
      'Settings → AI Configuration → paste your API key and model ID → tap '
          'Test Connection → Save. You are ready to generate tours.',
    ),
  ];

  static const _errors = <(String, String)>[
    (
      'Invalid or missing API key (401)',
      'The key is wrong or empty. Re-copy it from openrouter.ai/keys and make '
          'sure there are no extra spaces.',
    ),
    (
      'Model not found (404 / 400)',
      'The model ID is wrong. Copy the exact slug from openrouter.ai/models, that is, '
          'it must include the provider, e.g. "deepseek/deepseek-chat".',
    ),
    (
      'Out of credits (402)',
      'Add credits on OpenRouter, or switch to the free model '
          'meta-llama/llama-3.1-8b-instruct:free.',
    ),
    ('Timed out / no internet', 'Check your network connection and try again.'),
  ];

  void _copy(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: 'https://$url'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Link copied: $url')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Setup Guide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Set up your AI model', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Tour Director generates tours through OpenRouter. Just need one API key '
              'giving you access to DeepSeek, GPT, Claude, Llama and 300+ models. '
              'Follow these steps once.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            for (var i = 0; i < _steps.length; i++)
              _StepTile(index: i + 1, title: _steps[i].$1, body: _steps[i].$2),

            const SizedBox(height: 12),
            Text(
              'QUICK LINKS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _LinkRow(
              url: 'openrouter.ai/keys',
              onTap: () => _copy(context, 'openrouter.ai/keys'),
            ),
            _LinkRow(
              url: 'openrouter.ai/models',
              onTap: () => _copy(context, 'openrouter.ai/models'),
            ),

            const SizedBox(height: 20),
            Text(
              'COMMON ERRORS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            for (final (title, body) in _errors)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(title, style: theme.textTheme.titleSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(alignment: Alignment.centerLeft, child: Text(body)),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/settings/ai'),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Open AI Configuration'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.title,
    required this.body,
  });
  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Icon(
              Icons.copy,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
