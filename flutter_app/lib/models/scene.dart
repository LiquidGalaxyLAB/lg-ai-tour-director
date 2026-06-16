import 'location.dart';
import 'narration.dart';

// Camera treatment for a scene, in the order they play per location
enum SceneType { lookAt, topDown, orbit }

// One beat of the tour: a location, its narration, and how the camera frames it
class Scene {
  const Scene({
    required this.index,
    required this.location,
    this.type = SceneType.lookAt,
    this.narration,
  });

  final int index;
  final TourLocation location;
  final SceneType type;
  final Narration? narration;

  double get durationSeconds =>
      narration?.estimatedDurationSeconds ??
      location.suggestedDurationSeconds.toDouble();

  Scene copyWith({
    int? index,
    TourLocation? location,
    SceneType? type,
    Narration? narration,
  }) {
    return Scene(
      index: index ?? this.index,
      location: location ?? this.location,
      type: type ?? this.type,
      narration: narration ?? this.narration,
    );
  }
}
