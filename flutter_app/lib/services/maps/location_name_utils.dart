// this builds an ordered, de-duped list of query strings to try for one location
// name, so a near-miss like `"Old Fort (Purana Qila), Delhi"` still geocodes

// The geocoders often fail on a *string* even when the place exists but
// usually because of a parenthetical or extra qualifiers. We try
// the original first, then progressively simpler forms
// Returned in priority order; the caller stops at the first variant that resolves
///
/// Example: `"Old Fort (Purana Qila), Delhi"` →
///   1. `Old Fort (Purana Qila), Delhi`  (original)
///   2. `Old Fort, Delhi`                 (parenthetical stripped)
///   3. `Purana Qila, Delhi`              (parenthetical used as the name)
///   4. `Old Fort, Delhi`                 (first + last comma segment — deduped)
///   5. `Old Fort`                        (core name only)
List<String> locationQueryVariants(String name) {
  final variants = <String>[];

  void add(String? candidate) {
    if (candidate == null) return;
    final cleaned = candidate
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .replaceAll(RegExp(r'(,\s*){2,}'), ', ')
        .replaceAll(RegExp(r'^[\s,]+'), '')
        .replaceAll(RegExp(r'[\s,]+$'), '')
        .trim();
    if (cleaned.isEmpty || variants.contains(cleaned)) return;
    variants.add(cleaned);
  }

  final raw = name.trim();
  add(raw);

  final open = raw.indexOf('(');
  final close = open == -1 ? -1 : raw.indexOf(')', open);
  if (open != -1 && close != -1) {
    final before = raw.substring(0, open);
    final inside = raw.substring(open + 1, close).trim();
    final after = raw.substring(close + 1);
    add('$before $after');
    if (inside.isNotEmpty) {
      add('$inside $after');
    }
  }

  final base = raw.replaceAll(RegExp(r'\s*\([^)]*\)'), ' ');
  final segments = base
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final head = segments.isNotEmpty ? segments.first : base.trim();
  final tail = segments.length >= 2 ? segments.last : null;
  final headWords = head.split(RegExp(r'\s+'));
  for (var drop = 1; drop < headWords.length; drop++) {
    final shorter = headWords.sublist(drop).join(' ');
    if (shorter.isEmpty) continue;
    add(tail != null ? '$shorter, $tail' : shorter);
  }

  if (segments.length >= 3) {
    add('${segments.first}, ${segments.last}');
  }
  if (segments.length >= 2) {
    add(segments.first);
    add(segments.last);
  }

  return variants;
}
