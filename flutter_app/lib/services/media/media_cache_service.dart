import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache of resolved media (image + description) keyed by location
/// name, so each Wikipedia/Unsplash lookup happens once and replays are free.
class MediaCacheService {
  MediaCacheService._();
  static final MediaCacheService instance = MediaCacheService._();

  static const String _prefix = 'media_cache_';

  String _key(String name) => '$_prefix${name.trim().toLowerCase()}';

  /// Returns the cached media for [name], or null if never resolved.
  Future<({String imageUrl, String description})?> get(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(name));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        imageUrl: map['imageUrl'] as String? ?? '',
        description: map['description'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[MediaCache] read failed for "$name": $e');
      return null;
    }
  }

  /// Stores resolved media for [name] (an empty [imageUrl] caches a known miss).
  Future<void> put(
    String name, {
    required String imageUrl,
    required String description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(name),
        jsonEncode({'imageUrl': imageUrl, 'description': description}),
      );
    } catch (e) {
      debugPrint('[MediaCache] write failed for "$name": $e');
    }
  }
}
