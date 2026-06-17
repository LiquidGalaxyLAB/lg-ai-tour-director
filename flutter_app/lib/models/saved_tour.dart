import 'dart:convert';

import 'location.dart';

// A tour the user explicitly saved : backs the **Saved** tab (the library)
// Persists the full **KML** so replay can re-send it to the rig without
// regenerating, plus the locations (with coords) and imagery for the detail UI
class SavedTour {
  const SavedTour({
    required this.id,
    required this.title,
    required this.prompt,
    required this.createdAt,
    required this.locations,
    required this.kml,
    this.imageUrls = const [],
    this.screenCount = 3,
    this.isFavourite = false,
    this.distanceKm = 0,
    this.durationMin = 0,
  });

  final String id;
  final String title;
  final String prompt;
  final DateTime createdAt;
  final List<TourLocation> locations;
  final String kml;
  final List<String> imageUrls;
  final int screenCount;
  final bool isFavourite;
  final double distanceKm;
  final int durationMin;

  int get stopCount => locations.length;

  SavedTour copyWith({bool? isFavourite}) => SavedTour(
    id: id,
    title: title,
    prompt: prompt,
    createdAt: createdAt,
    locations: locations,
    kml: kml,
    imageUrls: imageUrls,
    screenCount: screenCount,
    isFavourite: isFavourite ?? this.isFavourite,
    distanceKm: distanceKm,
    durationMin: durationMin,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'prompt': prompt,
    'created_at': createdAt.toIso8601String(),
    'locations': jsonEncode(locations.map((l) => l.toJson()).toList()),
    'kml': kml,
    'image_urls': jsonEncode(imageUrls),
    'screen_count': screenCount,
    'is_favourite': isFavourite ? 1 : 0,
    'distance_km': distanceKm,
    'duration_min': durationMin,
  };

  factory SavedTour.fromMap(Map<String, dynamic> map) => SavedTour(
    id: map['id'] as String,
    title: map['title'] as String,
    prompt: map['prompt'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    locations: (jsonDecode(map['locations'] as String) as List)
        .map((e) => TourLocation.fromJson(e as Map<String, dynamic>))
        .toList(),
    kml: map['kml'] as String,
    imageUrls: (jsonDecode(map['image_urls'] as String) as List).cast<String>(),
    screenCount: (map['screen_count'] as num?)?.toInt() ?? 3,
    isFavourite: (map['is_favourite'] as num?)?.toInt() == 1,
    distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
    durationMin: (map['duration_min'] as num?)?.toInt() ?? 0,
  );

  /// Placeholder library used by the Saved shell until sqflite is wired
  static List<SavedTour> sample() => [
    SavedTour(
      id: 's1',
      title: 'Lleida Heritage Walk',
      prompt: 'Historic landmarks of Lleida, Spain',
      createdAt: DateTime(2026, 3, 10),
      kml: '',
      isFavourite: true,
      distanceKm: 3.6,
      durationMin: 6,
      imageUrls: const [],
      locations: const [
        TourLocation(
          name: 'Seu Vella Cathedral',
          type: 'Cathedral',
          whySignificant: 'Hilltop medieval cathedral overlooking Lleida.',
          suggestedDurationSeconds: 20,
        ),
        TourLocation(
          name: 'Gardeny Castle',
          type: 'Castle',
          whySignificant: 'Templar fortress on Gardeny hill.',
          suggestedDurationSeconds: 18,
        ),
      ],
    ),
    SavedTour(
      id: 's2',
      title: 'Historical Pune Tour',
      prompt: 'Historical places in Pune',
      createdAt: DateTime(2026, 3, 8),
      kml: '',
      isFavourite: true,
      distanceKm: 22,
      durationMin: 5,
      imageUrls: const [],
      locations: const [
        TourLocation(
          name: 'Shaniwar Wada',
          type: 'Fort',
          whySignificant: 'Seat of the Peshwas of the Maratha Empire.',
          suggestedDurationSeconds: 20,
        ),
      ],
    ),
  ];
}
