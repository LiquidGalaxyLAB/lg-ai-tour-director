// Builds an ordered, de-duped list of geocoder queries for one location name.
// Every variant keeps the city+country context so a near-miss never flies to
// the wrong place, and a bare city/country is never emitted on its own.
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

  // Parenthetical handling: "Old Fort (Purana Qila), Delhi".
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

  // Comma segments of the paren-free name: [landmark, city, country].
  final base = raw.replaceAll(RegExp(r'\s*\([^)]*\)'), ' ');
  add(base);
  final segments = base
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return variants;

  // Drop a leading article so a fragment can't collapse to the bare word "The".
  final head = segments.first.replaceFirst(
    RegExp(r'^the\s+', caseSensitive: false),
    '',
  );
  // Geographic context (city, country), always reattached to keep the anchor.
  final context = segments.length > 1 ? segments.sublist(1).join(', ') : null;
  // City is the segment just before the country, the best anchor.
  final city = segments.length >= 2 ? segments[segments.length - 2] : null;

  String withContext(String core) => context != null ? '$core, $context' : core;

  // Skip a too-short one-word fragment or bare article; it matches random points.
  const stop = {'the', 'a', 'an', 'of', 'and', 'de', 'la', 'el'};
  bool tooGeneric(String core) {
    final words = core.split(' ');
    if (words.length > 1) return false;
    final w = words.first.toLowerCase();
    return w.length <= 3 || stop.contains(w);
  }

  // De-articled full name with context: the single most likely rescue.
  add(withContext(head));

  final headWords = head
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Drop trailing generic words, keeping the leading proper noun.
  for (var keep = headWords.length - 1; keep >= 1; keep--) {
    final core = headWords.sublist(0, keep).join(' ');
    if (!tooGeneric(core)) add(withContext(core));
  }
  // Then drop leading words, still anchored to city/country context.
  for (var drop = 1; drop < headWords.length; drop++) {
    final core = headWords.sublist(drop).join(' ');
    if (!tooGeneric(core)) add(withContext(core));
  }

  // Landmark with just the city (drop the country qualifier).
  if (city != null && city.toLowerCase() != head.toLowerCase()) {
    add('$head, $city');
  }
  // Landmark name alone: last-resort global search.
  add(head);

  // Cap variants so a long name doesn't hammer the geocoder's rate limit.
  return variants.length > 8 ? variants.sublist(0, 8) : variants;
}
