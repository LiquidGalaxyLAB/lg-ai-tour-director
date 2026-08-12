class VideoClip {
  const VideoClip({
    required this.locationName,
    required this.localPath,
    required this.durationSeconds,
    required this.clipIndex,
    required this.locationIndex,
  });

  final String locationName;
  final String localPath;
  final int durationSeconds;
  final int clipIndex;
  final int locationIndex;
}
