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
      suggestedDurationSeconds:
          suggestedDurationSeconds ?? this.suggestedDurationSeconds,
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeId: json['place_id'] as String?,
      address: json['address'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'why_significant': whySignificant,
    'suggested_duration_seconds': suggestedDurationSeconds,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (placeId != null) 'place_id': placeId,
    if (address != null) 'address': address,
    if (imageUrl != null) 'image_url': imageUrl,
  };

  @override
  String toString() => 'TourLocation(name: $name, type: $type)';
}
