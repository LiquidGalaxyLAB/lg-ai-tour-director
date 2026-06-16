import 'location.dart';
import 'scene.dart';

// A fully assembled tour: the discovered locations, ordered scenes, and the
// master KML that plays it on the Liquid Galaxy rig
class Tour {
  const Tour({
    required this.id,
    required this.title,
    required this.prompt,
    required this.locations,
    this.scenes = const [],
    this.kml,
    this.createdAt,
  });

  final String id;
  final String title;
  final String prompt;
  final List<TourLocation> locations;
  final List<Scene> scenes;

  // Assembled master KML (`<gx:Tour>`). Null until the KML engine builds it
  final String? kml;
  final DateTime? createdAt;

  int get stopCount => locations.length;

  double get totalDurationSeconds =>
      scenes.fold(0, (sum, s) => sum + s.durationSeconds);

  Tour copyWith({
    String? id,
    String? title,
    String? prompt,
    List<TourLocation>? locations,
    List<Scene>? scenes,
    String? kml,
    DateTime? createdAt,
  }) {
    return Tour(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      locations: locations ?? this.locations,
      scenes: scenes ?? this.scenes,
      kml: kml ?? this.kml,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
