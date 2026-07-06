import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AiSetupScreen extends StatelessWidget {
  const AiSetupScreen({super.key});

  static const _steps = <(String, String)>[
    (
      'Pick a provider',
      'Tour Director works with almost any AI provider. Use a cloud provider '
          'such as OpenRouter, Groq or Together.ai, or run a model locally with '
          'Ollama or LM Studio.',
    ),
    (
      'Get an API key (cloud only)',
      'Create an account with your chosen provider and generate an API key from '
          'its dashboard. Keep it private, like a password. Local models such as '
          'Ollama and LM Studio need no key, so you leave the key field empty.',
    ),
    (
      'Find your base URL',
      'This is the provider endpoint, for example https://openrouter.ai/api/v1, '
          'https://api.groq.com/openai/v1, or http://localhost:11434/v1 for a '
          'local Ollama server. The app adds /chat/completions for you.',
    ),
    (
      'Copy the exact model ID',
      'Use the exact model identifier your provider expects, including any '
          'prefix, for example deepseek/deepseek-chat, openai/gpt-4o-mini, or '
          'llama3 for a local model. A wrong ID fails with a model not found '
          'error.',
    ),
    (
      'Enter it in the app',
      'Open Settings then AI Configuration. Tap a quick preset to auto fill all '
          'three fields, adjust the key and model, then tap Test Connection and '
          'Save. You are ready to generate tours.',
    ),
  ];

  static const _examples = <(String, String)>[
    ('OpenRouter (cloud)', 'https://openrouter.ai/api/v1'),
    ('Groq (cloud)', 'https://api.groq.com/openai/v1'),
    ('Together.ai (cloud)', 'https://api.together.xyz/v1'),
    ('Ollama (local)', 'http://localhost:11434/v1'),
    ('LM Studio (local)', 'http://localhost:1234/v1'),
  ];

  static const _errors = <(String, String)>[
    (
      'Invalid or missing API key (401 or 403)',
      'The key is wrong or empty. Re-copy it from your provider dashboard and '
          'check for extra spaces. Local models can leave the key empty.',
    ),
    (
      'Model not found (400 or 404)',
      'The model ID is wrong for this provider. Copy the exact model identifier '
          'from your provider, including any prefix.',
    ),
    (
      'Out of credits or quota (402)',
      'Your provider account has run out of credit or quota. Add credit, switch '
          'to a free or local model, and try again.',
    ),
    (
      'Rate limited (429)',
      'Your provider is throttling requests. Wait a moment and try again.',
    ),
    (
      'Timed out or no internet',
      'Check your network connection. For a local model, make sure the local '
          'server is running and reachable from this device.',
    ),
  ];

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied: $text')));
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
              'Tour Director generates tours with an AI model of your choice. '
              'Point it at any OpenAI-compatible endpoint: a cloud provider like '
              'OpenRouter, Groq or Together.ai, or a local model with Ollama or '
              'LM Studio. Set it up once.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            for (var i = 0; i < _steps.length; i++)
              _StepTile(index: i + 1, title: _steps[i].$1, body: _steps[i].$2),

            const SizedBox(height: 12),
            Text(
              'EXAMPLE BASE URLS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            for (final (label, url) in _examples)
              _EndpointRow(
                label: label,
                url: url,
                onTap: () => _copy(context, url),
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

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.label,
    required this.url,
    required this.onTap,
  });
  final String label;
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
            Icon(
              Icons.dns_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  Text(
                    url,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
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
