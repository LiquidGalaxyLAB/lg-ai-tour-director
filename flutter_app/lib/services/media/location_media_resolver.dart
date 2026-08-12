import 'package:flutter/foundation.dart';

import '../../models/location.dart';
import 'media_cache_service.dart';
import 'unsplash_service.dart';
import 'wikimedia_service.dart';

/// Single source of truth for a location's media (image URL + description),
/// shared by the on-rig info balloon AND the in-app image widgets so both show
/// the same picture.
///
/// Resolution happens once per location name and is cached persistently
/// ([MediaCacheService]) — so the app, the live tour, and any later replay all
/// reuse the result instead of re-querying Wikipedia/Unsplash.
class LocationMediaResolver {
  LocationMediaResolver._();
  static final LocationMediaResolver instance = LocationMediaResolver._();

  /// Chain: cache → Wikipedia (sanitise retry) → Unsplash → generation-time
  /// image → text-only. Description is ALWAYS the location's unified AI
  /// narration (whySignificant), independent of the image source — so the
  /// balloon card text matches the spoken narration exactly. Never throws.
  Future<({String imageUrl, String description})> resolve(
    TourLocation location,
  ) async {
    final cached = await MediaCacheService.instance.get(location.name);
    if (cached != null) {
      debugPrint('[Media] source: cache for "${location.name}"');
      return cached;
    }

    var imageUrl = '';
    // Unified: the balloon description is ALWAYS the AI narration, so it matches
    // the spoken TTS. The Wikipedia/Unsplash chain below only resolves the IMAGE.
    final description = location.whySignificant;
    String source;

    final wiki = await WikimediaService.instance.fetchLocationMedia(
      location.name,
    );
    if (wiki != null && wiki.imageUrl.isNotEmpty) {
      imageUrl = wiki.imageUrl;
      source = 'wikipedia';
    } else {
      final unsplash = await UnsplashService.instance.fetchPhotoUrl(
        location.name,
      );
      if (unsplash != null && unsplash.isNotEmpty) {
        imageUrl = unsplash;
        source = 'unsplash';
      } else if ((location.imageUrl ?? '').isNotEmpty) {
        imageUrl = location.imageUrl!;
        source = 'fallback (generation image)';
      } else {
        final themed = _themedQuery(location);
        final themedUrl = themed == null
            ? null
            : await UnsplashService.instance.fetchPhotoUrl(themed);
        if (themedUrl != null && themedUrl.isNotEmpty) {
          imageUrl = themedUrl;
          source = 'unsplash (themed: $themed)';
        } else {
          source = 'text-only';
        }
      }
    }

    debugPrint('[Media] source: $source for "${location.name}"');
    debugPrint('[Narration] using unified description for ${location.name}');
    await MediaCacheService.instance.put(
      location.name,
      imageUrl: imageUrl,
      description: description,
    );
    return (imageUrl: imageUrl, description: description);
  }

  String? _themedQuery(TourLocation location) {
    final segments = location.name
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final city = segments.length >= 2 ? segments[segments.length - 2] : null;
    final type = location.type.trim();
    final usableType = type.isEmpty || type.toLowerCase() == 'unknown'
        ? ''
        : type;
    final query = [
      usableType,
      city ?? '',
    ].where((s) => s.isNotEmpty).join(' ').trim();
    return query.isEmpty ? null : query;
  }
}
