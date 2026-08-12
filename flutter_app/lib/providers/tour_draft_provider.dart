import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tour_flow.dart';

/// Holds the most recently GENERATED tour (locations + prompt) that has not yet
/// been started, so it survives in-app navigation.
///
/// A generated tour normally lives only inside the go_router route `extra` of
/// the Preview/Inspection screens. If those routes are popped — e.g. the user
/// presses the phone's system back gesture, or wanders off to change the theme —
/// the route is gone and the generated locations would be lost. Stashing the
/// same [TourFlowArgs] here lets the Home screen offer a "return to your tour"
/// banner that re-opens Preview with the exact generated data.
///
/// This mirrors what [tourStateProvider] already does for a *running* tour; this
/// one covers the *generated-but-not-yet-started* stage. Lifecycle:
///  - [set]   on generation success (Generation screen).
///  - [clear] when the tour actually starts (the running-tour banner takes over)
///            or when the user discards the preview.
class TourDraftNotifier extends Notifier<TourFlowArgs?> {
  @override
  TourFlowArgs? build() => null;

  void set(TourFlowArgs args) => state = args;

  void clear() => state = null;
}

final tourDraftProvider = NotifierProvider<TourDraftNotifier, TourFlowArgs?>(
  TourDraftNotifier.new,
);
