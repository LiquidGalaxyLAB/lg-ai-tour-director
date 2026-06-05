class RigConfig {
  const RigConfig({
    required this.totalScreens,
    required this.centerScreen,
    required this.leftScreens,
    required this.rightScreens,
  });

  final int totalScreens;
  final int centerScreen;

  /// Left wing screens ordered nearest to center first
  /// eg 5-screen : [2, 1]
  final List<int> leftScreens;

  /// Right wing screens ordered nearest to center first
  /// eg 5-screen : [4, 5]
  final List<int> rightScreens;

  /// Computes the layout for an odd screen count (3, 5, 7, ...).
  ///
  /// The center screen is the middle one: `(n / 2).ceil()`.
  /// Left wing fans out from center toward screen 1; right wing fans out
  /// from center toward screen N — both ordered nearest-to-center first.
  ///
  ///  - 3 → center=2, left=[1],     right=[3]
  ///  - 5 → center=3, left=[2,1],   right=[4,5]
  ///  - 7 → center=4, left=[3,2,1], right=[5,6,7]
  factory RigConfig.fromScreenCount(int n) {
    assert(n > 0 && n.isOdd, 'LG rigs use an odd number of screens (3/5/7).');
    final center = (n / 2).ceil();
    final left = [for (var s = center - 1; s >= 1; s--) s];
    final right = [for (var s = center + 1; s <= n; s++) s];
    return RigConfig(
      totalScreens: n,
      centerScreen: center,
      leftScreens: List.unmodifiable(left),
      rightScreens: List.unmodifiable(right),
    );
  }

  /// Outermost left screen (e.g. 5-screen → 1). The logo overlay goes here.
  int get leftmostScreen => leftScreens.last;

  /// Outermost right screen (e.g. 5-screen → 5). The info balloon goes here.
  int get rightmostScreen => rightScreens.last;

  /// Screen that displays the contextual info balloon.
  int get infoScreen => rightmostScreen;

  /// Screen that displays the Liquid Galaxy logo overlay.
  int get logoScreen => leftmostScreen;

  @override
  bool operator ==(Object other) =>
      other is RigConfig && other.totalScreens == totalScreens;

  @override
  int get hashCode => totalScreens.hashCode;

  @override
  String toString() =>
      'RigConfig(total: $totalScreens, center: $centerScreen, '
      'left: $leftScreens, right: $rightScreens)';
}
