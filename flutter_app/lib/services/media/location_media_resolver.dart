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
  /// image → text-only. Description prefers Wikipedia's extract, else the AI's
  /// significance text. Never throws.
  Future<({String imageUrl, String description})> resolve(
    TourLocation location,
  ) async {
    final cached = await MediaCacheService.instance.get(location.name);
    if (cached != null) {
      debugPrint('[Media] source: cache for "${location.name}"');
      return cached;
    }

    var imageUrl = '';
    var description = location.whySignificant; // body falls back to AI text
    String source;

    final wiki =
        await WikimediaService.instance.fetchLocationMedia(location.name);
    if (wiki != null && wiki.imageUrl.isNotEmpty) {
      imageUrl = wiki.imageUrl;
      description = wiki.description;
      source = 'wikipedia';
    } else {
      final unsplash =
          await UnsplashService.instance.fetchPhotoUrl(location.name);
      if (unsplash != null && unsplash.isNotEmpty) {
        imageUrl = unsplash;
        source = 'unsplash';
      } else if ((location.imageUrl ?? '').isNotEmpty) {
        imageUrl = location.imageUrl!;
        source = 'fallback (generation image)';
      } else {
        source = 'text-only';
      }
    }

    debugPrint('[Media] source: $source for "${location.name}"');
    await MediaCacheService.instance.put(
      location.name,
      imageUrl: imageUrl,
      description: description,
    );
    return (imageUrl: imageUrl, description: description);
  }
}
