import 'location.dart';

/// Data carried between the tour-flow screens (preview → active → post-tour)
/// via GoRouter `extra`.
class TourFlowArgs {
  const TourFlowArgs({
    required this.title,
    required this.prompt,
    required this.locations,
    this.generateFilm = false,
  });

  final String title;
  final String prompt;
  final List<TourLocation> locations;

  /// Whether an AI film was opted into before the tour started.
  final bool generateFilm;

  TourFlowArgs copyWith({bool? generateFilm}) => TourFlowArgs(
    title: title,
    prompt: prompt,
    locations: locations,
    generateFilm: generateFilm ?? this.generateFilm,
  );
}
