/// Lightweight record of a tour that was generated/run — backs the **Tours**
/// tab (chronological history). No KML; saving "promotes" one of these into a
/// [SavedTour] in the library.
class TourHistoryEntry {
  const TourHistoryEntry({
    required this.id,
    required this.title,
    required this.prompt,
    required this.createdAt,
    required this.stopCount,
    required this.distanceKm,
    required this.durationMin,
    required this.locationNames,
  });

  final String id;
  final String title;
  final String prompt;
  final DateTime createdAt;
  final int stopCount;
  final double distanceKm;
  final int durationMin;
  final List<String> locationNames;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'prompt': prompt,
    'created_at': createdAt.toIso8601String(),
    'stop_count': stopCount,
    'distance_km': distanceKm,
    'duration_min': durationMin,
    'location_names': locationNames.join('|'),
  };

  factory TourHistoryEntry.fromMap(Map<String, dynamic> map) =>
      TourHistoryEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        prompt: map['prompt'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        stopCount: (map['stop_count'] as num).toInt(),
        distanceKm: (map['distance_km'] as num).toDouble(),
        durationMin: (map['duration_min'] as num).toInt(),
        locationNames: (map['location_names'] as String).split('|'),
      );

  /// Placeholder history used by the Tours shell until sqflite is wired.
  static List<TourHistoryEntry> sample() => [
    TourHistoryEntry(
      id: 'h1',
      title: 'Lleida Heritage Walk',
      prompt: 'Historic landmarks of Lleida, Spain',
      createdAt: DateTime(2026, 3, 10, 10, 15),
      stopCount: 4,
      distanceKm: 3.6,
      durationMin: 6,
      locationNames: const [
        'Seu Vella Cathedral',
        'Gardeny Castle',
        'La Paeria',
        'Església de Sant Llorenç',
      ],
    ),
    TourHistoryEntry(
      id: 'h2',
      title: 'Historical Pune Tour',
      prompt: 'Historical places in Pune',
      createdAt: DateTime(2026, 3, 8, 16, 21),
      stopCount: 5,
      distanceKm: 22,
      durationMin: 5,
      locationNames: const [
        'Shaniwar Wada',
        'Aga Khan Palace',
        'Sinhagad Fort',
        'Lal Mahal',
        'Pataleshwar Cave Temple',
      ],
    ),
  ];
}
