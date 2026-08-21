class HeroBannerSettings {
  /// How long the current hero stays visible before changing slides.
  final int slideIntervalSeconds;

  /// How long the visual animation takes when changing slides.
  final int transitionDurationMilliseconds;

  const HeroBannerSettings({
    this.slideIntervalSeconds = 8,
    this.transitionDurationMilliseconds = 550,
  });

  HeroBannerSettings copyWith({
    int? slideIntervalSeconds,
    int? transitionDurationMilliseconds,
  }) {
    return HeroBannerSettings(
      slideIntervalSeconds: slideIntervalSeconds ?? this.slideIntervalSeconds,
      transitionDurationMilliseconds:
          transitionDurationMilliseconds ?? this.transitionDurationMilliseconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slideIntervalSeconds': slideIntervalSeconds,
      'transitionDurationMilliseconds': transitionDurationMilliseconds,
    };
  }

  factory HeroBannerSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const HeroBannerSettings();

    final interval = (map['slideIntervalSeconds'] as num?)?.toInt() ?? 8;
    final duration =
        (map['transitionDurationMilliseconds'] as num?)?.toInt() ?? 550;

    return HeroBannerSettings(
      slideIntervalSeconds: interval.clamp(3, 30).toInt(),
      transitionDurationMilliseconds: duration.clamp(200, 1500).toInt(),
    );
  }
}
