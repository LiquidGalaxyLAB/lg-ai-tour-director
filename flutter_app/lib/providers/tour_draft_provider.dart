import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tour_flow.dart';

/// Holds the most recently generated (not-yet-started) tour so it survives
/// in-app navigation. If the Preview route is popped (back gesture, wandering
/// off), Home can offer a "return to your tour" banner to re-open Preview.
/// Set on generation success, cleared when the tour starts or is discarded.
class TourDraftNotifier extends Notifier<TourFlowArgs?> {
  @override
  TourFlowArgs? build() => null;

  void set(TourFlowArgs args) => state = args;

  void clear() => state = null;
}

final tourDraftProvider = NotifierProvider<TourDraftNotifier, TourFlowArgs?>(
  TourDraftNotifier.new,
);
