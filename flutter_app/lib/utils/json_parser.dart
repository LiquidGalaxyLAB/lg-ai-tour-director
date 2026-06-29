/// Extracts a JSON document from potentially messy LLM output. OpenRouter
/// models are chattier than Gemini (which could enforce a JSON mime type), so
/// they may wrap the JSON in ```json fences or add prose around it.
class JsonParser {
  JsonParser._();

  /// Returns a parseable JSON string ([ … ] or { … }) from [raw], or null if
  /// none can be found. Handles: raw JSON, ```json fences, and prose before/
  /// after the JSON.
  static String? extractJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final trimmed = raw.trim();

    // 1. Already clean JSON.
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      return trimmed;
    }

    // 2. Fenced ```json … ``` block.
    final fenceMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(trimmed);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)?.trim();
      if (inner != null && inner.isNotEmpty) return inner;
    }

    // 3. Prose around the JSON — slice from the first [ or { to the last ] or }.
    final firstArray = trimmed.indexOf('[');
    final firstObject = trimmed.indexOf('{');
    final start = (firstArray != -1 && (firstObject == -1 || firstArray < firstObject))
        ? firstArray
        : firstObject;

    final lastArray = trimmed.lastIndexOf(']');
    final lastObject = trimmed.lastIndexOf('}');
    final end = lastArray > lastObject ? lastArray : lastObject;

    if (start != -1 && end != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }

    return null;
  }
}
