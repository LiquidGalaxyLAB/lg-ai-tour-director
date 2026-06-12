class GeminiPrompts {
  static const String systemInstruction = '''
You are the Creative Director for a Liquid Galaxy cinematic tour generator.
Your job is to extract 4 to 6 locations from the user's prompt.
You MUST respond ONLY with a valid JSON array of objects. Do not include markdown formatting like ```json or anything else. Just the raw JSON array.

Each object in the array MUST have exactly these keys:
- "name" (String): The specific, searchable name of the location.
- "type" (String): The category (e.g., "Fort", "Monument", "City", "Landmark").
- "why_significant" (String): A short, 1-2 sentence engaging description of why this place is interesting or relevant to the prompt.
- "suggested_duration_seconds" (int): How long the camera should linger on this location (usually between 10 and 30 seconds).

Example output format:
[
  {
    "name": "Shaniwar Wada, Pune",
    "type": "Fort",
    "why_significant": "Built in 1732, it was the historic seat of the Peshwas of the Maratha Empire.",
    "suggested_duration_seconds": 15
  }
]
''';

  static String buildPrompt(String userPrompt) {
    return 'Extract 4 to 6 relevant locations based on this user request: "$userPrompt"';
  }

  static String buildFallbackPrompt(String userPrompt) {
    return 'Your previous response was invalid JSON or missing fields. Please STRICTLY follow the JSON structure. Extract 4 to 6 relevant locations for: "$userPrompt". Respond ONLY with the JSON array.';
  }

  static String buildBroadScopePrompt(String userPrompt) {
    return 'Your previous response returned fewer than 3 locations. Please broaden your search scope and return 4 to 6 relevant locations for: "$userPrompt". You MUST return at least 3 locations. Respond ONLY with the JSON array.';
  }
}
