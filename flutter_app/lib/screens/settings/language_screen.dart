import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// App language picker. Uses easy_localization: [BuildContext.setLocale]
/// switches the language at runtime and persists it automatically.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  // (code, flag, name in English, name in native script)
  static const _languages = <(String, String, String, String)>[
    ('en', '🇬🇧', 'English', 'English'),
    ('es', '🇪🇸', 'Spanish', 'Español'),
    ('fr', '🇫🇷', 'French', 'Français'),
    ('hi', '🇮🇳', 'Hindi', 'हिन्दी'),
    ('ar', '🇸🇦', 'Arabic', 'العربية'),
    ('de', '🇩🇪', 'German', 'Deutsch'),
    ('pt', '🇧🇷', 'Portuguese', 'Português'),
    ('zh', '🇨🇳', 'Chinese', '中文'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text('app_language'.tr())),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (code, flag, english, native) in _languages)
            ListTile(
              leading: Text(flag, style: const TextStyle(fontSize: 26)),
              title: Text(english),
              subtitle: Text(native),
              trailing: current == code
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => context.setLocale(Locale(code)),
            ),
        ],
      ),
    );
  }
}
