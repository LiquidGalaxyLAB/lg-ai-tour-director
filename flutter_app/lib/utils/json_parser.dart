/// Extracts a JSON document from messy LLM output that may wrap it in ```json
/// fences or surround it with prose.
class JsonParser {
  JsonParser._();

  /// Returns a parseable JSON string from [raw], or null if none is found.
  static String? extractJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final trimmed = raw.trim();

    // Already clean JSON.
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      return trimmed;
    }

    // Fenced ```json block.
    final fenceMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(trimmed);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)?.trim();
      if (inner != null && inner.isNotEmpty) return inner;
    }

    // Prose around the JSON: slice from the first [ or { to the last ] or }.
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
