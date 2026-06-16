import '../core/constants/app_constants.dart';

// A single scene's narration text plus the timing derived from it
// Duration is estimated from word count and the configured speech rate so KML
// scene timelines and subtitle pacing can be precomputed
class Narration {
  const Narration({required this.text, this.languageCode = 'en'});

  final String text;
  final String languageCode;

  int get wordCount =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  // Estimated spoken length in seconds (word count ÷ words-per-second)
  double get estimatedDurationSeconds =>
      wordCount / AppConstants.defaultSpeechRateWps;

  Map<String, dynamic> toJson() => {'text': text, 'languageCode': languageCode};

  factory Narration.fromJson(Map<String, dynamic> json) => Narration(
    text: json['text'] as String? ?? '',
    languageCode: json['languageCode'] as String? ?? 'en',
  );
}
