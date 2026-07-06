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

  // Drop a leading article ("The Stratosphere Tower" → "Stratosphere Tower"),
  // otherwise a stripped fragment can collapse to the bare word "The".
  final head = segments.first.replaceFirst(
    RegExp(r'^the\s+', caseSensitive: false),
    '',
  );
  // Everything after the landmark = geographic context, e.g. "Las Vegas, USA".
  // ALWAYS reattached so a rescue stays anchored to the requested city.
  final context = segments.length > 1 ? segments.sublist(1).join(', ') : null;
  // The city is the segment just before the country — the best anchor.
  final city = segments.length >= 2 ? segments[segments.length - 2] : null;

  String withContext(String core) => context != null ? '$core, $context' : core;

  // A one-word fragment this short (or a bare article/conjunction) is not a
  // landmark — searching it just matches a random nearby point. Skip it.
  const stop = {'the', 'a', 'an', 'of', 'and', 'de', 'la', 'el'};
  bool tooGeneric(String core) {
    final words = core.split(' ');
    if (words.length > 1) return false;
    final w = words.first.toLowerCase();
    return w.length <= 3 || stop.contains(w);
  }

  // The de-articled full name with context — the single most likely rescue,
  // e.g. "Stratosphere Tower, Las Vegas, USA". Tried before any fragment.
  add(withContext(head));

  final headWords = head
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Drop TRAILING generic words first ("High Roller Observation Wheel" →
  // "High Roller"), keeping the leading proper noun — usually the real signal.
  for (var keep = headWords.length - 1; keep >= 1; keep--) {
    final core = headWords.sublist(0, keep).join(' ');
    if (!tooGeneric(core)) add(withContext(core));
  }
  // Then drop LEADING words ("Red Rock Canyon National Conservation Area" →
  // "Conservation Area"), still anchored to the city/country context.
  for (var drop = 1; drop < headWords.length; drop++) {
    final core = headWords.sublist(drop).join(' ');
    if (!tooGeneric(core)) add(withContext(core));
  }

  // Landmark with just the city (drop the country qualifier).
  if (city != null && city.toLowerCase() != head.toLowerCase()) {
    add('$head, $city');
  }
  // Landmark name alone — a global search, last resort for world-famous names.
  add(head);

  // Safety cap: a real match almost always lands in the first few variants;
  // this keeps a very long name from hammering the geocoder (and its rate
  // limits) with a dozen low-value fragments.
  return variants.length > 8 ? variants.sublist(0, 8) : variants;
}

// Builds an ordered, de-duped list of query strings to try for one location
// name, so a near-miss like "High Roller Observation Wheel, Las Vegas, USA"
// still geocodes to the RIGHT place.
//
// Two hard rules keep a rescue from flying to the wrong spot:
//   1. Every stripped variant keeps the geographic context (city + country), so
//      a search can never wander to another state. Dropping words but keeping
//      only "USA" is what once matched "Observation Wheel, USA" to Wyoming.
//   2. We NEVER emit a bare city or country as a query. Searching "USA" or
//      "Las Vegas" for a specific landmark returns a centroid far from the real
//      place (that bug flew "Omnia Nightclub" to the centre of the USA).
//
// The caller tries these in order and stops at the first that resolves. If none
// resolve, returning no coordinates is correct — far better than a confident
// wrong location.
//
// Example: "High Roller Observation Wheel, Las Vegas, USA" →
//   1. High Roller Observation Wheel, Las Vegas, USA   (original)
//   2. High Roller Observation, Las Vegas, USA         (trailing word dropped)
//   3. High Roller, Las Vegas, USA                     (matches the wheel)
//   ... leading-word drops, then "landmark, city", then the bare landmark name.
