import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_tour.dart';
import '../models/tour_history_entry.dart';
import '../services/storage/tour_storage_service.dart';

/// The Saved library (persisted). Backs the Saved tab + detail.
final savedToursProvider =
    AsyncNotifierProvider<SavedToursNotifier, List<SavedTour>>(
      SavedToursNotifier.new,
    );

class SavedToursNotifier extends AsyncNotifier<List<SavedTour>> {
  @override
  Future<List<SavedTour>> build() =>
      TourStorageService.instance.getSavedTours();

  Future<void> save(SavedTour tour) async {
    state = AsyncData(await TourStorageService.instance.saveTour(tour));
  }

  Future<void> remove(String id) async {
    state = AsyncData(await TourStorageService.instance.deleteSavedTour(id));
  }

  Future<void> toggleFavourite(String id) async {
    state = AsyncData(await TourStorageService.instance.toggleFavourite(id));
  }
}

/// The Tours history (persisted). A row is recorded for every tour that runs.
final tourHistoryProvider =
    AsyncNotifierProvider<TourHistoryNotifier, List<TourHistoryEntry>>(
      TourHistoryNotifier.new,
    );

class TourHistoryNotifier extends AsyncNotifier<List<TourHistoryEntry>> {
  @override
  Future<List<TourHistoryEntry>> build() =>
      TourStorageService.instance.getHistory();

  Future<void> add(TourHistoryEntry entry) async {
    state = AsyncData(await TourStorageService.instance.addHistory(entry));
  }

  Future<void> remove(String id) async {
    state = AsyncData(await TourStorageService.instance.deleteHistory(id));
  }
}
