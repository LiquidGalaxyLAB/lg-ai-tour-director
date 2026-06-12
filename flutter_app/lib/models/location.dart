class TourLocation {
  const TourLocation({
    required this.name,
    required this.type,
    required this.whySignificant,
    required this.suggestedDurationSeconds,
    this.latitude,
    this.longitude,
    this.placeId,
    this.address,
    this.imageUrl,
  });

  final String name;
  final String type;
  final String whySignificant;
  final int suggestedDurationSeconds;
  
  // Enriched fields
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? address;
  final String? imageUrl;

  TourLocation copyWith({
    String? name,
    String? type,
    String? whySignificant,
    int? suggestedDurationSeconds,
    double? latitude,
    double? longitude,
    String? placeId,
    String? address,
    String? imageUrl,
  }) {
    return TourLocation(
      name: name ?? this.name,
      type: type ?? this.type,
      whySignificant: whySignificant ?? this.whySignificant,
      suggestedDurationSeconds: suggestedDurationSeconds ?? this.suggestedDurationSeconds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

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
