class TourLocation {
  const TourLocation({
    required this.name,
    required this.type,
    required this.whySignificant,
    required this.suggestedDurationSeconds,
  });

  final String name;
  final String type;
  final String whySignificant;
  final int suggestedDurationSeconds;

  factory TourLocation.fromJson(Map<String, dynamic> json) {
    return TourLocation(
      name: json['name'] as String? ?? 'Unknown Location',
      type: json['type'] as String? ?? 'Unknown',
      whySignificant: json['why_significant'] as String? ?? '',
      suggestedDurationSeconds:
          (json['suggested_duration_seconds'] as num?)?.toInt() ?? 15,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'why_significant': whySignificant,
    'suggested_duration_seconds': suggestedDurationSeconds,
  };

  @override
  String toString() => 'TourLocation(name: $name, type: $type)';
}
