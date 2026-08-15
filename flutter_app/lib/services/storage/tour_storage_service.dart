import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/saved_tour.dart';
import '../../models/tour_history_entry.dart';

/// Persists Tours history and the Saved library via SharedPreferences (JSON),
/// which works on every platform including web. Models already carry
/// `toMap`/`fromMap` for a later swap to sqflite if scale demands it.
class TourStorageService {
  TourStorageService._();
  static final TourStorageService instance = TourStorageService._();

  static const String _historyKey = 'tour_history_v1';
  static const String _savedKey = 'saved_tours_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // Tours history

  Future<List<TourHistoryEntry>> getHistory() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_historyKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final entries = list
          .map((e) => TourHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<List<TourHistoryEntry>> addHistory(TourHistoryEntry entry) async {
    final entries = await getHistory();
    entries.removeWhere((e) => e.id == entry.id);
    entries.insert(0, entry);
    await _writeHistory(entries);
    return entries;
  }

  Future<List<TourHistoryEntry>> deleteHistory(String id) async {
    final entries = await getHistory();
    entries.removeWhere((e) => e.id == id);
    await _writeHistory(entries);
    return entries;
  }

  Future<void> _writeHistory(List<TourHistoryEntry> entries) async {
    final prefs = await _prefs;
    await prefs.setString(
      _historyKey,
      jsonEncode(entries.map((e) => e.toMap()).toList()),
    );
  }

  // Saved library

  Future<List<SavedTour>> getSavedTours() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_savedKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final tours = list
          .map((e) => SavedTour.fromMap(e as Map<String, dynamic>))
          .toList();
      tours.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tours;
    } catch (_) {
      return [];
    }
  }

  Future<List<SavedTour>> saveTour(SavedTour tour) async {
    final tours = await getSavedTours();
    tours.removeWhere((t) => t.id == tour.id);
    tours.insert(0, tour);
    await _writeSaved(tours);
    return tours;
  }

  Future<List<SavedTour>> deleteSavedTour(String id) async {
    final tours = await getSavedTours();
    tours.removeWhere((t) => t.id == id);
    await _writeSaved(tours);
    return tours;
  }

  Future<List<SavedTour>> toggleFavourite(String id) async {
    final tours = await getSavedTours();
    final i = tours.indexWhere((t) => t.id == id);
    if (i != -1) {
      tours[i] = tours[i].copyWith(isFavourite: !tours[i].isFavourite);
      await _writeSaved(tours);
    }
    return tours;
  }

  Future<void> _writeSaved(List<SavedTour> tours) async {
    final prefs = await _prefs;
    await prefs.setString(
      _savedKey,
      jsonEncode(tours.map((t) => t.toMap()).toList()),
    );
  }
}
